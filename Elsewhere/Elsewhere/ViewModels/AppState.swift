//
//  AppState.swift
//  Elsewhere
//
//  Created on 12/12/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var currentUser: User?
    @Published var currentHouse: House?
    @Published var houseProfile: HouseProfile?
    @Published var isAuthenticated: Bool = false
    @Published var isAuthenticating: Bool = true
    
    // For Phase 1 MVP: Single house, single user
    // TODO: Expand for multi-house support in Phase 3
    
    init() {
        // TODO: Load from local storage or Firebase
        // For now, we'll start with no house (onboarding needed)
        Task {
            await signInAnonymously()
        }
    }
    
    func signInAnonymously() async {
        await MainActor.run {
            self.isAuthenticating = true
        }
        
        do {
            let user = try await FirebaseService.shared.signInAnonymously()
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                self.isAuthenticating = false
                print("✅ Authenticated as user: \(user.id)")
            }
        } catch {
            await MainActor.run {
                self.isAuthenticating = false
            }
            print("❌ Failed to sign in anonymously: \(error)")
        }
    }
    
    func setCurrentHouse(_ house: House) {
        currentHouse = house
        // TODO: Load house profile from Firebase
    }
    
    func setHouseProfile(_ profile: HouseProfile) {
        houseProfile = profile
        // Notify chat view model if it exists
        // TODO: Use a better pattern for this (NotificationCenter or Combine)
    }
}

struct User: Identifiable, Codable {
    var id: String
    var email: String
    var displayName: String?
    var createdAt: Date
    
    init(
        id: String = UUID().uuidString,
        email: String,
        displayName: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.createdAt = createdAt
    }
}

