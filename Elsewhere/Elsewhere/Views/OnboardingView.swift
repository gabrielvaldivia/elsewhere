//
//  OnboardingView.swift
//  Elsewhere
//
//  Created on 12/12/25.
//

import SwiftUI

struct OnboardingView: View {
    @ObservedObject var appState: AppState
    @StateObject private var onboardingViewModel = OnboardingViewModel()
    @State private var showingLocationForm = false
    @State private var showingAgeForm = false
    @State private var showingSystemsForm = false
    @State private var showingUsageForm = false
    @State private var isCreatingHouse = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "house.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Welcome to Upstate Home Copilot")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Let's get to know your second home. I'll ask you a few questions to set everything up.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 16) {
                    OnboardingItem(
                        title: "Location",
                        isComplete: onboardingViewModel.collectedData.isLocationComplete,
                        action: { showingLocationForm = true }
                    )
                    
                    OnboardingItem(
                        title: "Age",
                        isComplete: onboardingViewModel.collectedData.isAgeComplete,
                        action: { showingAgeForm = true }
                    )
                    
                    OnboardingItem(
                        title: "Systems",
                        isComplete: onboardingViewModel.collectedData.isSystemsComplete,
                        action: { showingSystemsForm = true }
                    )
                    
                    OnboardingItem(
                        title: "Usage Pattern",
                        isComplete: onboardingViewModel.collectedData.isUsagePatternComplete,
                        action: { showingUsageForm = true }
                    )
                }
                .padding()
                
                Spacer()
                
                Button(action: createHouse) {
                    HStack {
                        if isCreatingHouse {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(isCreatingHouse ? "Creating..." : "Complete Setup")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(onboardingViewModel.collectedData.isComplete ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!onboardingViewModel.collectedData.isComplete || isCreatingHouse)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingLocationForm) {
                LocationFormView(onboardingViewModel: onboardingViewModel)
            }
            .sheet(isPresented: $showingAgeForm) {
                AgeFormView(onboardingViewModel: onboardingViewModel)
            }
            .sheet(isPresented: $showingSystemsForm) {
                SystemsFormView(onboardingViewModel: onboardingViewModel)
            }
            .sheet(isPresented: $showingUsageForm) {
                UsagePatternFormView(onboardingViewModel: onboardingViewModel)
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    private func createHouse() {
        guard let userId = appState.currentUser?.id else {
            errorMessage = "Please wait for authentication to complete"
            return
        }
        
        isCreatingHouse = true
        errorMessage = nil
        
        Task {
            do {
                let (house, profile) = try await onboardingViewModel.createHouse(userId: userId)
                
                await MainActor.run {
                    appState.setCurrentHouse(house)
                    appState.setHouseProfile(profile)
                    isCreatingHouse = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreatingHouse = false
                }
            }
        }
    }
}

struct OnboardingItem: View {
    let title: String
    let isComplete: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isComplete ? .green : .gray)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
}

struct LocationFormView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var onboardingViewModel: OnboardingViewModel
    
    @State private var address: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var zipCode: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Address") {
                    TextField("Street Address", text: $address)
                    TextField("City", text: $city)
                    TextField("State", text: $state)
                    TextField("ZIP Code", text: $zipCode)
                }
            }
            .navigationTitle("House Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveLocation()
                    }
                    .disabled(address.isEmpty || city.isEmpty || state.isEmpty || zipCode.isEmpty)
                }
            }
            .onAppear {
                if let location = onboardingViewModel.collectedData.location {
                    address = location.address
                    city = location.city
                    state = location.state
                    zipCode = location.zipCode
                }
            }
        }
    }
    
    private func saveLocation() {
        onboardingViewModel.collectedData.location = Location(
            address: address,
            city: city,
            state: state,
            zipCode: zipCode,
            coordinates: nil
        )
        dismiss()
    }
}

struct AgeFormView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var onboardingViewModel: OnboardingViewModel
    
    @State private var age: Int = 0
    
    var body: some View {
        NavigationStack {
            Form {
                Section("House Age") {
                    Stepper("Age: \(age) years", value: $age, in: 0...200)
                }
            }
            .navigationTitle("House Age")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAge()
                    }
                }
            }
            .onAppear {
                if let existingAge = onboardingViewModel.collectedData.age {
                    age = existingAge
                }
            }
        }
    }
    
    private func saveAge() {
        onboardingViewModel.collectedData.age = age
        dismiss()
    }
}

struct SystemsFormView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var onboardingViewModel: OnboardingViewModel
    
    @State private var selectedSystems: Set<SystemType> = []
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Select the systems in your house") {
                    ForEach(SystemType.allCases, id: \.self) { systemType in
                        Toggle(systemType.rawValue, isOn: Binding(
                            get: { selectedSystems.contains(systemType) },
                            set: { isOn in
                                if isOn {
                                    selectedSystems.insert(systemType)
                                } else {
                                    selectedSystems.remove(systemType)
                                }
                            }
                        ))
                    }
                }
            }
            .navigationTitle("House Systems")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSystems()
                    }
                    .disabled(selectedSystems.isEmpty)
                }
            }
            .onAppear {
                selectedSystems = Set(onboardingViewModel.collectedData.systems.map { $0.type })
            }
        }
    }
    
    private func saveSystems() {
        onboardingViewModel.collectedData.systems = selectedSystems.map { systemType in
            HouseSystem(type: systemType)
        }
        dismiss()
    }
}

struct UsagePatternFormView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var onboardingViewModel: OnboardingViewModel
    
    @State private var frequency: OccupancyFrequency = .monthly
    @State private var seasonalUsage: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("How often do you use the house?") {
                    Picker("Frequency", selection: $frequency) {
                        ForEach([OccupancyFrequency.daily, .weekly, .biweekly, .monthly, .seasonally, .rarely], id: \.self) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                }
                
                Section("Usage Details") {
                    Toggle("Seasonal Usage", isOn: $seasonalUsage)
                }
            }
            .navigationTitle("Usage Pattern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveUsagePattern()
                    }
                }
            }
            .onAppear {
                if let existing = onboardingViewModel.collectedData.usagePattern {
                    frequency = existing.occupancyFrequency
                    seasonalUsage = existing.seasonalUsage
                }
            }
        }
    }
    
    private func saveUsagePattern() {
        onboardingViewModel.collectedData.usagePattern = UsagePattern(
            occupancyFrequency: frequency,
            typicalStayDuration: nil,
            seasonalUsage: seasonalUsage,
            notes: nil
        )
        dismiss()
    }
}

#Preview {
    OnboardingView(appState: AppState())
}

