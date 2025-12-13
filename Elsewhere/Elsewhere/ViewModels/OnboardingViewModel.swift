//
//  OnboardingViewModel.swift
//  Elsewhere
//
//  Created on 12/12/25.
//

import Foundation
import Combine

@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var collectedData: HouseOnboardingData = HouseOnboardingData()
    
    private let firebaseService = FirebaseService.shared
    
    enum OnboardingStep {
        case welcome
        case location
        case age
        case systems
        case usagePattern
        case complete
    }
    
    func createHouse(userId: String) async throws -> (House, HouseProfile) {
        // Create house
        let house = House(
            createdBy: userId,
            ownerIds: [userId],
            memberIds: []
        )
        
        try await firebaseService.createHouse(house)
        
        // Create house profile
        var profile = HouseProfile(
            houseId: house.id,
            name: collectedData.name,
            location: collectedData.location,
            age: collectedData.age,
            systems: collectedData.systems,
            usagePattern: collectedData.usagePattern,
            riskFactors: []
        )
        
        // Add risk factors based on collected data
        if let usagePattern = collectedData.usagePattern {
            if usagePattern.occupancyFrequency == .rarely || usagePattern.occupancyFrequency == .seasonally {
                profile.riskFactors.append(RiskFactor(
                    type: .lowOccupancy,
                    severity: .medium
                ))
            }
        }
        
        if let age = collectedData.age, age > 30 {
            profile.riskFactors.append(RiskFactor(
                type: .oldSystems,
                severity: .medium
            ))
        }
        
        try await firebaseService.saveHouseProfile(profile)
        
        return (house, profile)
    }
}

struct HouseOnboardingData {
    var name: String?
    var location: Location?
    var age: Int?
    var systems: [HouseSystem] = []
    var usagePattern: UsagePattern?
    
    var isLocationComplete: Bool {
        location != nil && 
        !(location?.address.isEmpty ?? true) &&
        !(location?.city.isEmpty ?? true) &&
        !(location?.state.isEmpty ?? true)
    }
    
    var isAgeComplete: Bool {
        age != nil
    }
    
    var isSystemsComplete: Bool {
        // Systems are complete once we've asked about all of them
        // An empty list is valid (user might not have any systems)
        true // We'll track completion via the question flow instead
    }
    
    var isUsagePatternComplete: Bool {
        usagePattern != nil
    }
    
    var isComplete: Bool {
        isLocationComplete && isAgeComplete && isSystemsComplete && isUsagePatternComplete
    }
}

