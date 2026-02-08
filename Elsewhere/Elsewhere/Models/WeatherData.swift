//
//  WeatherData.swift
//  Elsewhere
//
//  Created on 2/8/26.
//

import Foundation

struct WeatherData: Codable {
    var houseId: String
    var fetchedAt: Date
    var current: CurrentWeather
    var forecast: [DailyForecast]
    var alerts: [WeatherAlert]

    init(
        houseId: String,
        fetchedAt: Date = Date(),
        current: CurrentWeather,
        forecast: [DailyForecast] = [],
        alerts: [WeatherAlert] = []
    ) {
        self.houseId = houseId
        self.fetchedAt = fetchedAt
        self.current = current
        self.forecast = forecast
        self.alerts = alerts
    }
}

struct CurrentWeather: Codable {
    var temperature: Double      // Fahrenheit
    var feelsLike: Double
    var humidity: Int            // Percentage
    var windSpeed: Double        // mph
    var windDirection: Int       // degrees
    var description: String
    var icon: String
    var uvIndex: Double
    var visibility: Int          // meters

    var temperatureDisplay: String {
        "\(Int(temperature.rounded()))°F"
    }

    var weatherIcon: String {
        mapOpenWeatherIcon(icon)
    }

    private func mapOpenWeatherIcon(_ icon: String) -> String {
        switch icon {
        case "01d": return "sun.max.fill"
        case "01n": return "moon.fill"
        case "02d": return "cloud.sun.fill"
        case "02n": return "cloud.moon.fill"
        case "03d", "03n": return "cloud.fill"
        case "04d", "04n": return "smoke.fill"
        case "09d", "09n": return "cloud.drizzle.fill"
        case "10d": return "cloud.sun.rain.fill"
        case "10n": return "cloud.moon.rain.fill"
        case "11d", "11n": return "cloud.bolt.fill"
        case "13d", "13n": return "snowflake"
        case "50d", "50n": return "cloud.fog.fill"
        default: return "cloud.fill"
        }
    }
}

struct DailyForecast: Codable, Identifiable {
    var id: String { "\(date.timeIntervalSince1970)" }
    var date: Date
    var tempHigh: Double
    var tempLow: Double
    var humidity: Int
    var windSpeed: Double
    var description: String
    var icon: String
    var precipProbability: Double   // 0-1
    var precipAmount: Double?       // inches

    var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    var weatherIcon: String {
        mapOpenWeatherIcon(icon)
    }

    private func mapOpenWeatherIcon(_ icon: String) -> String {
        switch icon {
        case "01d": return "sun.max.fill"
        case "01n": return "moon.fill"
        case "02d": return "cloud.sun.fill"
        case "02n": return "cloud.moon.fill"
        case "03d", "03n": return "cloud.fill"
        case "04d", "04n": return "smoke.fill"
        case "09d", "09n": return "cloud.drizzle.fill"
        case "10d": return "cloud.sun.rain.fill"
        case "10n": return "cloud.moon.rain.fill"
        case "11d", "11n": return "cloud.bolt.fill"
        case "13d", "13n": return "snowflake"
        case "50d", "50n": return "cloud.fog.fill"
        default: return "cloud.fill"
        }
    }
}

struct WeatherAlert: Codable, Identifiable {
    var id: String { "\(start.timeIntervalSince1970)-\(event)" }
    var event: String
    var sender: String
    var start: Date
    var end: Date
    var description: String
    var severity: AlertSeverity

    var isActive: Bool {
        let now = Date()
        return now >= start && now <= end
    }
}

enum AlertSeverity: String, Codable {
    case advisory = "Advisory"
    case watch = "Watch"
    case warning = "Warning"
    case extreme = "Extreme"

    var color: String {
        switch self {
        case .advisory: return "yellow"
        case .watch: return "orange"
        case .warning: return "red"
        case .extreme: return "purple"
        }
    }
}
