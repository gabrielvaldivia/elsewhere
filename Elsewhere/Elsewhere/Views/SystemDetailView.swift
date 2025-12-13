//
//  SystemDetailView.swift
//  Elsewhere
//
//  Created on 12/12/25.
//

import SwiftUI

struct SystemDetailView: View {
    let systemType: SystemType
    @Binding var system: HouseSystem
    var onRemove: (() -> Void)? = nil
    var onSave: (() -> Void)? = nil
    
    @State private var description: String = ""
    @State private var age: Int?
    @State private var lastServiced: Date?
    @State private var notes: String = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Form {
            Section("Description") {
                TextField("e.g., Forced air, Oil furnace, etc.", text: $description)
                    .onChange(of: description) { _, _ in
                        updateSystem()
                    }
            }
            
            Section("Age") {
                if let currentAge = age {
                    Stepper("\(currentAge)", value: Binding(
                        get: { currentAge },
                        set: { newAge in
                            age = newAge
                            updateSystem()
                        }
                    ), in: 0...100)
                } else {
                    Button("Add Age") {
                        age = 0
                        updateSystem()
                    }
                }
            }
            
            Section("Last Serviced") {
                if let servicedDate = lastServiced {
                    DatePicker("Last Serviced", selection: Binding(
                        get: { servicedDate },
                        set: { newDate in
                            lastServiced = newDate
                            updateSystem()
                        }
                    ), displayedComponents: .date)
                } else {
                    Button("Add Last Serviced Date") {
                        lastServiced = Date()
                        updateSystem()
                    }
                }
            }
            
            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(minHeight: 120)
                    .onChange(of: notes) { _, _ in
                        updateSystem()
                    }
            }
            
            Section {
                Button(role: .destructive, action: {
                    onRemove?()
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Remove System")
                    }
                }
            }
        }
        .navigationTitle(systemType.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadSystemIntoState()
        }
        .onDisappear {
            updateSystem()
            onSave?()
        }
    }
    
    private func loadSystemIntoState() {
        description = system.description ?? ""
        age = system.age
        lastServiced = system.lastServiced
        notes = system.notes ?? ""
    }
    
    private func clearState() {
        description = ""
        age = nil
        lastServiced = nil
        notes = ""
    }
    
    private func updateSystem() {
        let existingId = system.id // Preserve ID
        system.description = description.isEmpty ? nil : description
        system.age = age
        system.lastServiced = lastServiced
        system.notes = notes.isEmpty ? nil : notes
        system.id = existingId // Ensure ID is preserved
    }
}

#Preview {
    NavigationStack {
        SystemDetailView(
            systemType: .heating,
            system: .constant(HouseSystem(type: .heating, description: "Forced air", age: 15)),
            onRemove: nil,
            onSave: nil
        )
    }
}

