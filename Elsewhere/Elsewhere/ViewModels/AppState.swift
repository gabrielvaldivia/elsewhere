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
            
            // After authentication, check if user has existing houses
            await loadUserHouses()
        } catch {
            await MainActor.run {
                self.isAuthenticating = false
            }
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
    
    func loadUserHouses() async {
        guard let userId = currentUser?.id else { return }
        
        do {
            let houses = try await FirebaseService.shared.fetchUserHouses(userId: userId)
            await MainActor.run {
                if let firstHouse = houses.first {
                    self.currentHouse = firstHouse
                    // Load profile for the house
                    Task {
                        if let profile = try? await FirebaseService.shared.fetchHouseProfile(houseId: firstHouse.id) {
                            await MainActor.run {
                                self.houseProfile = profile
                            }
                        }
                    }
                }
            }
        } catch {
            print("Failed to load user houses: \(error)")
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

