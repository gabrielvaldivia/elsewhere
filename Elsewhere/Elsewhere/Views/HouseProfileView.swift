//
//  HouseProfileView.swift
//  Elsewhere
//
//  Created on 12/12/25.
//

import SwiftUI

struct HouseProfileView: View {
    @ObservedObject var appState: AppState
    @State private var editedProfile: HouseProfile?
    @State private var name: String = ""
    @State private var address: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var zipCode: String = ""
    @State private var age: Int?
    @State private var occupancyFrequency: OccupancyFrequency = .monthly
    @State private var typicalStayDuration: Int?
    @State private var systemsDict: [SystemType: HouseSystem] = [:]
    @State private var squareFeet: String = ""
    @State private var bedrooms: Int?
    @State private var bathrooms: Int?
    @State private var lotSize: String = ""
    
    var body: some View {
        NavigationStack {
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
        occupancyFrequency = profile.usagePattern?.occupancyFrequency ?? .monthly
        typicalStayDuration = profile.usagePattern?.typicalStayDuration
        editedProfile = profile
        
        // Load house size
        if let size = profile.size {
            squareFeet = size.squareFeet.map { String($0) } ?? ""
            bedrooms = size.bedrooms
            bathrooms = size.bathrooms
            lotSize = size.lotSize.map { String($0) } ?? ""
        } else {
            squareFeet = ""
            bedrooms = nil
            bathrooms = nil
            lotSize = ""
        }
        
        // Load systems into dictionary
        systemsDict = Dictionary(uniqueKeysWithValues: profile.systems.map { ($0.type, $0) })
    }
    
    private func profileContent(_ profile: HouseProfile) -> some View {
        Form {
            Section("Name") {
                TextField("House Name", text: $name)
                    .onSubmit {
                        saveProfile()
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
                TextField("Square Feet", text: $squareFeet)
                    .keyboardType(.numberPad)
                    .onSubmit {
                        saveProfile()
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
                
                TextField("Lot Size (acres)", text: $lotSize)
                    .keyboardType(.decimalPad)
                    .onSubmit {
                        saveProfile()
                    }
            }
            
            
            
            Section("Typical Stay") {
                Picker("Frequency", selection: $occupancyFrequency) {
                    ForEach([OccupancyFrequency.daily, .weekly, .biweekly, .monthly, .seasonally, .rarely], id: \.self) { freq in
                        Text(freq.rawValue).tag(freq)
                    }
                }
                .onChange(of: occupancyFrequency) { _, _ in
                    saveProfile()
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

            Section("Systems") {
                // Show existing systems from dictionary
                ForEach(Array(systemsDict.values).sorted(by: { $0.type.rawValue < $1.type.rawValue }), id: \.id) { system in
                    SystemDetailRow(
                        system: system,
                        systemBinding: Binding(
                            get: { systemsDict[system.type] ?? system },
                            set: { updatedSystem in
                                systemsDict[system.type] = updatedSystem
                                saveProfile()
                            }
                        ),
                        onRemove: {
                            systemsDict.removeValue(forKey: system.type)
                            saveProfile()
                        },
                        onSave: {
                            saveProfile()
                        }
                    )
                }
                .onDelete { indexSet in
                    let systems = Array(systemsDict.values).sorted(by: { $0.type.rawValue < $1.type.rawValue })
                    for index in indexSet {
                        let system = systems[index]
                        systemsDict.removeValue(forKey: system.type)
                    }
                    saveProfile()
                }
                
                // Add new system button - show systems not yet added
                if systemsDict.count < SystemType.allCases.count {
                    Menu {
                        ForEach(SystemType.allCases.filter { systemsDict[$0] == nil }, id: \.self) { systemType in
                            Button(systemType.rawValue) {
                                addSystem(systemType)
                            }
                        }
                    } label: {
                        HStack {
                            Text("Add System")
                        }
                        .foregroundColor(.blue)
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
            
            Section {
                Button(role: .destructive, action: {
                    Task {
                        await deleteAllData()
                    }
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete All Data")
                    }
                }
            }
        }
        .navigationTitle("House Profile")
        .navigationBarTitleDisplayMode(.inline)
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
                if !squareFeet.isEmpty, let sqft = Int(squareFeet) {
                    houseSize.squareFeet = sqft
                }
                houseSize.bedrooms = bedrooms
                houseSize.bathrooms = bathrooms
                if !lotSize.isEmpty, let lot = Double(lotSize) {
                    houseSize.lotSize = lot
                }
                profile.size = (houseSize.squareFeet != nil || houseSize.bedrooms != nil || houseSize.bathrooms != nil || houseSize.lotSize != nil) ? houseSize : nil
                
                // Update systems from dictionary
                profile.systems = Array(systemsDict.values)
                
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
    
    private func addSystem(_ systemType: SystemType) {
        systemsDict[systemType] = HouseSystem(type: systemType)
        saveProfile()
    }
    
    private func updateSystemInProfile(_ system: HouseSystem) {
        systemsDict[system.type] = system
        saveProfile()
    }
    
    private func removeSystemFromProfile(_ systemType: SystemType) {
        systemsDict.removeValue(forKey: systemType)
        saveProfile()
    }
    
    private func deleteAllData() async {
        guard let houseId = appState.currentHouse?.id,
              let userId = appState.currentUser?.id else { return }
        
        do {
            // Delete all data from Firebase
            try await FirebaseService.shared.deleteAllDataForHouse(houseId: houseId)
            
            // Create a new empty house and profile
            let newHouse = House(
                createdBy: userId,
                ownerIds: [userId],
                memberIds: []
            )
            
            let newProfile = HouseProfile(
                houseId: newHouse.id,
                name: nil,
                location: nil,
                age: nil,
                systems: [],
                usagePattern: nil,
                riskFactors: []
            )
            
            // Save the new empty house and profile to Firebase
            try await FirebaseService.shared.createHouse(newHouse)
            try await FirebaseService.shared.saveHouseProfile(newProfile)
            
            // Update app state with the new empty house and profile
            await MainActor.run {
                appState.setCurrentHouse(newHouse, profile: newProfile)
                updateStateFromProfile(newProfile)
            }
            
            print("✅ All data cleared. New empty house and profile created.")
        } catch {
            print("❌ Failed to clear data: \(error)")
        }
    }
}


#Preview {
    HouseProfileView(appState: AppState())
}

