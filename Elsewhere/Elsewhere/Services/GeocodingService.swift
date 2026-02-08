//
//  GeocodingService.swift
//  Elsewhere
//
//  Created on 2/8/26.
//

import Foundation
import CoreLocation

@MainActor
class GeocodingService {
    static let shared = GeocodingService()
    private let geocoder = CLGeocoder()

    private init() {}

    func geocodeAddress(_ address: String, city: String, state: String, zipCode: String) async throws -> Coordinates {
        let fullAddress = "\(address), \(city), \(state) \(zipCode)"
        return try await geocodeAddressString(fullAddress)
    }

    func geocodeAddressString(_ address: String) async throws -> Coordinates {
        let placemarks = try await geocoder.geocodeAddressString(address)

        guard let location = placemarks.first?.location else {
            throw GeocodingError.noResults
        }

        return Coordinates(from: location.coordinate)
    }

    func reverseGeocode(coordinates: Coordinates) async throws -> (city: String, state: String) {
        let location = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
        let placemarks = try await geocoder.reverseGeocodeLocation(location)

        guard let placemark = placemarks.first else {
            throw GeocodingError.noResults
        }

        let city = placemark.locality ?? placemark.subAdministrativeArea ?? ""
        let state = placemark.administrativeArea ?? ""

        return (city, state)
    }
}

enum GeocodingError: LocalizedError {
    case noResults
    case invalidAddress

    var errorDescription: String? {
        switch self {
        case .noResults:
            return "Could not find location for address"
        case .invalidAddress:
            return "Invalid address format"
        }
    }
}
