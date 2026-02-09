//
//  HomeView.swift
//  Elsewhere
//
//  Created on 2/8/26.
//

import SwiftUI
import MapKit
import CoreLocation

private struct OtherHomeDistance: Identifiable {
    let id: String
    let name: String
    let travelTime: TimeInterval?
    let coordinates: Coordinates?
}

private enum SuggestionSource {
    case weather(triggerType: WeatherTriggerType)
    case systemAge(systemType: SystemType)
    case serviceOverdue(systemType: SystemType)
    case occupancy
    case seasonal
    case riskFactor
}

private struct Suggestion: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let priority: MaintenancePriority
    let relatedSystem: SystemType?
    let source: SuggestionSource
}

struct HomeView: View {
    @ObservedObject var appState: AppState
    @State private var showingSettings = false
    @State private var showingChat = false
    @State private var pendingTasks: [MaintenanceItem] = []
    @State private var vendors: [Vendor] = []
    @State private var isLoading = true

    // Weather alert state
    @State private var weather: WeatherData?
    @State private var weatherTriggers: [WeatherTriggerType] = []
    @State private var actionItems: [WeatherActionItem] = []
    @State private var isLoadingWeather = false
    @State private var weatherError: String?

    // Suggestions state
    @State private var suggestions: [Suggestion] = []
    @AppStorage("dismissedSuggestions") private var dismissedSuggestionsData: Data = Data()

    // Map & distances state
    @State private var resolvedCoordinates: Coordinates?
    @State private var otherHomeDistances: [OtherHomeDistance] = []
    @State private var isLoadingDistances = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 16) {
                    // Weather card
                    if let weather = weather {
                        NavigationLink(destination: WeatherDetailScreen(
                            weather: weather,
                            triggers: weatherTriggers,
                            actionItems: actionItems,
                            pendingTasks: pendingTasks,
                            onAddTask: { item in await addTaskFromAction(item) }
                        )) {
                            CardSection(title: "Weather", showChevron: true) {
                                CompactWeatherView(
                                    weather: weather,
                                    hasAlerts: !weatherTriggers.isEmpty || !weather.alerts.filter(\.isActive).isEmpty
                                )
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        CardSection(title: "Weather") {
                            if isLoadingWeather {
                                HStack {
                                    ProgressView()
                                    Text("Loading weather...")
                                        .foregroundColor(.secondary)
                                }
                            } else if let error = weatherError {
                                Text(error)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("No weather data available")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Suggestions
                    if !suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Suggestions")
                                .font(.headline)
                                .padding(.horizontal, 4)
                            ForEach(suggestions) { suggestion in
                                SuggestionCardView(
                                    suggestion: suggestion,
                                    onAccept: { Task { await acceptSuggestion(suggestion) } },
                                    onDismiss: { dismissSuggestionCard(suggestion) }
                                )
                            }
                        }
                    }

                    // Quick stats
                    if let profile = appState.houseProfile {
                        QuickStatsRow(profile: profile)
                    }

                    // Tasks card
                    NavigationLink(destination: MaintenanceView(appState: appState)) {
                        CardSection(title: "Tasks", showChevron: true) {
                            if isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            } else if pendingTasks.isEmpty {
                                Text("No pending tasks")
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(pendingTasks.prefix(3)) { item in
                                        MaintenanceItemRow(item: item)
                                    }
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    // Vendors card
                    NavigationLink(destination: VendorsView(appState: appState)) {
                        CardSection(title: "Vendors", showChevron: true) {
                            if isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            } else if vendors.isEmpty {
                                Text("No vendors added")
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                HStack {
                                    Label("\(vendors.count) total", systemImage: "person.2.fill")
                                        .font(.subheadline)
                                    Spacer()
                                    let favCount = vendors.filter { $0.isFavorite }.count
                                    if favCount > 0 {
                                        Label("\(favCount) favorites", systemImage: "star.fill")
                                            .font(.subheadline)
                                            .foregroundColor(.yellow)
                                    }
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    // Map & distances
                    if let coords = resolvedCoordinates {
                        CardSection(title: "Location") {
                            VStack(spacing: 12) {
                                Map(position: .constant(.region(MKCoordinateRegion(
                                    center: coords.clLocation,
                                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                )))) {
                                    Marker(appState.currentHouse?.name ?? "Home", coordinate: coords.clLocation)
                                }
                                .mapStyle(.standard)
                                .frame(height: 180)
                                .cornerRadius(8)
                                .allowsHitTesting(false)

                                distancesList
                            }
                        }
                    }
                }
                .padding()
                .padding(.bottom, 60)
            }

                // Floating chat bar
                Button {
                    showingChat = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "message.fill")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Text("Ask about your home...")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassEffect(.regular, in: .capsule)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .navigationTitle(appState.currentHouse?.name ?? "Home")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        appState.currentHouse = nil
                        appState.houseProfile = nil
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Homes")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView(appState: appState)
            }
        }
        .sheet(isPresented: $showingChat) {
            ChatView(appState: appState)
        }
    }

    @ViewBuilder
    private var distancesList: some View {
        if isLoadingDistances {
            HStack {
                ProgressView()
                Text("Calculating distances...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        } else if !otherHomeDistances.isEmpty {
            VStack(spacing: 0) {
                ForEach(otherHomeDistances) { home in
                    if home.id != otherHomeDistances.first?.id {
                        Divider()
                    }
                    Button {
                        openDirections(from: home)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: home.id == "current-location" ? "location.fill" : "arrow.triangle.turn.up.right.diamond.fill")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            Text(home.name)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                            if let time = home.travelTime {
                                Text(formatTravelTime(time))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("—")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func loadData() async {
        guard let houseId = appState.currentHouse?.id else { return }

        // Reset stale state
        weather = nil
        weatherTriggers = []
        actionItems = []
        weatherError = nil
        resolvedCoordinates = nil
        otherHomeDistances = []

        // Ensure profile is loaded for this house
        if appState.houseProfile?.houseId != houseId {
            if let profile = try? await FirebaseService.shared.fetchHouseProfile(houseId: houseId) {
                appState.houseProfile = profile
            }
        }

        isLoading = true
        do {
            async let tasksResult = FirebaseService.shared.fetchPendingMaintenanceItems(houseId: houseId)
            async let vendorsResult = FirebaseService.shared.fetchVendors(houseId: houseId)

            pendingTasks = try await tasksResult
            vendors = try await vendorsResult
        } catch {
            print("Failed to load home data: \(error)")
        }
        isLoading = false

        // Resolve coordinates and load weather first, then suggestions, then distances
        await loadWeather()
        suggestions = generateSuggestions()
        await loadDistances()
    }

    private func loadWeather() async {
        guard let houseId = appState.currentHouse?.id,
              let location = appState.houseProfile?.location else {
            weatherError = "No location set for this home"
            return
        }

        isLoadingWeather = true
        weatherError = nil

        do {
            var coordinates = location.coordinates
            if coordinates == nil {
                coordinates = try await GeocodingService.shared.geocodeAddress(
                    location.address,
                    city: location.city,
                    state: location.state,
                    zipCode: location.zipCode
                )
            }

            guard let coords = coordinates else {
                weatherError = "Could not determine location"
                isLoadingWeather = false
                return
            }

            resolvedCoordinates = coords

            let weatherData = try await WeatherService.shared.fetchWeather(for: houseId, coordinates: coords)
            weather = weatherData

            // Check triggers and generate action items
            let triggers = WeatherService.shared.checkWeatherTriggers(weatherData)
            weatherTriggers = triggers

            let systems = appState.houseProfile?.systems ?? []
            actionItems = WeatherService.shared.generateActionItems(triggers: triggers, systems: systems)
        } catch {
            weatherError = "Could not load weather"
        }
        isLoadingWeather = false
    }

    private func loadDistances() async {
        guard let homeCoords = resolvedCoordinates else { return }

        isLoadingDistances = true
        var results: [OtherHomeDistance] = []

        // Current device location
        let locationManager = CLLocationManager()
        if let deviceLocation = locationManager.location {
            let request = MKDirections.Request()
            request.source = MKMapItem(location: deviceLocation, address: nil)
            request.destination = MKMapItem(location: CLLocation(latitude: homeCoords.latitude, longitude: homeCoords.longitude), address: nil)
            request.transportType = .automobile
            let directions = MKDirections(request: request)
            let travelTime = (try? await directions.calculate())?.routes.first?.expectedTravelTime
            results.append(OtherHomeDistance(
                id: "current-location",
                name: "Current Location",
                travelTime: travelTime,
                coordinates: Coordinates(latitude: deviceLocation.coordinate.latitude, longitude: deviceLocation.coordinate.longitude)
            ))
        }

        // Other homes
        let otherHouses = appState.userHouses.filter { $0.id != appState.currentHouse?.id }
        for house in otherHouses {
            var coords: Coordinates?
            if let profile = try? await FirebaseService.shared.fetchHouseProfile(houseId: house.id) {
                if let loc = profile.location {
                    coords = loc.coordinates
                    if coords == nil {
                        coords = try? await GeocodingService.shared.geocodeAddress(
                            loc.address, city: loc.city, state: loc.state, zipCode: loc.zipCode
                        )
                    }
                }
            }

            var travelTime: TimeInterval?
            if let destCoords = coords {
                let request = MKDirections.Request()
                request.source = MKMapItem(location: CLLocation(latitude: destCoords.latitude, longitude: destCoords.longitude), address: nil)
                request.destination = MKMapItem(location: CLLocation(latitude: homeCoords.latitude, longitude: homeCoords.longitude), address: nil)
                request.transportType = .automobile
                let directions = MKDirections(request: request)
                if let response = try? await directions.calculate() {
                    travelTime = response.routes.first?.expectedTravelTime
                }
            }

            results.append(OtherHomeDistance(
                id: house.id,
                name: house.name ?? "Home",
                travelTime: travelTime,
                coordinates: coords
            ))
        }

        otherHomeDistances = results
        isLoadingDistances = false
    }

    private func formatTravelTime(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m drive"
        }
        return "\(minutes)m drive"
    }

    private func openDirections(from entry: OtherHomeDistance) {
        guard let homeCoords = resolvedCoordinates else { return }
        let destination = MKMapItem(location: CLLocation(latitude: homeCoords.latitude, longitude: homeCoords.longitude), address: nil)
        destination.name = appState.currentHouse?.name ?? "Home"

        let source: MKMapItem
        if entry.id == "current-location" {
            source = .forCurrentLocation()
        } else if let coords = entry.coordinates {
            source = MKMapItem(location: CLLocation(latitude: coords.latitude, longitude: coords.longitude), address: nil)
            source.name = entry.name
        } else {
            return
        }

        MKMapItem.openMaps(with: [source, destination], launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    // MARK: - Suggestion Persistence

    private func dismissedSuggestionIDs(for houseId: String) -> Set<String> {
        guard !dismissedSuggestionsData.isEmpty,
              let dict = try? JSONDecoder().decode([String: [String]].self, from: dismissedSuggestionsData) else {
            return []
        }
        return Set(dict[houseId] ?? [])
    }

    private func persistDismissal(_ id: String, for houseId: String) {
        var dict: [String: [String]] = [:]
        if !dismissedSuggestionsData.isEmpty,
           let existing = try? JSONDecoder().decode([String: [String]].self, from: dismissedSuggestionsData) {
            dict = existing
        }
        var ids = dict[houseId] ?? []
        if !ids.contains(id) {
            ids.append(id)
        }
        dict[houseId] = ids
        if let encoded = try? JSONEncoder().encode(dict) {
            dismissedSuggestionsData = encoded
        }
    }

    // MARK: - Suggestion Generation

    private func generateSuggestions() -> [Suggestion] {
        guard let houseId = appState.currentHouse?.id else { return [] }

        let dismissed = dismissedSuggestionIDs(for: houseId)
        let pendingTitles = Set(pendingTasks.map(\.title))
        var results: [Suggestion] = []

        // Weather suggestions
        for item in actionItems {
            let suggestionId = "weather-\(item.triggerType.rawValue)-\(item.title)"
            // Skip if already a pending task with same weather trigger
            let alreadyPending = pendingTasks.contains { task in
                task.isWeatherTriggered &&
                task.weatherTrigger?.type == item.triggerType &&
                task.title == item.title &&
                task.status == .pending
            }
            if !alreadyPending {
                results.append(Suggestion(
                    id: suggestionId,
                    title: item.title,
                    description: item.description,
                    icon: item.icon,
                    priority: item.priority,
                    relatedSystem: item.relatedSystem,
                    source: .weather(triggerType: item.triggerType)
                ))
            }
        }

        // Profile-based suggestions
        if let profile = appState.houseProfile {
            // System age rules
            for system in profile.systems {
                if let age = system.age {
                    switch system.type {
                    case .heating, .cooling:
                        if age >= 15 {
                            results.append(Suggestion(
                                id: "systemAge-\(system.type.rawValue)-HVAC inspection",
                                title: "Schedule HVAC inspection",
                                description: "Your \(system.type.rawValue.lowercased()) system is \(age) years old.",
                                icon: "magnifyingglass",
                                priority: .high,
                                relatedSystem: system.type,
                                source: .systemAge(systemType: system.type)
                            ))
                        }
                    case .roofing:
                        if age >= 20 {
                            results.append(Suggestion(
                                id: "systemAge-\(system.type.rawValue)-Roof inspection",
                                title: "Consider roof inspection",
                                description: "Your roof is \(age) years old — most last 20–25 years.",
                                icon: "house.fill",
                                priority: .high,
                                relatedSystem: .roofing,
                                source: .systemAge(systemType: .roofing)
                            ))
                        }
                    case .water:
                        if age >= 10 {
                            results.append(Suggestion(
                                id: "systemAge-\(system.type.rawValue)-Water heater replacement",
                                title: "Plan water heater replacement",
                                description: "Your water heater is \(age) years old — most last 10–15 years.",
                                icon: "drop.fill",
                                priority: .medium,
                                relatedSystem: .water,
                                source: .systemAge(systemType: .water)
                            ))
                        }
                    default:
                        break
                    }
                }

                // Service overdue
                if let lastServiced = system.lastServiced {
                    let yearsAgo = Calendar.current.dateComponents([.year], from: lastServiced, to: Date()).year ?? 0
                    if yearsAgo > 2 {
                        results.append(Suggestion(
                            id: "serviceOverdue-\(system.type.rawValue)",
                            title: "\(system.type.rawValue) service overdue",
                            description: "Last serviced \(yearsAgo) years ago.",
                            icon: "wrench.fill",
                            priority: .medium,
                            relatedSystem: system.type,
                            source: .serviceOverdue(systemType: system.type)
                        ))
                    }
                }
            }

            // Occupancy rules
            if let freq = profile.usagePattern?.occupancyFrequency,
               freq == .rarely || freq == .seasonally {
                results.append(Suggestion(
                    id: "occupancy-pest",
                    title: "Check for pest activity",
                    description: "This home is occupied \(freq.rawValue.lowercased()).",
                    icon: "ant.fill",
                    priority: .medium,
                    relatedSystem: nil,
                    source: .occupancy
                ))
                results.append(Suggestion(
                    id: "occupancy-water",
                    title: "Run water to prevent stagnation",
                    description: "Pipes can stagnate in \(freq.rawValue.lowercased()) occupied homes.",
                    icon: "drop.fill",
                    priority: .low,
                    relatedSystem: .plumbing,
                    source: .occupancy
                ))
            }

            // Seasonal rules
            let currentMonth = Calendar.current.component(.month, from: Date())
            let systemTypes = Set(profile.systems.map(\.type))

            // Fall: Sep–Nov
            if (9...11).contains(currentMonth) && systemTypes.contains(.heating) {
                results.append(Suggestion(
                    id: "seasonal-furnace",
                    title: "Schedule furnace tune-up",
                    description: "Fall is the best time to service heating before winter.",
                    icon: "flame.fill",
                    priority: .medium,
                    relatedSystem: .heating,
                    source: .seasonal
                ))
            }
            // Spring: Mar–May
            if (3...5).contains(currentMonth) {
                if systemTypes.contains(.cooling) {
                    results.append(Suggestion(
                        id: "seasonal-ac",
                        title: "Schedule AC tune-up",
                        description: "Spring is the best time to service cooling before summer.",
                        icon: "snowflake",
                        priority: .medium,
                        relatedSystem: .cooling,
                        source: .seasonal
                    ))
                }
                if systemTypes.contains(.landscaping) {
                    results.append(Suggestion(
                        id: "seasonal-irrigation",
                        title: "Inspect irrigation and drainage",
                        description: "Spring is the right time to check outdoor water systems.",
                        icon: "drop.triangle.fill",
                        priority: .low,
                        relatedSystem: .landscaping,
                        source: .seasonal
                    ))
                }
            }

            // Risk factor: winterExposure, medium+
            for risk in profile.riskFactors {
                if risk.type == .winterExposure && (risk.severity == .medium || risk.severity == .high) {
                    results.append(Suggestion(
                        id: "risk-winterize",
                        title: "Winterize the property",
                        description: "This property has \(risk.severity.rawValue.lowercased()) winter exposure risk.",
                        icon: "thermometer.snowflake",
                        priority: .high,
                        relatedSystem: nil,
                        source: .riskFactor
                    ))
                }
            }
        }

        // Filter: remove dismissed and already-pending tasks
        return results
            .filter { !dismissed.contains($0.id) }
            .filter { !pendingTitles.contains($0.title) }
            .sorted { $0.priority.sortOrder < $1.priority.sortOrder }
    }

    // MARK: - Suggestion Actions

    private func acceptSuggestion(_ suggestion: Suggestion) async {
        guard let houseId = appState.currentHouse?.id,
              let userId = appState.currentUser?.id else { return }

        var isWeatherTriggered = false
        var weatherTrigger: WeatherTrigger?
        if case .weather(let triggerType) = suggestion.source {
            isWeatherTriggered = true
            weatherTrigger = WeatherTrigger(type: triggerType)
        }

        let item = MaintenanceItem(
            houseId: houseId,
            title: suggestion.title,
            description: suggestion.description,
            priority: suggestion.priority,
            status: .pending,
            relatedSystem: suggestion.relatedSystem,
            isWeatherTriggered: isWeatherTriggered,
            weatherTrigger: weatherTrigger,
            createdBy: userId
        )

        do {
            try await FirebaseService.shared.saveMaintenanceItem(item)
            if let tasks = try? await FirebaseService.shared.fetchPendingMaintenanceItems(houseId: houseId) {
                pendingTasks = tasks
            }
            withAnimation {
                suggestions.removeAll { $0.id == suggestion.id }
            }
        } catch {
            print("Failed to save suggestion as task: \(error)")
        }
    }

    private func dismissSuggestionCard(_ suggestion: Suggestion) {
        guard let houseId = appState.currentHouse?.id else { return }
        persistDismissal(suggestion.id, for: houseId)
        withAnimation {
            suggestions.removeAll { $0.id == suggestion.id }
        }
    }

    private func addTaskFromAction(_ actionItem: WeatherActionItem) async {
        guard let houseId = appState.currentHouse?.id,
              let userId = appState.currentUser?.id else { return }

        let maintenanceItem = MaintenanceItem(
            houseId: houseId,
            title: actionItem.title,
            description: actionItem.description,
            category: .weatherAlert,
            priority: actionItem.priority,
            status: .pending,
            relatedSystem: actionItem.relatedSystem,
            isWeatherTriggered: true,
            weatherTrigger: WeatherTrigger(type: actionItem.triggerType),
            createdBy: userId
        )

        do {
            try await FirebaseService.shared.saveMaintenanceItem(maintenanceItem)
            // Reload pending tasks to show the new item
            if let tasks = try? await FirebaseService.shared.fetchPendingMaintenanceItems(houseId: houseId) {
                pendingTasks = tasks
            }
        } catch {
            print("Failed to save weather action task: \(error)")
        }
    }


}

// MARK: - Suggestion Card View

private struct SuggestionCardView: View {
    let suggestion: Suggestion
    let onAccept: () -> Void
    let onDismiss: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isRemoving = false

    private var priorityColor: Color {
        switch suggestion.priority {
        case .urgent: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        }
    }

    private var priorityDotColor: Color {
        switch suggestion.priority {
        case .urgent: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        }
    }

    var body: some View {
        ZStack {
            // Background hints
            HStack {
                if offset > 0 {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        Spacer()
                    }
                    .padding(.leading, 20)
                }
                if offset < 0 {
                    HStack {
                        Spacer()
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.title2)
                    }
                    .padding(.trailing, 20)
                }
            }

            // Card
            HStack(spacing: 12) {
                // Leading icon
                Circle()
                    .fill(priorityColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: suggestion.icon)
                            .font(.subheadline)
                            .foregroundColor(priorityColor)
                    )

                // Center text
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(suggestion.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Priority dot
                Circle()
                    .fill(priorityDotColor)
                    .frame(width: 8, height: 8)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .offset(x: offset)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        if !isRemoving {
                            offset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        guard !isRemoving else { return }
                        if value.translation.width > 100 {
                            isRemoving = true
                            withAnimation(.easeIn(duration: 0.2)) {
                                offset = UIScreen.main.bounds.width
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                onAccept()
                            }
                        } else if value.translation.width < -100 {
                            isRemoving = true
                            withAnimation(.easeIn(duration: 0.2)) {
                                offset = -UIScreen.main.bounds.width
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                onDismiss()
                            }
                        } else {
                            withAnimation(.spring()) {
                                offset = 0
                            }
                        }
                    }
            )
        }
    }
}

// MARK: - Weather Alert Card

struct WeatherAlertCard: View {
    let weather: WeatherData?
    let triggers: [WeatherTriggerType]
    let actionItems: [WeatherActionItem]
    let pendingTasks: [MaintenanceItem]
    let onAddTask: (WeatherActionItem) async -> Void

    private var highestPriority: MaintenancePriority {
        actionItems.map(\.priority).min(by: { $0.sortOrder < $1.sortOrder }) ?? .medium
    }

    private var bannerColor: Color {
        switch highestPriority {
        case .urgent: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        }
    }

    private var triggerHeadline: String {
        guard let weather = weather else { return triggers.first?.rawValue ?? "Weather Alert" }

        if triggers.contains(.freezeWarning) {
            if let forecast = weather.forecast.first(where: { $0.tempLow <= 32 }) {
                return "Freeze Warning — Low of \(Int(forecast.tempLow))°F \(forecast.dayName)"
            }
            return "Freeze Warning — \(Int(weather.current.temperature))°F"
        } else if triggers.contains(.highWind) {
            let maxWind = max(weather.current.windSpeed, weather.forecast.map(\.windSpeed).max() ?? 0)
            return "High Wind Warning — Gusts up to \(Int(maxWind)) mph"
        } else if triggers.contains(.snowStorm) {
            return "Snow Storm Warning — Heavy snow expected"
        } else if triggers.contains(.heavyRain) {
            return "Heavy Rain Warning — Significant rainfall expected"
        } else if triggers.contains(.heatWave) {
            if let forecast = weather.forecast.first(where: { $0.tempHigh >= 95 }) {
                return "Heat Wave — High of \(Int(forecast.tempHigh))°F \(forecast.dayName)"
            }
            return "Heat Wave Warning"
        }
        return triggers.first?.rawValue ?? "Weather Alert"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Alert banner
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(triggerHeadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(12)
            .background(bannerColor)

            // Action items (hide ones already added as tasks)
            let remainingItems = actionItems.filter { !isTaskAlreadyPending($0) }
            if !remainingItems.isEmpty {
                VStack(spacing: 0) {
                    ForEach(remainingItems) { item in
                        ActionItemRow(
                            item: item,
                            onAdd: { await onAddTask(item) }
                        )

                        if item.id != remainingItems.last?.id {
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
            }
        }
        .cornerRadius(12)
        .clipped()
    }

    private func isTaskAlreadyPending(_ actionItem: WeatherActionItem) -> Bool {
        pendingTasks.contains { task in
            task.isWeatherTriggered &&
            task.weatherTrigger?.type == actionItem.triggerType &&
            task.title == actionItem.title &&
            task.status == .pending
        }
    }
}

// MARK: - Action Item Row

struct ActionItemRow: View {
    let item: WeatherActionItem
    let onAdd: () async -> Void
    @State private var isAdding = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.body)
                .foregroundColor(priorityColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(item.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if isAdding {
                ProgressView()
            } else {
                Button {
                    Task {
                        isAdding = true
                        await onAdd()
                        isAdding = false
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var priorityColor: Color {
        switch item.priority {
        case .urgent: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        }
    }
}

// MARK: - NWS Alert Card

struct NWSAlertCard: View {
    let alerts: [WeatherAlert]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(alerts) { alert in
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(alert.event)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(alertTimeRange(alert))
                            .font(.caption)
                    }
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(12)
                .background(alertColor(for: alert.severity))
                .cornerRadius(12)
            }
        }
    }

    private func alertColor(for severity: AlertSeverity) -> Color {
        switch severity {
        case .advisory: return .yellow
        case .watch: return .orange
        case .warning: return .red
        case .extreme: return .purple
        }
    }

    private func alertTimeRange(_ alert: WeatherAlert) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE h:mm a"
        return "\(formatter.string(from: alert.start)) – \(formatter.string(from: alert.end))"
    }
}

// MARK: - Compact Weather View

struct CompactWeatherView: View {
    let weather: WeatherData
    var hasAlerts: Bool = false

    var body: some View {
        HStack {
            Image(systemName: weather.current.weatherIcon)
                .font(.title)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(weather.current.temperatureDisplay)
                        .font(.title2)
                        .fontWeight(.semibold)
                    if hasAlerts {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                }
                Text(weather.current.description.capitalized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !weather.forecast.isEmpty {
                HStack(spacing: 12) {
                    ForEach(weather.forecast.prefix(3)) { day in
                        VStack(spacing: 3) {
                            Text(day.dayName)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Image(systemName: day.weatherIcon)
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text("\(Int(day.tempHigh))°")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Weather Detail Screen

struct WeatherDetailScreen: View {
    let weather: WeatherData
    var triggers: [WeatherTriggerType] = []
    var actionItems: [WeatherActionItem] = []
    var pendingTasks: [MaintenanceItem] = []
    var onAddTask: ((WeatherActionItem) async -> Void)?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Weather triggers with action items
                if !triggers.isEmpty, let onAddTask = onAddTask {
                    WeatherAlertCard(
                        weather: weather,
                        triggers: triggers,
                        actionItems: actionItems,
                        pendingTasks: pendingTasks,
                        onAddTask: onAddTask
                    )
                }

                // NWS alerts
                if !weather.alerts.isEmpty {
                    NWSAlertCard(alerts: weather.alerts)
                }

                // Current conditions
                CardSection(title: "Current") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(weather.current.temperatureDisplay)
                                .font(.largeTitle)
                                .fontWeight(.semibold)
                            Text(weather.current.description.capitalized)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: weather.current.weatherIcon)
                            .font(.system(size: 48))
                            .foregroundColor(.blue)
                    }

                    HStack(spacing: 24) {
                        Label("Feels \(Int(weather.current.feelsLike))°", systemImage: "thermometer.medium")
                        Label("\(weather.current.humidity)%", systemImage: "humidity.fill")
                        Label("\(Int(weather.current.windSpeed)) mph", systemImage: "wind")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                // 7-day forecast
                CardSection(title: "7-Day Forecast") {
                    VStack(spacing: 10) {
                        ForEach(weather.forecast.prefix(7)) { day in
                            HStack {
                                Text(day.dayName)
                                    .font(.subheadline)
                                    .frame(width: 40, alignment: .leading)

                                Image(systemName: day.weatherIcon)
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                    .frame(width: 24)

                                if day.precipProbability > 0 {
                                    Text("\(Int(day.precipProbability * 100))%")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .frame(width: 36, alignment: .trailing)
                                } else {
                                    Spacer()
                                        .frame(width: 36)
                                }

                                Spacer()

                                Text("\(Int(day.tempLow))°")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(width: 32, alignment: .trailing)

                                TemperatureBar(
                                    low: day.tempLow,
                                    high: day.tempHigh,
                                    rangeLow: weather.forecast.prefix(7).map(\.tempLow).min() ?? day.tempLow,
                                    rangeHigh: weather.forecast.prefix(7).map(\.tempHigh).max() ?? day.tempHigh
                                )
                                .frame(width: 80)

                                Text("\(Int(day.tempHigh))°")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(width: 32, alignment: .trailing)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Weather")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Temperature Bar

struct TemperatureBar: View {
    let low: Double
    let high: Double
    let rangeLow: Double
    let rangeHigh: Double

    private var startFraction: CGFloat {
        guard rangeHigh > rangeLow else { return 0 }
        return CGFloat((low - rangeLow) / (rangeHigh - rangeLow))
    }

    private var endFraction: CGFloat {
        guard rangeHigh > rangeLow else { return 1 }
        return CGFloat((high - rangeLow) / (rangeHigh - rangeLow))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemGray4))
                    .frame(height: 4)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: max(4, geo.size.width * (endFraction - startFraction)),
                        height: 4
                    )
                    .offset(x: geo.size.width * startFraction)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Card Section

struct CardSection<Content: View>: View {
    let title: String
    var showChevron: Bool = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tertiary)
                }
            }
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Quick Stats Row

struct QuickStatsRow: View {
    let profile: HouseProfile

    var body: some View {
        HStack(spacing: 12) {
            if let age = profile.age {
                StatBadge(label: "Age", value: "\(age) yrs")
            }
            if let bedrooms = profile.size?.bedrooms {
                StatBadge(label: "Beds", value: "\(bedrooms)")
            }
            if let bathrooms = profile.size?.bathrooms {
                StatBadge(label: "Baths", value: "\(bathrooms)")
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct StatBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    HomeView(appState: AppState())
}
