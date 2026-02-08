//
//  WeatherService.swift
//  Elsewhere
//
//  Created on 2/8/26.
//

import Foundation
import Combine

@MainActor
class WeatherService: ObservableObject {
    static let shared = WeatherService()

    private let apiKey: String
    // Use 2.5 API as fallback (free, no subscription needed)
    private let baseURL25 = "https://api.openweathermap.org/data/2.5"
    private let baseURL30 = "https://api.openweathermap.org/data/3.0/onecall"

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var cachedWeather: [String: WeatherData] = [:]  // houseId -> WeatherData

    private init() {
        self.apiKey = Bundle.main.object(forInfoDictionaryKey: "OPENWEATHER_API_KEY") as? String ?? ""

        if apiKey.isEmpty {
            print("⚠️ OpenWeather API key not found. Set OPENWEATHER_API_KEY in Info.plist")
        } else {
            print("✅ OpenWeather API key loaded: \(apiKey.prefix(8))...")
        }
    }

    func fetchWeather(for houseId: String, coordinates: Coordinates) async throws -> WeatherData {
        // Check cache first (valid for 1 hour)
        if let cached = cachedWeather[houseId],
           Date().timeIntervalSince(cached.fetchedAt) < 3600 {
            return cached
        }

        guard !apiKey.isEmpty else {
            throw WeatherError.apiKeyMissing
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        // Try 3.0 API first, fall back to 2.5 if unauthorized
        do {
            return try await fetchWeather30(for: houseId, coordinates: coordinates)
        } catch WeatherError.apiError(let statusCode) where statusCode == 401 {
            print("⚠️ One Call 3.0 API returned 401, falling back to 2.5 API")
            return try await fetchWeather25(for: houseId, coordinates: coordinates)
        }
    }

    private func fetchWeather30(for houseId: String, coordinates: Coordinates) async throws -> WeatherData {
        let url = URL(string: "\(baseURL30)?lat=\(coordinates.latitude)&lon=\(coordinates.longitude)&exclude=minutely,hourly&units=imperial&appid=\(apiKey)")!

        print("🌤️ Fetching weather from 3.0 API: \(url)")

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WeatherError.invalidResponse
        }

        print("🌤️ 3.0 API response status: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            throw WeatherError.apiError(statusCode: httpResponse.statusCode)
        }

        return try parseWeatherResponse(data, houseId: houseId)
    }

    private func fetchWeather25(for houseId: String, coordinates: Coordinates) async throws -> WeatherData {
        // Fetch current weather
        let currentURL = URL(string: "\(baseURL25)/weather?lat=\(coordinates.latitude)&lon=\(coordinates.longitude)&units=imperial&appid=\(apiKey)")!

        print("🌤️ Fetching current weather from 2.5 API")

        let (currentData, currentResponse) = try await URLSession.shared.data(from: currentURL)

        guard let httpResponse = currentResponse as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WeatherError.apiError(statusCode: (currentResponse as? HTTPURLResponse)?.statusCode ?? 0)
        }

        // Fetch forecast
        let forecastURL = URL(string: "\(baseURL25)/forecast?lat=\(coordinates.latitude)&lon=\(coordinates.longitude)&units=imperial&appid=\(apiKey)")!

        let (forecastData, _) = try await URLSession.shared.data(from: forecastURL)

        return try parseWeather25Response(currentData: currentData, forecastData: forecastData, houseId: houseId)
    }

    private func parseWeather25Response(currentData: Data, forecastData: Data, houseId: String) throws -> WeatherData {
        guard let currentJson = try JSONSerialization.jsonObject(with: currentData) as? [String: Any],
              let forecastJson = try JSONSerialization.jsonObject(with: forecastData) as? [String: Any] else {
            throw WeatherError.invalidResponse
        }

        // Parse current weather
        let main = currentJson["main"] as? [String: Any] ?? [:]
        let wind = currentJson["wind"] as? [String: Any] ?? [:]
        let weatherArray = currentJson["weather"] as? [[String: Any]] ?? []
        let weatherInfo = weatherArray.first ?? [:]

        let current = CurrentWeather(
            temperature: main["temp"] as? Double ?? 0,
            feelsLike: main["feels_like"] as? Double ?? 0,
            humidity: main["humidity"] as? Int ?? 0,
            windSpeed: wind["speed"] as? Double ?? 0,
            windDirection: wind["deg"] as? Int ?? 0,
            description: weatherInfo["description"] as? String ?? "",
            icon: weatherInfo["icon"] as? String ?? "01d",
            uvIndex: 0,
            visibility: currentJson["visibility"] as? Int ?? 10000
        )

        // Parse forecast (group by day)
        let forecastList = forecastJson["list"] as? [[String: Any]] ?? []
        var dailyForecasts: [String: (high: Double, low: Double, icon: String, description: String, pop: Double)] = [:]

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for item in forecastList {
            let dt = item["dt"] as? TimeInterval ?? 0
            let date = Date(timeIntervalSince1970: dt)
            let dateKey = dateFormatter.string(from: date)

            let itemMain = item["main"] as? [String: Any] ?? [:]
            let temp = itemMain["temp"] as? Double ?? 0
            let itemWeather = (item["weather"] as? [[String: Any]])?.first ?? [:]
            let pop = item["pop"] as? Double ?? 0

            if var existing = dailyForecasts[dateKey] {
                existing.high = max(existing.high, temp)
                existing.low = min(existing.low, temp)
                existing.pop = max(existing.pop, pop)
                dailyForecasts[dateKey] = existing
            } else {
                dailyForecasts[dateKey] = (
                    high: temp,
                    low: temp,
                    icon: itemWeather["icon"] as? String ?? "01d",
                    description: itemWeather["description"] as? String ?? "",
                    pop: pop
                )
            }
        }

        let forecast = dailyForecasts.sorted { $0.key < $1.key }.prefix(7).map { (dateKey, data) in
            DailyForecast(
                date: dateFormatter.date(from: dateKey) ?? Date(),
                tempHigh: data.high,
                tempLow: data.low,
                humidity: 0,
                windSpeed: 0,
                description: data.description,
                icon: data.icon,
                precipProbability: data.pop,
                precipAmount: nil
            )
        }

        let weatherData = WeatherData(
            houseId: houseId,
            current: current,
            forecast: Array(forecast),
            alerts: []
        )
        cachedWeather[houseId] = weatherData
        return weatherData
    }

    private func parseWeatherResponse(_ data: Data, houseId: String) throws -> WeatherData {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw WeatherError.invalidResponse
        }

        // Parse current weather
        guard let currentJson = json["current"] as? [String: Any] else {
            throw WeatherError.invalidResponse
        }

        let weatherArray = currentJson["weather"] as? [[String: Any]] ?? []
        let weatherInfo = weatherArray.first ?? [:]

        let current = CurrentWeather(
            temperature: currentJson["temp"] as? Double ?? 0,
            feelsLike: currentJson["feels_like"] as? Double ?? 0,
            humidity: currentJson["humidity"] as? Int ?? 0,
            windSpeed: currentJson["wind_speed"] as? Double ?? 0,
            windDirection: currentJson["wind_deg"] as? Int ?? 0,
            description: weatherInfo["description"] as? String ?? "",
            icon: weatherInfo["icon"] as? String ?? "01d",
            uvIndex: currentJson["uvi"] as? Double ?? 0,
            visibility: currentJson["visibility"] as? Int ?? 10000
        )

        // Parse daily forecast
        let dailyArray = json["daily"] as? [[String: Any]] ?? []
        let forecast = dailyArray.prefix(7).map { day -> DailyForecast in
            let temp = day["temp"] as? [String: Any] ?? [:]
            let weather = (day["weather"] as? [[String: Any]])?.first ?? [:]

            return DailyForecast(
                date: Date(timeIntervalSince1970: day["dt"] as? TimeInterval ?? 0),
                tempHigh: temp["max"] as? Double ?? 0,
                tempLow: temp["min"] as? Double ?? 0,
                humidity: day["humidity"] as? Int ?? 0,
                windSpeed: day["wind_speed"] as? Double ?? 0,
                description: weather["description"] as? String ?? "",
                icon: weather["icon"] as? String ?? "01d",
                precipProbability: day["pop"] as? Double ?? 0,
                precipAmount: (day["rain"] as? Double) ?? (day["snow"] as? Double)
            )
        }

        // Parse alerts
        let alertsArray = json["alerts"] as? [[String: Any]] ?? []
        let alerts = alertsArray.map { alert -> WeatherAlert in
            let severity: AlertSeverity
            let tags = alert["tags"] as? [String] ?? []
            if tags.contains("Extreme") {
                severity = .extreme
            } else if tags.contains("Warning") || (alert["event"] as? String ?? "").contains("Warning") {
                severity = .warning
            } else if tags.contains("Watch") || (alert["event"] as? String ?? "").contains("Watch") {
                severity = .watch
            } else {
                severity = .advisory
            }

            return WeatherAlert(
                event: alert["event"] as? String ?? "Weather Alert",
                sender: alert["sender_name"] as? String ?? "",
                start: Date(timeIntervalSince1970: alert["start"] as? TimeInterval ?? 0),
                end: Date(timeIntervalSince1970: alert["end"] as? TimeInterval ?? 0),
                description: alert["description"] as? String ?? "",
                severity: severity
            )
        }

        return WeatherData(
            houseId: houseId,
            current: current,
            forecast: Array(forecast),
            alerts: alerts
        )
    }

    // MARK: - Weather Triggers

    func checkWeatherTriggers(_ weather: WeatherData) -> [WeatherTriggerType] {
        var triggers: [WeatherTriggerType] = []

        // Check freeze warning
        if weather.current.temperature <= 32 ||
           weather.forecast.first(where: { $0.tempLow <= 32 }) != nil {
            triggers.append(.freezeWarning)
        }

        // Check snow storm
        if weather.forecast.contains(where: {
            $0.icon.contains("13") && ($0.precipAmount ?? 0) >= 4
        }) {
            triggers.append(.snowStorm)
        }

        // Check heavy rain
        if weather.forecast.contains(where: {
            $0.icon.contains("09") || $0.icon.contains("10") && ($0.precipAmount ?? 0) >= 2
        }) {
            triggers.append(.heavyRain)
        }

        // Check heat wave
        if weather.forecast.contains(where: { $0.tempHigh >= 95 }) {
            triggers.append(.heatWave)
        }

        // Check high wind
        if weather.current.windSpeed >= 40 ||
           weather.forecast.contains(where: { $0.windSpeed >= 40 }) {
            triggers.append(.highWind)
        }

        return triggers
    }

    func generateMaintenanceAlerts(triggers: [WeatherTriggerType]) -> [(title: String, description: String, priority: MaintenancePriority)] {
        return triggers.map { trigger in
            switch trigger {
            case .freezeWarning:
                return (
                    title: "Winterize pipes",
                    description: "Freezing temperatures expected. Check pipes, disconnect hoses, and ensure heating is working.",
                    priority: .high
                )
            case .snowStorm:
                return (
                    title: "Schedule snow removal",
                    description: "Heavy snowfall expected. Contact snow removal service or prepare equipment.",
                    priority: .high
                )
            case .heavyRain:
                return (
                    title: "Check drainage",
                    description: "Heavy rain expected. Inspect gutters, downspouts, and drainage areas.",
                    priority: .medium
                )
            case .heatWave:
                return (
                    title: "Check cooling system",
                    description: "High temperatures expected. Ensure AC is working and consider remote monitoring.",
                    priority: .medium
                )
            case .highWind:
                return (
                    title: "Secure outdoor items",
                    description: "High winds expected. Secure or store loose outdoor furniture and items.",
                    priority: .high
                )
            }
        }
    }
}

enum WeatherError: LocalizedError {
    case apiKeyMissing
    case invalidResponse
    case apiError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "OpenWeather API key is missing"
        case .invalidResponse:
            return "Invalid response from weather service"
        case .apiError(let statusCode):
            return "Weather API error (status: \(statusCode))"
        }
    }
}
