//
//  HouseProfile.swift
//  Elsewhere
//
//  Created on 12/12/25.
//

import Foundation
import CoreLocation

struct HouseProfile: Identifiable, Codable, Equatable {
    var id: String
    var houseId: String
    var name: String?
    var location: Location?
    var size: HouseSize?
    var age: Int? // Years since built
    var systems: [HouseSystem]
    var usagePattern: UsagePattern?
    var riskFactors: [RiskFactor]
    var seasonality: Seasonality?
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: String = UUID().uuidString,
        houseId: String,
        name: String? = nil,
        location: Location? = nil,
        size: HouseSize? = nil,
        age: Int? = nil,
        systems: [HouseSystem] = [],
        usagePattern: UsagePattern? = nil,
        riskFactors: [RiskFactor] = [],
        seasonality: Seasonality? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.houseId = houseId
        self.name = name
        self.location = location
        self.size = size
        self.age = age
        self.systems = systems
        self.usagePattern = usagePattern
        self.riskFactors = riskFactors
        self.seasonality = seasonality
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct Location: Codable, Equatable {
    var address: String
    var city: String
    var state: String
    var zipCode: String
    var coordinates: Coordinates?
}

struct Coordinates: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(from clLocation: CLLocationCoordinate2D) {
        self.latitude = clLocation.latitude
        self.longitude = clLocation.longitude
    }
    
    var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct HouseSize: Codable, Equatable {
    var squareFeet: Int?
    var bedrooms: Int?
    var bathrooms: Int?
    var lotSize: Double? // Acres
}

struct HouseSystem: Identifiable, Codable, Equatable {
    var id: String
    var type: SystemType
    var description: String?
    var age: Int? // Years old
    var lastServiced: Date?
    var notes: String?
    
    init(
        id: String = UUID().uuidString,
        type: SystemType,
        description: String? = nil,
        age: Int? = nil,
        lastServiced: Date? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.type = type
        self.description = description
        self.age = age
        self.lastServiced = lastServiced
        self.notes = notes
    }
}

enum SystemType: String, CaseIterable, Codable, Equatable {
    case heating = "Heating"
    case cooling = "Cooling"
    case water = "Water"
    case power = "Power"
    case waste = "Waste"
    case plumbing = "Plumbing"
    case electrical = "Electrical"
    case roofing = "Roofing"
    case foundation = "Foundation"
    case landscaping = "Landscaping"
    case security = "Security"
    case other = "Other"
}

struct UsagePattern: Codable, Equatable {
    var occupancyFrequency: OccupancyFrequency?
    var typicalStayDuration: Int? // Days
    var seasonalUsage: Bool
    var notes: String?
}

enum OccupancyFrequency: String, Codable, Equatable {
    case daily = "Daily"
    case weekly = "Weekly"
    case biweekly = "Bi-weekly"
    case monthly = "Monthly"
    case seasonally = "Seasonally"
    case rarely = "Rarely"
}

struct RiskFactor: Identifiable, Codable, Equatable {
    var id: String
    var type: RiskType
    var description: String?
    var severity: RiskSeverity
    
    init(
        id: String = UUID().uuidString,
        type: RiskType,
        description: String? = nil,
        severity: RiskSeverity
    ) {
        self.id = id
        self.type = type
        self.description = description
        self.severity = severity
    }
}

enum RiskType: String, Codable, Equatable {
    case lowOccupancy = "Low Occupancy"
    case winterExposure = "Winter Exposure"
    case remoteLocation = "Remote Location"
    case oldSystems = "Old Systems"
    case other = "Other"
}

enum RiskSeverity: String, Codable, Equatable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

struct Seasonality: Codable, Equatable {
    var primarySeason: Season?
    var yearRound: Bool
    var notes: String?
}

enum Season: String, Codable, Equatable {
    case spring = "Spring"
    case summer = "Summer"
    case fall = "Fall"
    case winter = "Winter"
}

