//
//  MaintenanceItem.swift
//  Elsewhere
//
//  Created on 2/8/26.
//

import Foundation

struct MaintenanceItem: Identifiable, Codable {
    var id: String
    var houseId: String
    var title: String
    var description: String?
    var category: MaintenanceCategory
    var priority: MaintenancePriority
    var status: MaintenanceStatus
    var dueDate: Date?
    var reminderDate: Date?
    var relatedSystem: SystemType?
    var relatedVendorId: String?
    var isWeatherTriggered: Bool
    var weatherTrigger: WeatherTrigger?
    var recurrence: RecurrencePattern?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var createdBy: String

    init(
        id: String = UUID().uuidString,
        houseId: String,
        title: String,
        description: String? = nil,
        category: MaintenanceCategory = .routine,
        priority: MaintenancePriority = .medium,
        status: MaintenanceStatus = .pending,
        dueDate: Date? = nil,
        reminderDate: Date? = nil,
        relatedSystem: SystemType? = nil,
        relatedVendorId: String? = nil,
        isWeatherTriggered: Bool = false,
        weatherTrigger: WeatherTrigger? = nil,
        recurrence: RecurrencePattern? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil,
        createdBy: String
    ) {
        self.id = id
        self.houseId = houseId
        self.title = title
        self.description = description
        self.category = category
        self.priority = priority
        self.status = status
        self.dueDate = dueDate
        self.reminderDate = reminderDate
        self.relatedSystem = relatedSystem
        self.relatedVendorId = relatedVendorId
        self.isWeatherTriggered = isWeatherTriggered
        self.weatherTrigger = weatherTrigger
        self.recurrence = recurrence
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.createdBy = createdBy
    }
}

enum MaintenanceCategory: String, Codable, CaseIterable {
    case routine = "Routine"
    case seasonal = "Seasonal"
    case weatherAlert = "Weather Alert"
    case repair = "Repair"
    case inspection = "Inspection"
    case upgrade = "Upgrade"

    var icon: String {
        switch self {
        case .routine:
            return "clock.fill"
        case .seasonal:
            return "leaf.fill"
        case .weatherAlert:
            return "cloud.bolt.fill"
        case .repair:
            return "wrench.fill"
        case .inspection:
            return "magnifyingglass"
        case .upgrade:
            return "arrow.up.circle.fill"
        }
    }
}

enum MaintenancePriority: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case urgent = "Urgent"

    var sortOrder: Int {
        switch self {
        case .urgent: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }
}

enum MaintenanceStatus: String, Codable, CaseIterable {
    case pending = "Pending"
    case inProgress = "In Progress"
    case completed = "Completed"
    case skipped = "Skipped"
}

struct WeatherTrigger: Codable, Equatable {
    var type: WeatherTriggerType
    var threshold: Double?

    init(type: WeatherTriggerType, threshold: Double? = nil) {
        self.type = type
        self.threshold = threshold
    }
}

enum WeatherTriggerType: String, Codable, CaseIterable {
    case freezeWarning = "Freeze Warning"
    case snowStorm = "Snow Storm"
    case heavyRain = "Heavy Rain"
    case heatWave = "Heat Wave"
    case highWind = "High Wind"

    var defaultThreshold: Double {
        switch self {
        case .freezeWarning: return 32 // Fahrenheit
        case .snowStorm: return 4 // inches
        case .heavyRain: return 2 // inches
        case .heatWave: return 95 // Fahrenheit
        case .highWind: return 40 // mph
        }
    }
}

struct RecurrencePattern: Codable, Equatable {
    var frequency: RecurrenceFrequency
    var interval: Int
    var endDate: Date?

    init(frequency: RecurrenceFrequency, interval: Int = 1, endDate: Date? = nil) {
        self.frequency = frequency
        self.interval = interval
        self.endDate = endDate
    }
}

enum RecurrenceFrequency: String, Codable, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case yearly = "Yearly"
}
