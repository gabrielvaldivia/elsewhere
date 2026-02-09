//
//  GooglePlacesService.swift
//  Elsewhere
//
//  Created on 2/8/26.
//

import Foundation

struct PlaceResult {
    let name: String
    let address: String
    let rating: Double?
    let ratingCount: Int?
    let placeId: String
}

@MainActor
class GooglePlacesService {
    static let shared = GooglePlacesService()

    private init() {}

    func searchNearby(category: VendorCategory, location: String, coordinates: Coordinates) async throws -> [PlaceResult] {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_PLACES_API_KEY") as? String else {
            throw GooglePlacesError.missingAPIKey
        }

        let query = "\(category.googlePlacesType) near \(location)"
        let urlString = "https://maps.googleapis.com/maps/api/place/textsearch/json"
            + "?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
            + "&location=\(coordinates.latitude),\(coordinates.longitude)"
            + "&radius=40000"
            + "&key=\(apiKey)"

        guard let url = URL(string: urlString) else {
            throw GooglePlacesError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else {
            return []
        }

        return results.prefix(5).compactMap { result in
            guard let name = result["name"] as? String,
                  let placeId = result["place_id"] as? String else {
                return nil
            }
            return PlaceResult(
                name: name,
                address: result["formatted_address"] as? String ?? "",
                rating: result["rating"] as? Double,
                ratingCount: result["user_ratings_total"] as? Int,
                placeId: placeId
            )
        }
    }
}

enum GooglePlacesError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case noResults

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Google Places API key not configured"
        case .invalidURL:
            return "Failed to build search URL"
        case .noResults:
            return "No results found"
        }
    }
}
