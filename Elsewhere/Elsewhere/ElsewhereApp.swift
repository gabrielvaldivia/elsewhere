//
//  ElsewhereApp.swift
//  Elsewhere
//
//  Created by Gabriel Valdivia on 12/12/25.
//

import SwiftUI
import FirebaseCore

@main
struct ElsewhereApp: App {
    init() {
        // Configure Firebase
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
