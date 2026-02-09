//
//  ChatToolsService.swift
//  Elsewhere
//
//  Created on 2/8/26.
//

import Foundation
import Combine

@MainActor
class ChatToolsService {
    static let shared = ChatToolsService()

    private init() {}

    // MARK: - Tool Definitions for OpenAI Function Calling

    var toolDefinitions: [[String: Any]] {
        return [
            updateHouseProfileTool,
            addVendorTool,
            createMaintenanceItemTool,
            getWeatherTool,
            searchVendorsTool
        ]
    }

    private var updateHouseProfileTool: [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": "update_house_profile",
                "description": "Update information about the house, such as systems, notes, or details. Use this when the user mentions changes to their house or wants to add notes.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "system_type": [
                            "type": "string",
                            "enum": SystemType.allCases.map { $0.rawValue },
                            "description": "The type of system to update (e.g., Heating, Cooling, Plumbing)"
                        ],
                        "system_notes": [
                            "type": "string",
                            "description": "Notes to add to the system (e.g., 'Changed furnace filter on 2/8/26')"
                        ],
                        "system_age": [
                            "type": "integer",
                            "description": "Age of the system in years"
                        ],
                        "last_serviced": [
                            "type": "string",
                            "description": "Date when the system was last serviced (ISO 8601 format)"
                        ]
                    ],
                    "required": ["system_type"]
                ]
            ]
        ]
    }

    private var addVendorTool: [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": "add_vendor",
                "description": "Add a new vendor/contractor to the house's contact list. Use this when the user mentions a service provider they work with.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "name": [
                            "type": "string",
                            "description": "Name of the vendor or company"
                        ],
                        "category": [
                            "type": "string",
                            "enum": VendorCategory.allCases.map { $0.rawValue },
                            "description": "Category of service"
                        ],
                        "phone": [
                            "type": "string",
                            "description": "Phone number"
                        ],
                        "email": [
                            "type": "string",
                            "description": "Email address"
                        ],
                        "notes": [
                            "type": "string",
                            "description": "Additional notes about the vendor"
                        ]
                    ],
                    "required": ["name", "category"]
                ]
            ]
        ]
    }

    private var createMaintenanceItemTool: [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": "create_maintenance_item",
                "description": "Create a new maintenance task or reminder. Use this when the user wants to remember to do something or schedule maintenance.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "title": [
                            "type": "string",
                            "description": "Title of the maintenance task"
                        ],
                        "description": [
                            "type": "string",
                            "description": "Detailed description of what needs to be done"
                        ],
                        "category": [
                            "type": "string",
                            "enum": MaintenanceCategory.allCases.map { $0.rawValue },
                            "description": "Category of maintenance"
                        ],
                        "priority": [
                            "type": "string",
                            "enum": MaintenancePriority.allCases.map { $0.rawValue },
                            "description": "Priority level"
                        ],
                        "due_date": [
                            "type": "string",
                            "description": "When this should be done (ISO 8601 format or relative like 'next week')"
                        ],
                        "related_system": [
                            "type": "string",
                            "enum": SystemType.allCases.map { $0.rawValue },
                            "description": "Related house system"
                        ]
                    ],
                    "required": ["title"]
                ]
            ]
        ]
    }

    private var getWeatherTool: [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": "get_weather",
                "description": "Get the current weather and forecast for the house location. Use this when the user asks about weather.",
                "parameters": [
                    "type": "object",
                    "properties": [:],
                    "required": []
                ]
            ]
        ]
    }

    private var searchVendorsTool: [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": "search_vendors",
                "description": "Search for vendors/contractors near the house location. Use this when the user asks to find a plumber, electrician, etc.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "category": [
                            "type": "string",
                            "enum": VendorCategory.allCases.map { $0.rawValue },
                            "description": "Type of vendor to search for"
                        ]
                    ],
                    "required": ["category"]
                ]
            ]
        ]
    }

    // MARK: - Tool Execution

    func executeTool(
        name: String,
        arguments: [String: Any],
        houseId: String,
        userId: String,
        houseProfile: HouseProfile?
    ) async throws -> ToolResult {
        switch name {
        case "update_house_profile":
            return try await executeUpdateHouseProfile(arguments: arguments, houseProfile: houseProfile)

        case "add_vendor":
            return try await executeAddVendor(arguments: arguments, houseId: houseId)

        case "create_maintenance_item":
            return try await executeCreateMaintenanceItem(arguments: arguments, houseId: houseId, userId: userId)

        case "get_weather":
            return try await executeGetWeather(houseId: houseId, houseProfile: houseProfile)

        case "search_vendors":
            return try await executeSearchVendors(arguments: arguments, houseProfile: houseProfile)

        default:
            throw ToolError.unknownTool(name)
        }
    }

    private func executeUpdateHouseProfile(arguments: [String: Any], houseProfile: HouseProfile?) async throws -> ToolResult {
        guard var profile = houseProfile else {
            return ToolResult(success: false, message: "No house profile found", data: nil)
        }

        guard let systemTypeString = arguments["system_type"] as? String,
              let systemType = SystemType(rawValue: systemTypeString) else {
            return ToolResult(success: false, message: "Invalid system type", data: nil)
        }

        // Find or create the system
        var systemIndex = profile.systems.firstIndex(where: { $0.type == systemType })
        if systemIndex == nil {
            profile.systems.append(HouseSystem(type: systemType))
            systemIndex = profile.systems.count - 1
        }

        // Update system properties
        if let notes = arguments["system_notes"] as? String {
            let existingNotes = profile.systems[systemIndex!].notes ?? ""
            profile.systems[systemIndex!].notes = existingNotes.isEmpty ? notes : "\(existingNotes)\n\(notes)"
        }

        if let age = arguments["system_age"] as? Int {
            profile.systems[systemIndex!].age = age
        }

        if let lastServicedString = arguments["last_serviced"] as? String {
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: lastServicedString) {
                profile.systems[systemIndex!].lastServiced = date
            }
        }

        profile.updatedAt = Date()

        try await FirebaseService.shared.saveHouseProfile(profile)

        return ToolResult(
            success: true,
            message: "Updated \(systemType.rawValue) system",
            data: ["system_type": systemType.rawValue]
        )
    }

    private func executeAddVendor(arguments: [String: Any], houseId: String) async throws -> ToolResult {
        guard let name = arguments["name"] as? String,
              let categoryString = arguments["category"] as? String,
              let category = VendorCategory(rawValue: categoryString) else {
            return ToolResult(success: false, message: "Missing vendor name or category", data: nil)
        }

        let vendor = Vendor(
            houseId: houseId,
            name: name,
            category: category,
            phone: arguments["phone"] as? String,
            email: arguments["email"] as? String,
            notes: arguments["notes"] as? String,
            source: .chat
        )

        try await FirebaseService.shared.saveVendor(vendor)

        return ToolResult(
            success: true,
            message: "Added \(name) to your vendors list",
            data: ["vendor_id": vendor.id, "name": name, "category": category.rawValue]
        )
    }

    private func executeCreateMaintenanceItem(arguments: [String: Any], houseId: String, userId: String) async throws -> ToolResult {
        guard let title = arguments["title"] as? String else {
            return ToolResult(success: false, message: "Missing task title", data: nil)
        }

        let category: MaintenanceCategory
        if let categoryString = arguments["category"] as? String,
           let cat = MaintenanceCategory(rawValue: categoryString) {
            category = cat
        } else {
            category = .routine
        }

        let priority: MaintenancePriority
        if let priorityString = arguments["priority"] as? String,
           let pri = MaintenancePriority(rawValue: priorityString) {
            priority = pri
        } else {
            priority = .medium
        }

        var dueDate: Date?
        if let dueDateString = arguments["due_date"] as? String {
            dueDate = parseDateString(dueDateString)
        }

        var relatedSystem: SystemType?
        if let systemString = arguments["related_system"] as? String {
            relatedSystem = SystemType(rawValue: systemString)
        }

        let item = MaintenanceItem(
            houseId: houseId,
            title: title,
            description: arguments["description"] as? String,
            category: category,
            priority: priority,
            dueDate: dueDate,
            relatedSystem: relatedSystem,
            createdBy: userId
        )

        try await FirebaseService.shared.saveMaintenanceItem(item)

        var message = "Created task: \(title)"
        if let date = dueDate {
            message += " (due \(date.formatted(date: .abbreviated, time: .omitted)))"
        }

        return ToolResult(
            success: true,
            message: message,
            data: ["item_id": item.id, "title": title]
        )
    }

    private func executeGetWeather(houseId: String, houseProfile: HouseProfile?) async throws -> ToolResult {
        guard let profile = houseProfile,
              let location = profile.location else {
            return ToolResult(success: false, message: "No house location set", data: nil)
        }

        var coordinates = location.coordinates
        if coordinates == nil {
            coordinates = try await GeocodingService.shared.geocodeAddress(
                location.address,
                city: location.city,
                state: location.state,
                zipCode: location.zipCode
            )
        }

        guard let coords = coordinates else {
            return ToolResult(success: false, message: "Could not determine location", data: nil)
        }

        let weather = try await WeatherService.shared.fetchWeather(for: houseId, coordinates: coords)

        let forecastSummary = weather.forecast.prefix(3).map { day in
            "\(day.dayName): \(Int(day.tempHigh))°/\(Int(day.tempLow))° \(day.description)"
        }.joined(separator: ", ")

        let message = "Current: \(Int(weather.current.temperature))°F, \(weather.current.description). Forecast: \(forecastSummary)"

        return ToolResult(
            success: true,
            message: message,
            data: [
                "current_temp": weather.current.temperature,
                "description": weather.current.description,
                "alerts_count": weather.alerts.count
            ]
        )
    }

    private func executeSearchVendors(arguments: [String: Any], houseProfile: HouseProfile?) async throws -> ToolResult {
        guard let categoryString = arguments["category"] as? String,
              let category = VendorCategory(rawValue: categoryString) else {
            return ToolResult(success: false, message: "Invalid vendor category", data: nil)
        }

        guard let profile = houseProfile,
              let location = profile.location else {
            return ToolResult(success: false, message: "No house location set. Add a location in Settings first.", data: nil)
        }

        var coordinates = location.coordinates
        if coordinates == nil {
            coordinates = try await GeocodingService.shared.geocodeAddress(
                location.address,
                city: location.city,
                state: location.state,
                zipCode: location.zipCode
            )
        }

        guard let coords = coordinates else {
            return ToolResult(success: false, message: "Could not determine house location", data: nil)
        }

        let locationString = "\(location.city), \(location.state)"
        let results = try await GooglePlacesService.shared.searchNearby(
            category: category,
            location: locationString,
            coordinates: coords
        )

        if results.isEmpty {
            return ToolResult(
                success: true,
                message: "No \(category.rawValue) vendors found near your home.",
                data: ["category": category.rawValue]
            )
        }

        let vendorDescriptions = results.map { place in
            var description = "- \(place.name)"
            if let rating = place.rating {
                description += " (\(String(format: "%.1f", rating))★"
                if let count = place.ratingCount {
                    description += ", \(count) reviews"
                }
                description += ")"
            }
            if !place.address.isEmpty {
                description += " — \(place.address)"
            }
            return description
        }

        let message = "Found \(vendorDescriptions.count) \(category.rawValue) vendors near your home:\n"
            + vendorDescriptions.joined(separator: "\n")
            + "\n\nWould you like me to add any of these to your vendors list?"

        return ToolResult(
            success: true,
            message: message,
            data: ["category": category.rawValue, "count": vendorDescriptions.count]
        )
    }

    private func parseDateString(_ dateString: String) -> Date? {
        // Try ISO 8601 first
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: dateString) {
            return date
        }

        // Try relative dates
        let lowercased = dateString.lowercased()
        let calendar = Calendar.current
        let now = Date()

        if lowercased.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: now)
        } else if lowercased.contains("next week") {
            return calendar.date(byAdding: .weekOfYear, value: 1, to: now)
        } else if lowercased.contains("next month") {
            return calendar.date(byAdding: .month, value: 1, to: now)
        }

        // Try common date formats
        let formats = ["yyyy-MM-dd", "MM/dd/yyyy", "M/d/yyyy"]
        for format in formats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }
}

struct ToolResult {
    let success: Bool
    let message: String
    let data: [String: Any]?
}

enum ToolError: LocalizedError {
    case unknownTool(String)
    case invalidArguments
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .unknownTool(let name):
            return "Unknown tool: \(name)"
        case .invalidArguments:
            return "Invalid tool arguments"
        case .executionFailed(let message):
            return "Tool execution failed: \(message)"
        }
    }
}
