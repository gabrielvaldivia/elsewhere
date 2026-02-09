//
//  HomeView.swift
//  Elsewhere
//
//  Created on 2/8/26.
//

import SwiftUI

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

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 16) {
                    // Weather alerts (shown above pending tasks when active)
                    if !weatherTriggers.isEmpty {
                        WeatherAlertCard(
                            weather: weather,
                            triggers: weatherTriggers,
                            actionItems: actionItems,
                            pendingTasks: pendingTasks,
                            onAddTask: { item in
                                await addTaskFromAction(item)
                            }
                        )
                    }

                    // NWS alerts
                    if let weather = weather, !weather.alerts.isEmpty {
                        NWSAlertCard(alerts: weather.alerts.filter { $0.isActive })
                    }

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
                                CompactWeatherView(weather: weather)
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
                                        if item.id != pendingTasks.first?.id {
                                            Divider()
                                        }
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

    private func loadData() async {
        guard let houseId = appState.currentHouse?.id else { return }

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

        // Load weather data
        await loadWeather()
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

    var body: some View {
        HStack {
            Image(systemName: weather.current.weatherIcon)
                .font(.title)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(weather.current.temperatureDisplay)
                    .font(.title2)
                    .fontWeight(.semibold)
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
                // Current conditions
                CardSection(title: "Current") {
                    HStack {
                        Image(systemName: weather.current.weatherIcon)
                            .font(.system(size: 48))
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(weather.current.temperatureDisplay)
                                .font(.largeTitle)
                                .fontWeight(.semibold)
                            Text(weather.current.description.capitalized)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
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
