//
//  AddHouseView.swift
//  Elsewhere
//
//  Created on 2/8/26.
//

import SwiftUI

struct AddHouseView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var houseName = ""
    @State private var address = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zipCode = ""
    @State private var isPrimary = false
    @State private var isCreating = false
    @State private var errorMessage: String?

    private var isFirstHome: Bool {
        appState.userHouses.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Home Name") {
                    TextField("e.g., Lake House", text: $houseName)
                }

                Section("Location") {
                    TextField("Street Address", text: $address)
                    TextField("City", text: $city)
                    Picker("State", selection: $state) {
                        Text("Select State").tag("")
                        ForEach(USStates.allStates, id: \.abbreviation) { stateOption in
                            Text(stateOption.name).tag(stateOption.abbreviation)
                        }
                    }
                    TextField("ZIP Code", text: $zipCode)
                        .keyboardType(.numberPad)
                }

                if !isFirstHome {
                    Section {
                        Toggle("Primary Home", isOn: $isPrimary)
                    } footer: {
                        Text("Your primary home is auto-selected when you open the app.")
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Add Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        createHouse()
                    }
                    .disabled(houseName.isEmpty || isCreating)
                }
            }
            .disabled(isCreating)
            .overlay {
                if isCreating {
                    ProgressView()
                }
            }
        }
    }

    private func createHouse() {
        guard let userId = appState.currentUser?.id else {
            errorMessage = "Not signed in"
            return
        }

        isCreating = true
        errorMessage = nil

        Task {
            do {
                let shouldBePrimary = isFirstHome || isPrimary

                // Create the house
                let house = House(
                    name: houseName.isEmpty ? nil : houseName,
                    createdBy: userId,
                    ownerIds: [userId],
                    memberIds: [],
                    isPrimary: shouldBePrimary
                )

                try await FirebaseService.shared.createHouse(house)

                // If marked primary, clear others
                if shouldBePrimary {
                    try await FirebaseService.shared.setHousePrimary(houseId: house.id, userId: userId)
                }

                // Create initial profile
                var location: Location?
                if !address.isEmpty || !city.isEmpty {
                    location = Location(
                        address: address,
                        city: city,
                        state: state,
                        zipCode: zipCode,
                        coordinates: nil
                    )
                }

                let profile = HouseProfile(
                    houseId: house.id,
                    name: houseName.isEmpty ? nil : houseName,
                    location: location,
                    age: nil,
                    systems: [],
                    usagePattern: nil,
                    riskFactors: []
                )

                try await FirebaseService.shared.saveHouseProfile(profile)

                // Update app state
                await MainActor.run {
                    appState.userHouses.append(house)
                    appState.currentHouse = house
                    appState.houseProfile = profile
                    dismiss()
                }

                print("✅ Created new house: \(house.id)")
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}

#Preview {
    AddHouseView(appState: AppState())
}
