//
//  AddVendorView.swift
//  Elsewhere
//
//  Created on 2/8/26.
//

import SwiftUI

struct AddVendorView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let onAdd: () -> Void

    @State private var name = ""
    @State private var category: VendorCategory = .handyman
    @State private var phone = ""
    @State private var email = ""
    @State private var address = ""
    @State private var notes = ""
    @State private var isFavorite = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Vendor Info") {
                    TextField("Name", text: $name)

                    Picker("Category", selection: $category) {
                        ForEach(VendorCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }
                }

                Section("Contact") {
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)

                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    TextField("Address", text: $address)
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Toggle("Mark as Favorite", isOn: $isFavorite)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Add Vendor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        addVendor()
                    }
                    .disabled(name.isEmpty || isSaving)
                }
            }
            .disabled(isSaving)
            .overlay {
                if isSaving {
                    ProgressView()
                }
            }
        }
    }

    private func addVendor() {
        guard let houseId = appState.currentHouse?.id else {
            errorMessage = "No house selected"
            return
        }

        isSaving = true
        errorMessage = nil

        let vendor = Vendor(
            houseId: houseId,
            name: name,
            category: category,
            phone: phone.isEmpty ? nil : phone,
            email: email.isEmpty ? nil : email,
            address: address.isEmpty ? nil : address,
            notes: notes.isEmpty ? nil : notes,
            isFavorite: isFavorite,
            source: .manual
        )

        Task {
            do {
                try await FirebaseService.shared.saveVendor(vendor)
                await MainActor.run {
                    onAdd()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}

#Preview {
    AddVendorView(appState: AppState()) { }
}
