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
    @Published var showAuthenticationView: Bool = false
    @Published var userHouses: [House] = []

    init() {
        // Check for existing session on launch
        Task {
            await checkExistingSession()
        }
    }

    // MARK: - Session Management

    func checkExistingSession() async {
        isAuthenticating = true
        print("🔐 checkExistingSession: Checking for existing session...")

        // Check if user is already signed in
        if let existingUser = AuthenticationService.shared.getCurrentUser() {
            print("🔐 checkExistingSession: Found existing user: \(existingUser.id), isAnonymous: \(existingUser.isAnonymous)")
            currentUser = existingUser
            isAuthenticated = true
            await loadUserHouses(autoSelectFirst: true)
            isAuthenticating = false
            print("✅ Restored session for user: \(existingUser.id)")
        } else {
            print("🔐 checkExistingSession: No existing session found")
            // No existing session, show authentication view
            isAuthenticating = false
            showAuthenticationView = true
        }
    }

    // MARK: - Authentication Handlers

    func handleSuccessfulSignIn(_ user: User) {
        currentUser = user
        isAuthenticated = true
        showAuthenticationView = false
        print("✅ Signed in as user: \(user.id)")

        Task {
            await loadUserHouses(autoSelectFirst: true)
        }
    }

    func handleAccountUpgrade(_ user: User) {
        currentUser = user
        print("✅ Account upgraded for user: \(user.id)")
    }

    func signOut() {
        do {
            try AuthenticationService.shared.signOut()
            currentUser = nil
            currentHouse = nil
            houseProfile = nil
            userHouses = []
            isAuthenticated = false
            showAuthenticationView = true
            print("✅ Signed out successfully")
        } catch {
            print("❌ Sign out failed: \(error)")
        }
    }
    
    func signInAnonymously() async {
        isAuthenticating = true

        do {
            let user = try await FirebaseService.shared.signInAnonymously()
            currentUser = user
            isAuthenticated = true
            isAuthenticating = false
            showAuthenticationView = false
            print("✅ Authenticated anonymously as user: \(user.id)")

            // After authentication, check if user has existing houses
            await loadUserHouses(autoSelectFirst: true)
        } catch {
            isAuthenticating = false
            print("❌ Failed to sign in anonymously: \(error)")
        }
    }
    
    func setCurrentHouse(_ house: House, profile: HouseProfile? = nil) {
        print("🏠 setCurrentHouse called - House ID: \(house.id), Profile provided: \(profile != nil)")
        currentHouse = house
        print("🏠 currentHouse set to: \(currentHouse?.id ?? "nil")")
        
        // If profile is provided, use it directly (e.g., when just created)
        if let profile = profile {
            self.houseProfile = profile
            print("✅ Set house profile directly: \(profile.id)")
            print("   Profile location: \(profile.location?.address ?? "nil")")
            print("   Profile age: \(profile.age?.description ?? "nil")")
            print("   Profile systems: \(profile.systems.count)")
            print("   Profile usage: \(profile.usagePattern != nil ? "set" : "nil")")
        } else {
            // Otherwise, load from Firebase
            Task {
                do {
                    if let profile = try await FirebaseService.shared.fetchHouseProfile(houseId: house.id) {
                        await MainActor.run {
                            self.houseProfile = profile
                            print("✅ Loaded house profile from Firebase: \(profile.id)")
                        }
                    } else {
                        print("⚠️ No profile found in Firebase for house: \(house.id)")
                    }
                } catch {
                    print("❌ Failed to load house profile: \(error)")
                }
            }
        }
    }
    
    func loadUserHouses(autoSelectFirst: Bool = false) async {
        guard let userId = currentUser?.id else {
            print("❌ loadUserHouses: No current user")
            return
        }

        print("🏠 loadUserHouses: Loading houses for user \(userId)")

        do {
            let houses = try await FirebaseService.shared.fetchUserHouses(userId: userId)
            print("🏠 loadUserHouses: Found \(houses.count) houses")

            userHouses = houses

            // Only auto-select if requested (e.g., on initial login)
            if autoSelectFirst, currentHouse == nil {
                // Prefer the primary home; fall back to first
                let selectedHouse = houses.first(where: { $0.isPrimary }) ?? houses.first
                if let selectedHouse {
                    print("🏠 loadUserHouses: Auto-selecting house: \(selectedHouse.id) (\(selectedHouse.name ?? "unnamed"), primary: \(selectedHouse.isPrimary))")
                    currentHouse = selectedHouse
                    if let profile = try? await FirebaseService.shared.fetchHouseProfile(houseId: selectedHouse.id) {
                        houseProfile = profile
                        print("🏠 loadUserHouses: Loaded profile for house")
                    } else {
                        print("⚠️ loadUserHouses: No profile found for house \(selectedHouse.id)")
                    }
                }
            } else if houses.isEmpty {
                print("⚠️ loadUserHouses: No houses found for user")
            }
        } catch {
            print("❌ loadUserHouses: Failed to load houses: \(error)")
        }
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
    var isAnonymous: Bool
    var appleUserId: String?  // Apple Sign In user identifier
    var photoURL: String?

    init(
        id: String = UUID().uuidString,
        email: String,
        displayName: String? = nil,
        createdAt: Date = Date(),
        isAnonymous: Bool = true,
        appleUserId: String? = nil,
        photoURL: String? = nil
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.createdAt = createdAt
        self.isAnonymous = isAnonymous
        self.appleUserId = appleUserId
        self.photoURL = photoURL
    }
}

