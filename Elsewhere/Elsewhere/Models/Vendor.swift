//
//  Vendor.swift
//  Elsewhere
//
//  Created on 2/8/26.
//

import Foundation

struct Vendor: Identifiable, Codable {
    var id: String
    var houseId: String
    var name: String
    var category: VendorCategory
    var phone: String?
    var email: String?
    var address: String?
    var notes: String?
    var isFavorite: Bool
    var source: VendorSource
    var googlePlaceId: String?
    var rating: Double?
    var workHistory: [WorkHistoryEntry]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        houseId: String,
        name: String,
        category: VendorCategory,
        phone: String? = nil,
        email: String? = nil,
        address: String? = nil,
        notes: String? = nil,
        isFavorite: Bool = false,
        source: VendorSource = .manual,
        googlePlaceId: String? = nil,
        rating: Double? = nil,
        workHistory: [WorkHistoryEntry] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.houseId = houseId
        self.name = name
        self.category = category
        self.phone = phone
        self.email = email
        self.address = address
        self.notes = notes
        self.isFavorite = isFavorite
        self.source = source
        self.googlePlaceId = googlePlaceId
        self.rating = rating
        self.workHistory = workHistory
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum VendorCategory: String, Codable, CaseIterable {
    case hvac = "HVAC"
    case plumbing = "Plumbing"
    case electrical = "Electrical"
    case roofing = "Roofing"
    case snowRemoval = "Snow Removal"
    case landscaping = "Landscaping"
    case cleaning = "Cleaning"
    case pest = "Pest Control"
    case security = "Security"
    case handyman = "Handyman"
    case other = "Other"

    var icon: String {
        switch self {
        case .hvac:
            return "thermometer.snowflake"
        case .plumbing:
            return "drop.fill"
        case .electrical:
            return "bolt.fill"
        case .roofing:
            return "house.fill"
        case .snowRemoval:
            return "snowflake"
        case .landscaping:
            return "leaf.fill"
        case .cleaning:
            return "sparkles"
        case .pest:
            return "ant.fill"
        case .security:
            return "lock.shield.fill"
        case .handyman:
            return "wrench.and.screwdriver.fill"
        case .other:
            return "ellipsis.circle.fill"
        }
    }

    var googlePlacesType: String {
        switch self {
        case .hvac:
            return "hvac_contractor"
        case .plumbing:
            return "plumber"
        case .electrical:
            return "electrician"
        case .roofing:
            return "roofing_contractor"
        case .snowRemoval:
            return "snow_removal_service"
        case .landscaping:
            return "landscaper"
        case .cleaning:
            return "house_cleaning_service"
        case .pest:
            return "pest_control_service"
        case .security:
            return "security_system_installer"
        case .handyman:
            return "handyman"
        case .other:
            return "contractor"
        }
    }
}

enum VendorSource: String, Codable {
    case manual = "manual"
    case googlePlaces = "google_places"
    case chat = "chat"
}

struct WorkHistoryEntry: Identifiable, Codable {
    var id: String
    var date: Date
    var description: String
    var cost: Double?
    var notes: String?

    init(
        id: String = UUID().uuidString,
        date: Date = Date(),
        description: String,
        cost: Double? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.date = date
        self.description = description
        self.cost = cost
        self.notes = notes
    }
}
