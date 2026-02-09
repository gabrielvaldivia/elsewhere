//
//  HouseProfileView.swift
//  Elsewhere
//
//  Created on 12/12/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var editedProfile: HouseProfile?
    @State private var name: String = ""
    @State private var address: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var zipCode: String = ""
    @State private var age: Int?
    @State private var occupancyFrequency: OccupancyFrequency?
    @State private var typicalStayDuration: Int?
    @State private var squareFeet: String = ""
    @State private var showSquareFeet: Bool = false
    @State private var bedrooms: Int?
    @State private var bathrooms: Int?
    @State private var lotSize: String = ""
    @State private var showLotSize: Bool = false
    @State private var isPrimary = false
    @State private var showingManageMembers = false
    @State private var showingInviteMember = false
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        Group {
            // Always show the form fields, even if profile is nil
            if let profile = appState.houseProfile {
                profileContent(profile)
            } else {
                // Show empty form when no profile exists
                profileContent(HouseProfile(
                    houseId: appState.currentHouse?.id ?? "placeholder",
                    name: nil,
                    location: nil,
                    age: nil,
                    systems: [],
                    usagePattern: nil,
                    riskFactors: []
                ))
            }
        }
        .onChange(of: appState.houseProfile) { _, newProfile in
            if let profile = newProfile {
                updateStateFromProfile(profile)
            }
        }
        .onAppear {
            if let profile = appState.houseProfile {
                updateStateFromProfile(profile)
            }
        }
        .onDisappear {
            saveProfile()
        }
    }
    
    private func updateStateFromProfile(_ profile: HouseProfile) {
        name = profile.name ?? ""
        address = profile.location?.address ?? ""
        city = profile.location?.city ?? ""
        state = profile.location?.state ?? ""
        zipCode = profile.location?.zipCode ?? ""
        age = profile.age
        occupancyFrequency = profile.usagePattern?.occupancyFrequency
        typicalStayDuration = profile.usagePattern?.typicalStayDuration
        isPrimary = appState.currentHouse?.isPrimary ?? false
        editedProfile = profile

        // Load house size
        if let size = profile.size {
            squareFeet = size.squareFeet.map { String($0) } ?? ""
            showSquareFeet = size.squareFeet != nil
            bedrooms = size.bedrooms
            bathrooms = size.bathrooms
            lotSize = size.lotSize.map { String($0) } ?? ""
            showLotSize = size.lotSize != nil
        } else {
            squareFeet = ""
            showSquareFeet = false
            bedrooms = nil
            bathrooms = nil
            lotSize = ""
            showLotSize = false
        }
        
    }
    
    private func profileContent(_ profile: HouseProfile) -> some View {
        Form {
            Section("Name") {
                TextField("House Name", text: $name)
                    .onSubmit {
                        saveProfile()
                    }
            }
            
            if appState.userHouses.count > 1 {
                Section {
                    Toggle("Primary Home", isOn: $isPrimary)
                        .onChange(of: isPrimary) { _, newValue in
                            if newValue {
                                togglePrimary()
                            }
                        }
                } footer: {
                    Text("Your primary home is auto-selected when you open the app.")
                }
            }

            Section("Location") {
                TextField("Address", text: $address)
                    .onSubmit {
                        saveProfile()
                    }
                TextField("City", text: $city)
                    .onSubmit {
                        saveProfile()
                    }
                Picker("State", selection: $state) {
                    Text("Select State").tag("")
                    ForEach(USStates.allStates, id: \.abbreviation) { stateOption in
                        Text("\(stateOption.name)").tag(stateOption.abbreviation)
                    }
                }
                .onChange(of: state) { _, _ in
                    saveProfile()
                }
                TextField("ZIP Code", text: $zipCode)
                    .onSubmit {
                        saveProfile()
                    }
            }
            
            Section("Age") {
                if let currentAge = age {
                    Stepper("\(currentAge) years", value: Binding(
                        get: { currentAge },
                        set: { newAge in
                            age = newAge
                            saveProfile()
                        }
                    ), in: 0...200)
                } else {
                    Button("Add Age") {
                        age = 0
                        saveProfile()
                    }
                }
            }
            
            Section("Size") {
                if showSquareFeet {
                    TextField("Square Feet", text: $squareFeet)
                        .keyboardType(.numberPad)
                        .onSubmit {
                            saveProfile()
                        }
                } else {
                    Button("Add Square Feet") {
                        squareFeet = ""
                        showSquareFeet = true
                        saveProfile()
                    }
                }
                
                if let currentBedrooms = bedrooms {
                    Stepper("Bedrooms: \(currentBedrooms)", value: Binding(
                        get: { currentBedrooms },
                        set: { newValue in
                            bedrooms = newValue
                            saveProfile()
                        }
                    ), in: 0...20)
                } else {
                    Button("Add Bedrooms") {
                        bedrooms = 1
                        saveProfile()
                    }
                }
                
                if let currentBathrooms = bathrooms {
                    Stepper("Bathrooms: \(currentBathrooms)", value: Binding(
                        get: { currentBathrooms },
                        set: { newValue in
                            bathrooms = newValue
                            saveProfile()
                        }
                    ), in: 0...20)
                } else {
                    Button("Add Bathrooms") {
                        bathrooms = 1
                        saveProfile()
                    }
                }
                
                if showLotSize {
                    TextField("Lot Size (acres)", text: $lotSize)
                        .keyboardType(.decimalPad)
                        .onSubmit {
                            saveProfile()
                        }
                } else {
                    Button("Add Lot Size") {
                        lotSize = ""
                        showLotSize = true
                        saveProfile()
                    }
                }
            }

            Section("Typical Stay") {
                if let frequency = occupancyFrequency {
                    Picker("Frequency", selection: Binding(
                        get: { frequency },
                        set: { newFrequency in
                            occupancyFrequency = newFrequency
                            saveProfile()
                        }
                    )) {
                        ForEach([OccupancyFrequency.daily, .weekly, .biweekly, .monthly, .seasonally, .rarely], id: \.self) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                    .onChange(of: occupancyFrequency) { _, _ in
                        saveProfile()
                    }
                } else {
                    Button("Add Frequency") {
                        occupancyFrequency = .monthly
                        saveProfile()
                    }
                }
                
                if let duration = typicalStayDuration {
                    Stepper("Duration: \(duration) days", value: Binding(
                        get: { duration },
                        set: { newDuration in
                            typicalStayDuration = newDuration
                            saveProfile()
                        }
                    ), in: 1...365)
                } else {
                    Button("Add Duration") {
                        typicalStayDuration = 7
                        saveProfile()
                    }
                }
            }

            if !profile.riskFactors.isEmpty {
                Section("Risk Factors") {
                    ForEach(profile.riskFactors) { risk in
                        HStack {
                            Text(risk.type.rawValue)
                            Spacer()
                            Text(risk.severity.rawValue)
                                .foregroundColor(severityColor(risk.severity))
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(severityColor(risk.severity).opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                }
            }

            // Members Section
            Section("Members") {
                Button {
                    showingManageMembers = true
                } label: {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.blue)
                        Text("Manage Members")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Button {
                    showingInviteMember = true
                } label: {
                    HStack {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(.green)
                        Text("Invite Someone")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Home")
                    }
                }
            } footer: {
                Text("This will permanently delete this home and all associated data.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingManageMembers) {
            HouseAccessView(appState: appState)
        }
        .sheet(isPresented: $showingInviteMember) {
            InviteMemberView(appState: appState)
        }
        .alert("Delete Home", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteHome()
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(appState.currentHouse?.name ?? "this home")\"? This will permanently delete all data including chat history, tasks, and vendors.")
        }
    }
    
    private func saveProfile() {
        // If no profile exists, create a new house and profile first
        guard let userId = appState.currentUser?.id else { return }
        
        Task {
            do {
                var house: House
                var profile: HouseProfile
                
                if let existingHouse = appState.currentHouse, let existingProfile = appState.houseProfile {
                    // Update existing profile
                    house = existingHouse
                    profile = existingProfile
                } else {
                    // Create new house and profile
                    house = House(
                        createdBy: userId,
                        ownerIds: [userId],
                        memberIds: []
                    )
                    profile = HouseProfile(
                        houseId: house.id,
                        name: nil,
                        location: nil,
                        age: nil,
                        systems: [],
                        usagePattern: nil,
                        riskFactors: []
                    )
                    
                    // Save house first
                    try await FirebaseService.shared.createHouse(house)
                }
                
                // Update profile with current field values
                profile.name = name.isEmpty ? nil : name
                
                if !address.isEmpty || !city.isEmpty || !state.isEmpty || !zipCode.isEmpty {
                    profile.location = Location(
                        address: address,
                        city: city,
                        state: state,
                        zipCode: zipCode,
                        coordinates: profile.location?.coordinates
                    )
                } else {
                    profile.location = nil
                }
                
                profile.age = age
                
                profile.usagePattern = UsagePattern(
                    occupancyFrequency: occupancyFrequency,
                    typicalStayDuration: typicalStayDuration,
                    seasonalUsage: occupancyFrequency == .seasonally,
                    notes: profile.usagePattern?.notes
                )
                
                // Update house size
                var houseSize = HouseSize()
                if showSquareFeet && !squareFeet.isEmpty, let sqft = Int(squareFeet), sqft > 0 {
                    houseSize.squareFeet = sqft
                }
                houseSize.bedrooms = bedrooms
                houseSize.bathrooms = bathrooms
                if showLotSize && !lotSize.isEmpty, let lot = Double(lotSize), lot > 0 {
                    houseSize.lotSize = lot
                }
                profile.size = (houseSize.squareFeet != nil || houseSize.bedrooms != nil || houseSize.bathrooms != nil || houseSize.lotSize != nil) ? houseSize : nil
                
                profile.updatedAt = Date()
                
                // Save to Firebase and update app state
                try await FirebaseService.shared.saveHouseProfile(profile)
                await MainActor.run {
                    appState.setCurrentHouse(house, profile: profile)
                    editedProfile = profile
                }
            } catch {
                print("❌ Failed to save profile: \(error)")
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "house.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No House Profile")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Your house profile will be built through conversation with the agent in the Chat tab.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .navigationTitle("House Profile")
    }
    
    private func severityColor(_ severity: RiskSeverity) -> Color {
        switch severity {
        case .low:
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }

    private func togglePrimary() {
        guard let houseId = appState.currentHouse?.id,
              let userId = appState.currentUser?.id else { return }
        Task {
            do {
                try await FirebaseService.shared.setHousePrimary(houseId: houseId, userId: userId)
                await appState.loadUserHouses()
                print("✅ Set \(appState.currentHouse?.name ?? houseId) as primary")
            } catch {
                print("❌ Failed to set primary: \(error)")
                await MainActor.run { isPrimary = false }
            }
        }
    }

    private func deleteHome() async {
        guard let houseId = appState.currentHouse?.id else { return }

        do {
            // Delete all data for this house from Firebase
            try await FirebaseService.shared.deleteAllDataForHouse(houseId: houseId)

            // Update app state - remove from list and clear current house
            await MainActor.run {
                appState.userHouses.removeAll { $0.id == houseId }
                appState.currentHouse = nil
                appState.houseProfile = nil
            }

            print("✅ Deleted home: \(houseId)")
        } catch {
            print("❌ Failed to delete home: \(error)")
        }
    }
}


// MARK: - Weather Summary Row

struct WeatherSummaryRow: View {
    @ObservedObject var appState: AppState
    @State private var weather: WeatherData?
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading {
                HStack {
                    ProgressView()
                    Text("Loading weather...")
                        .foregroundColor(.secondary)
                }
            } else if let weather = weather {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: weatherIcon(weather.current.icon))
                            .font(.title)
                            .foregroundColor(.blue)

                        VStack(alignment: .leading) {
                            Text("\(Int(weather.current.temperature))°F")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text(weather.current.description.capitalized)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    if !weather.forecast.isEmpty {
                        Divider()
                        HStack(spacing: 16) {
                            ForEach(weather.forecast.prefix(4)) { day in
                                VStack(spacing: 4) {
                                    Text(day.dayName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Image(systemName: weatherIcon(day.icon))
                                        .font(.caption)
                                    Text("\(Int(day.tempHigh))°")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            } else if let error = error {
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Button("Load Weather") {
                    loadWeather()
                }
            }
        }
        .onAppear {
            if weather == nil && !isLoading {
                loadWeather()
            }
        }
    }

    private func loadWeather() {
        guard let houseId = appState.currentHouse?.id,
              let location = appState.houseProfile?.location else {
            error = "No location set for this home"
            return
        }

        isLoading = true
        error = nil

        Task {
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
                    await MainActor.run {
                        error = "Could not determine location"
                        isLoading = false
                    }
                    return
                }

                let weatherData = try await WeatherService.shared.fetchWeather(for: houseId, coordinates: coords)
                await MainActor.run {
                    self.weather = weatherData
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = "Could not load weather"
                    isLoading = false
                }
            }
        }
    }

    private func weatherIcon(_ icon: String) -> String {
        switch icon {
        case "01d": return "sun.max.fill"
        case "01n": return "moon.fill"
        case "02d", "02n": return "cloud.sun.fill"
        case "03d", "03n", "04d", "04n": return "cloud.fill"
        case "09d", "09n": return "cloud.drizzle.fill"
        case "10d", "10n": return "cloud.rain.fill"
        case "11d", "11n": return "cloud.bolt.fill"
        case "13d", "13n": return "cloud.snow.fill"
        case "50d", "50n": return "cloud.fog.fill"
        default: return "cloud.fill"
        }
    }
}

#Preview {
    SettingsView(appState: AppState())
}

