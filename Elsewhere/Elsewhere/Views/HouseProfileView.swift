//
//  HouseProfileView.swift
//  Elsewhere
//
//  Created on 12/12/25.
//

import SwiftUI

struct HouseProfileView: View {
    @ObservedObject var appState: AppState
    @State private var isEditing = false
    
    var body: some View {
        NavigationStack {
            if let profile = appState.houseProfile {
                profileContent(profile)
            } else {
                emptyState
            }
        }
    }
    
    private func profileContent(_ profile: HouseProfile) -> some View {
        Form {
            Section("Location") {
                if let location = profile.location {
                    LabeledContent("Address", value: location.address)
                    LabeledContent("City", value: location.city)
                    LabeledContent("State", value: location.state)
                    LabeledContent("ZIP", value: location.zipCode)
                } else {
                    Text("Not set")
                        .foregroundColor(.secondary)
                }
            }
            
            if let age = profile.age {
                Section("Details") {
                    LabeledContent("Age", value: "\(age) years")
                }
            }
            
            if !profile.systems.isEmpty {
                Section("Systems") {
                    ForEach(profile.systems) { system in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(system.type.rawValue)
                                .font(.headline)
                            if let description = system.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            
            if let usagePattern = profile.usagePattern {
                Section("Usage") {
                    LabeledContent("Frequency", value: usagePattern.occupancyFrequency.rawValue)
                    if let duration = usagePattern.typicalStayDuration {
                        LabeledContent("Typical Stay", value: "\(duration) days")
                    }
                    LabeledContent("Seasonal", value: usagePattern.seasonalUsage ? "Yes" : "No")
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    isEditing = true
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            EditHouseProfileView(profile: profile, appState: appState)
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
    
    private func deleteAllData() async {
        guard let houseId = appState.currentHouse?.id else { return }
        
        do {
            // Delete all data from Firebase
            try await FirebaseService.shared.deleteAllDataForHouse(houseId: houseId)
            
            // Reset app state
            await MainActor.run {
                appState.currentHouse = nil
                appState.houseProfile = nil
            }
            
            print("✅ All data cleared. Onboarding will restart in Chat.")
        } catch {
            print("❌ Failed to clear data: \(error)")
        }
    }
}

struct EditHouseProfileView: View {
    @Environment(\.dismiss) var dismiss
    let profile: HouseProfile
    @ObservedObject var appState: AppState
    
    @State private var editedProfile: HouseProfile
    @State private var address: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var zipCode: String = ""
    @State private var age: Int?
    
    init(profile: HouseProfile, appState: AppState) {
        self.profile = profile
        self.appState = appState
        _editedProfile = State(initialValue: profile)
        _address = State(initialValue: profile.location?.address ?? "")
        _city = State(initialValue: profile.location?.city ?? "")
        _state = State(initialValue: profile.location?.state ?? "")
        _zipCode = State(initialValue: profile.location?.zipCode ?? "")
        _age = State(initialValue: profile.age)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Location") {
                    TextField("Address", text: $address)
                    TextField("City", text: $city)
                    TextField("State", text: $state)
                    TextField("ZIP Code", text: $zipCode)
                }
                
                Section("Details") {
                    if let currentAge = age {
                        Stepper("Age: \(currentAge) years", value: Binding(
                            get: { currentAge },
                            set: { age = $0 }
                        ), in: 0...200)
                    } else {
                        Button("Add Age") {
                            age = 0
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                    }
                }
            }
        }
    }
    
    private func saveProfile() {
        // Update location
        if !address.isEmpty || !city.isEmpty || !state.isEmpty || !zipCode.isEmpty {
            editedProfile.location = Location(
                address: address,
                city: city,
                state: state,
                zipCode: zipCode,
                coordinates: editedProfile.location?.coordinates
            )
        }
        
        // Update age
        editedProfile.age = age
        editedProfile.updatedAt = Date()
        
        // TODO: Save to Firebase
        appState.setHouseProfile(editedProfile)
        dismiss()
    }
}

#Preview {
    HouseProfileView(appState: AppState())
}

