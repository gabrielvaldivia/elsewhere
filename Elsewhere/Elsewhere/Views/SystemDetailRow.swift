//
//  SystemDetailRow.swift
//  Elsewhere
//
//  Created on 12/12/25.
//

import SwiftUI

struct SystemDetailRow: View {
    let system: HouseSystem
    @Binding var systemBinding: HouseSystem
    var onRemove: (() -> Void)? = nil
    var onSave: (() -> Void)? = nil
    
    var body: some View {
        NavigationLink(destination: {
            SystemDetailView(
                systemType: system.type,
                system: $systemBinding,
                onRemove: onRemove,
                onSave: onSave
            )
        }) {
            Text(system.type.rawValue)
        }
    }
}

#Preview {
    NavigationStack {
        Form {
            Section("Systems") {
                SystemDetailRow(
                    system: HouseSystem(type: .heating, description: "Forced air", age: 15),
                    systemBinding: .constant(HouseSystem(type: .heating, description: "Forced air", age: 15))
                )
            }
        }
    }
}

