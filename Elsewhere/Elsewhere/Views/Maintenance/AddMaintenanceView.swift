//
//  AddMaintenanceView.swift
//  Elsewhere
//
//  Created on 2/8/26.
//

import SwiftUI

struct AddMaintenanceView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let onAdd: () -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var category: MaintenanceCategory = .routine
    @State private var priority: MaintenancePriority = .medium
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var relatedSystem: SystemType?
    @State private var notes = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)

                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Category & Priority") {
                    Picker("Category", selection: $category) {
                        ForEach(MaintenanceCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }

                    Picker("Priority", selection: $priority) {
                        ForEach(MaintenancePriority.allCases, id: \.self) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                }

                Section("Schedule") {
                    Toggle("Set Due Date", isOn: $hasDueDate)

                    if hasDueDate {
                        DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                    }
                }

                Section("Related") {
                    Picker("System", selection: $relatedSystem) {
                        Text("None").tag(nil as SystemType?)
                        ForEach(SystemType.allCases, id: \.self) { system in
                            Text(system.rawValue).tag(system as SystemType?)
                        }
                    }
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Add Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        addItem()
                    }
                    .disabled(title.isEmpty || isSaving)
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

    private func addItem() {
        guard let houseId = appState.currentHouse?.id,
              let userId = appState.currentUser?.id else {
            errorMessage = "Not signed in or no house selected"
            return
        }

        isSaving = true
        errorMessage = nil

        let item = MaintenanceItem(
            houseId: houseId,
            title: title,
            description: description.isEmpty ? nil : description,
            category: category,
            priority: priority,
            status: .pending,
            dueDate: hasDueDate ? dueDate : nil,
            relatedSystem: relatedSystem,
            notes: notes.isEmpty ? nil : notes,
            createdBy: userId
        )

        Task {
            do {
                try await FirebaseService.shared.saveMaintenanceItem(item)
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
    AddMaintenanceView(appState: AppState()) { }
}
