//
//  VendorDetailView.swift
//  Elsewhere
//
//  Created on 2/8/26.
//

import SwiftUI

struct VendorDetailView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let vendor: Vendor
    let onUpdate: () -> Void

    @State private var editedVendor: Vendor
    @State private var isSaving = false
    @State private var showDeleteConfirmation = false
    @State private var showAddWork = false

    init(appState: AppState, vendor: Vendor, onUpdate: @escaping () -> Void) {
        self.appState = appState
        self.vendor = vendor
        self.onUpdate = onUpdate
        _editedVendor = State(initialValue: vendor)
    }

    var body: some View {
        Form {
            Section("Contact") {
                TextField("Name", text: $editedVendor.name)

                TextField("Phone", text: Binding(
                    get: { editedVendor.phone ?? "" },
                    set: { editedVendor.phone = $0.isEmpty ? nil : $0 }
                ))
                .keyboardType(.phonePad)

                TextField("Email", text: Binding(
                    get: { editedVendor.email ?? "" },
                    set: { editedVendor.email = $0.isEmpty ? nil : $0 }
                ))
                .keyboardType(.emailAddress)
                .autocapitalization(.none)

                TextField("Address", text: Binding(
                    get: { editedVendor.address ?? "" },
                    set: { editedVendor.address = $0.isEmpty ? nil : $0 }
                ))
            }

            Section("Details") {
                Picker("Category", selection: $editedVendor.category) {
                    ForEach(VendorCategory.allCases, id: \.self) { category in
                        Label(category.rawValue, systemImage: category.icon).tag(category)
                    }
                }

                Toggle("Favorite", isOn: $editedVendor.isFavorite)
            }

            Section("Notes") {
                TextField("Notes", text: Binding(
                    get: { editedVendor.notes ?? "" },
                    set: { editedVendor.notes = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(3...6)
            }

            // Quick actions
            Section("Quick Actions") {
                if let phone = editedVendor.phone {
                    Button {
                        callVendor(phone)
                    } label: {
                        HStack {
                            Image(systemName: "phone.fill")
                                .foregroundColor(.green)
                            Text("Call \(editedVendor.name)")
                        }
                    }
                }

                if let email = editedVendor.email {
                    Button {
                        emailVendor(email)
                    } label: {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.blue)
                            Text("Email \(editedVendor.name)")
                        }
                    }
                }
            }

            // Work history
            Section("Work History") {
                if editedVendor.workHistory.isEmpty {
                    Text("No work history recorded")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(editedVendor.workHistory) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.description)
                                .font(.headline)
                            HStack {
                                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                if let cost = entry.cost {
                                    Text("$\(cost, specifier: "%.2f")")
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete(perform: deleteWorkEntry)
                }

                Button {
                    showAddWork = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Work Entry")
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Vendor")
                    }
                }
            }
        }
        .navigationTitle("Edit Vendor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveVendor()
                }
                .disabled(editedVendor.name.isEmpty || isSaving)
            }
        }
        .disabled(isSaving)
        .alert("Delete Vendor", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteVendor()
            }
        } message: {
            Text("Are you sure you want to delete this vendor?")
        }
        .sheet(isPresented: $showAddWork) {
            AddWorkEntryView { entry in
                editedVendor.workHistory.insert(entry, at: 0)
                saveVendor()
            }
        }
    }

    private func saveVendor() {
        isSaving = true
        editedVendor.updatedAt = Date()

        Task {
            do {
                try await FirebaseService.shared.saveVendor(editedVendor)
                await MainActor.run {
                    onUpdate()
                    dismiss()
                }
            } catch {
                print("Failed to save vendor: \(error)")
                isSaving = false
            }
        }
    }

    private func deleteVendor() {
        Task {
            do {
                try await FirebaseService.shared.deleteVendor(vendor.id)
                await MainActor.run {
                    onUpdate()
                    dismiss()
                }
            } catch {
                print("Failed to delete vendor: \(error)")
            }
        }
    }

    private func deleteWorkEntry(at offsets: IndexSet) {
        editedVendor.workHistory.remove(atOffsets: offsets)
    }

    private func callVendor(_ phone: String) {
        let cleaned = phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        if let url = URL(string: "tel://\(cleaned)") {
            UIApplication.shared.open(url)
        }
    }

    private func emailVendor(_ email: String) {
        if let url = URL(string: "mailto:\(email)") {
            UIApplication.shared.open(url)
        }
    }
}

struct AddWorkEntryView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (WorkHistoryEntry) -> Void

    @State private var description = ""
    @State private var date = Date()
    @State private var hasCost = false
    @State private var cost = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Work Details") {
                    TextField("Description", text: $description)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Cost") {
                    Toggle("Record Cost", isOn: $hasCost)
                    if hasCost {
                        TextField("Amount", text: $cost)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Work Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        let entry = WorkHistoryEntry(
                            date: date,
                            description: description,
                            cost: hasCost ? Double(cost) : nil,
                            notes: notes.isEmpty ? nil : notes
                        )
                        onAdd(entry)
                        dismiss()
                    }
                    .disabled(description.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        VendorDetailView(
            appState: AppState(),
            vendor: Vendor(
                houseId: "test",
                name: "Test Plumber",
                category: .plumbing,
                phone: "555-1234"
            )
        ) { }
    }
}
