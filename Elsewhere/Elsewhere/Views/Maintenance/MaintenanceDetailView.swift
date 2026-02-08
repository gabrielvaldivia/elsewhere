//
//  MaintenanceDetailView.swift
//  Elsewhere
//
//  Created on 2/8/26.
//

import SwiftUI

struct MaintenanceDetailView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let item: MaintenanceItem
    let onUpdate: () -> Void

    @State private var editedItem: MaintenanceItem
    @State private var isSaving = false
    @State private var showDeleteConfirmation = false

    init(appState: AppState, item: MaintenanceItem, onUpdate: @escaping () -> Void) {
        self.appState = appState
        self.item = item
        self.onUpdate = onUpdate
        _editedItem = State(initialValue: item)
    }

    var body: some View {
        Form {
            Section("Details") {
                TextField("Title", text: $editedItem.title)

                TextField("Description", text: Binding(
                    get: { editedItem.description ?? "" },
                    set: { editedItem.description = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(3...6)
            }

            Section("Status & Priority") {
                Picker("Status", selection: $editedItem.status) {
                    ForEach(MaintenanceStatus.allCases, id: \.self) { status in
                        Text(status.rawValue).tag(status)
                    }
                }

                Picker("Priority", selection: $editedItem.priority) {
                    ForEach(MaintenancePriority.allCases, id: \.self) { priority in
                        Text(priority.rawValue).tag(priority)
                    }
                }

                Picker("Category", selection: $editedItem.category) {
                    ForEach(MaintenanceCategory.allCases, id: \.self) { category in
                        Label(category.rawValue, systemImage: category.icon).tag(category)
                    }
                }
            }

            Section("Schedule") {
                DatePicker(
                    "Due Date",
                    selection: Binding(
                        get: { editedItem.dueDate ?? Date() },
                        set: { editedItem.dueDate = $0 }
                    ),
                    displayedComponents: .date
                )

                Toggle("Has Due Date", isOn: Binding(
                    get: { editedItem.dueDate != nil },
                    set: { if !$0 { editedItem.dueDate = nil } else { editedItem.dueDate = Date() } }
                ))
            }

            Section("Related") {
                Picker("System", selection: $editedItem.relatedSystem) {
                    Text("None").tag(nil as SystemType?)
                    ForEach(SystemType.allCases, id: \.self) { system in
                        Text(system.rawValue).tag(system as SystemType?)
                    }
                }
            }

            Section("Notes") {
                TextField("Notes", text: Binding(
                    get: { editedItem.notes ?? "" },
                    set: { editedItem.notes = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(3...6)
            }

            if editedItem.status != .completed {
                Section {
                    Button {
                        markComplete()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Mark Complete")
                        }
                        .foregroundColor(.green)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Item")
                    }
                }
            }
        }
        .navigationTitle("Edit Task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveItem()
                }
                .disabled(editedItem.title.isEmpty || isSaving)
            }
        }
        .disabled(isSaving)
        .alert("Delete Item", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteItem()
            }
        } message: {
            Text("Are you sure you want to delete this maintenance item?")
        }
    }

    private func saveItem() {
        isSaving = true
        editedItem.updatedAt = Date()

        Task {
            do {
                try await FirebaseService.shared.saveMaintenanceItem(editedItem)
                await MainActor.run {
                    onUpdate()
                    dismiss()
                }
            } catch {
                print("Failed to save item: \(error)")
                isSaving = false
            }
        }
    }

    private func markComplete() {
        editedItem.status = .completed
        editedItem.completedAt = Date()
        saveItem()
    }

    private func deleteItem() {
        Task {
            do {
                try await FirebaseService.shared.deleteMaintenanceItem(item.id)
                await MainActor.run {
                    onUpdate()
                    dismiss()
                }
            } catch {
                print("Failed to delete item: \(error)")
            }
        }
    }
}

#Preview {
    NavigationStack {
        MaintenanceDetailView(
            appState: AppState(),
            item: MaintenanceItem(
                houseId: "test",
                title: "Test Item",
                description: "Description here",
                category: .routine,
                priority: .medium,
                createdBy: "user"
            )
        ) { }
    }
}
