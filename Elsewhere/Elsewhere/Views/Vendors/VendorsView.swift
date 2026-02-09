//
//  VendorsView.swift
//  Elsewhere
//
//  Created on 2/8/26.
//

import SwiftUI

struct VendorsView: View {
    @ObservedObject var appState: AppState
    @State private var vendors: [Vendor] = []
    @State private var isLoading = true
    @State private var showAddVendor = false
    @State private var selectedCategory: VendorCategory?
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var suggestedVendors: [VendorCategory: [PlaceResult]] = [:]
    @State private var isLoadingSuggestions = false

    var body: some View {
        VStack(spacing: 0) {
            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CategoryFilterButton(
                        title: "All",
                        isSelected: selectedCategory == nil
                    ) {
                        selectedCategory = nil
                    }

                    ForEach(VendorCategory.allCases, id: \.self) { category in
                        CategoryFilterButton(
                            title: category.rawValue,
                            icon: category.icon,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)

            // Vendors list
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if filteredVendors.isEmpty && filteredSuggestedCategories.isEmpty && !isLoadingSuggestions {
                Spacer()
                EmptyVendorsView()
                Spacer()
            } else {
                List {
                    // Saved vendors
                    if !filteredVendors.isEmpty {
                        Section("My Vendors") {
                            ForEach(filteredVendors) { vendor in
                                NavigationLink {
                                    VendorDetailView(appState: appState, vendor: vendor) {
                                        Task {
                                            await loadVendors()
                                        }
                                    }
                                } label: {
                                    VendorRow(vendor: vendor)
                                }
                            }
                            .onDelete(perform: deleteVendors)
                        }
                    }

                    // Suggested vendors by category
                    ForEach(filteredSuggestedCategories, id: \.self) { category in
                        if let unsaved = unsavedPlaces(for: category), !unsaved.isEmpty {
                            Section("Suggested \(category.rawValue)") {
                                ForEach(unsaved, id: \.placeId) { place in
                                    SuggestedVendorRow(place: place) {
                                        Task {
                                            await addSuggestedVendor(place, category: category)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if isLoadingSuggestions {
                        Section {
                            HStack {
                                Spacer()
                                ProgressView("Finding nearby vendors...")
                                    .font(.subheadline)
                                Spacer()
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .searchable(text: $searchText, prompt: "Search vendors")
            }
        }
        .navigationTitle("Vendors")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddVendor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await loadVendors()
        }
        .task {
            await loadSuggestions()
        }
        .refreshable {
            await loadVendors()
            await loadSuggestions()
        }
        .sheet(isPresented: $showAddVendor) {
            AddVendorView(appState: appState) {
                Task {
                    await loadVendors()
                }
            }
        }
    }

    private var filteredVendors: [Vendor] {
        var result = vendors

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.category.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Sort favorites first, then by name
        return result.sorted { v1, v2 in
            if v1.isFavorite != v2.isFavorite {
                return v1.isFavorite
            }
            return v1.name < v2.name
        }
    }

    private var filteredSuggestedCategories: [VendorCategory] {
        let categories = Array(suggestedVendors.keys).sorted { $0.rawValue < $1.rawValue }
        if let selected = selectedCategory {
            return categories.filter { $0 == selected }
        }
        return categories
    }

    private func unsavedPlaces(for category: VendorCategory) -> [PlaceResult]? {
        guard let places = suggestedVendors[category], !places.isEmpty else { return nil }
        let filtered = places.filter { place in
            !vendors.contains(where: { $0.googlePlaceId == place.placeId })
        }
        return filtered.isEmpty ? nil : filtered
    }

    private var relevantCategories: [VendorCategory] {
        var categories: Set<VendorCategory> = [.handyman, .cleaning]

        if let systems = appState.houseProfile?.systems {
            for system in systems {
                if let category = system.type.suggestedVendorCategory {
                    categories.insert(category)
                }
            }
        }

        return Array(categories).sorted { $0.rawValue < $1.rawValue }
    }

    private func loadVendors() async {
        guard let houseId = appState.currentHouse?.id else { return }

        isLoading = true
        errorMessage = nil

        do {
            vendors = try await FirebaseService.shared.fetchVendors(houseId: houseId)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func loadSuggestions() async {
        print("📋 loadSuggestions: started")

        guard let profile = appState.houseProfile else {
            print("⚠️ loadSuggestions: No house profile")
            return
        }

        guard let location = profile.location else {
            print("⚠️ loadSuggestions: No location on profile")
            return
        }

        print("📋 loadSuggestions: location=\(location.city), \(location.state), coords=\(String(describing: location.coordinates))")

        var coordinates = location.coordinates
        if coordinates == nil {
            print("📋 loadSuggestions: coordinates nil, attempting geocode...")
            coordinates = try? await GeocodingService.shared.geocodeAddress(
                location.address,
                city: location.city,
                state: location.state,
                zipCode: location.zipCode
            )
            print("📋 loadSuggestions: geocode result=\(String(describing: coordinates))")
        }

        guard let coords = coordinates else {
            print("⚠️ loadSuggestions: Could not determine coordinates")
            return
        }

        isLoadingSuggestions = true
        let locationString = "\(location.city), \(location.state)"
        let categories = relevantCategories
        print("📋 loadSuggestions: fetching \(categories.count) categories: \(categories.map { $0.rawValue })")

        for category in categories {
            guard !Task.isCancelled else {
                print("⚠️ loadSuggestions: task cancelled")
                break
            }
            do {
                let results = try await GooglePlacesService.shared.searchNearby(
                    category: category,
                    location: locationString,
                    coordinates: coords
                )
                print("📋 loadSuggestions: \(category.rawValue) returned \(results.count) results")
                suggestedVendors[category] = results
            } catch is CancellationError {
                print("⚠️ loadSuggestions: cancelled during \(category.rawValue)")
                break
            } catch {
                print("❌ loadSuggestions: \(category.rawValue) failed: \(error)")
            }
        }

        isLoadingSuggestions = false
        print("📋 loadSuggestions: done, \(suggestedVendors.count) categories loaded")
    }

    private func addSuggestedVendor(_ place: PlaceResult, category: VendorCategory) async {
        guard let houseId = appState.currentHouse?.id else { return }

        let vendor = Vendor(
            houseId: houseId,
            name: place.name,
            category: category,
            address: place.address,
            source: .googlePlaces,
            googlePlaceId: place.placeId,
            rating: place.rating
        )

        do {
            try await FirebaseService.shared.saveVendor(vendor)
            await loadVendors()
        } catch {
            print("Failed to add vendor: \(error)")
        }
    }

    private func deleteVendors(at offsets: IndexSet) {
        let vendorsToDelete = offsets.map { filteredVendors[$0] }

        Task {
            for vendor in vendorsToDelete {
                do {
                    try await FirebaseService.shared.deleteVendor(vendor.id)
                } catch {
                    print("Failed to delete vendor: \(error)")
                }
            }
            await loadVendors()
        }
    }
}

// MARK: - Suggested Vendor Row

struct SuggestedVendorRow: View {
    let place: PlaceResult
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.headline)

                if let rating = place.rating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", rating))
                            .font(.caption)
                        if let count = place.ratingCount {
                            Text("(\(count))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if !place.address.isEmpty {
                    Text(place.address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(action: onAdd) {
                Text("Add")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - SystemType Extension

extension SystemType {
    var suggestedVendorCategory: VendorCategory? {
        switch self {
        case .heating, .cooling:
            return .hvac
        case .water, .plumbing:
            return .plumbing
        case .power, .electrical:
            return .electrical
        case .roofing:
            return .roofing
        case .landscaping:
            return .landscaping
        case .security:
            return .security
        case .waste, .foundation, .other:
            return nil
        }
    }
}

// MARK: - Supporting Views

struct CategoryFilterButton: View {
    let title: String
    var icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
    }
}

struct VendorRow: View {
    let vendor: Vendor

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: vendor.category.icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(vendor.name)
                        .font(.headline)

                    if vendor.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }

                Text(vendor.category.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let phone = vendor.phone {
                Button {
                    callVendor(phone)
                } label: {
                    Image(systemName: "phone.fill")
                        .foregroundColor(.green)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }

    private func callVendor(_ phone: String) {
        let cleaned = phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        if let url = URL(string: "tel://\(cleaned)") {
            UIApplication.shared.open(url)
        }
    }
}

struct EmptyVendorsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No vendors yet")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Add vendors you work with to keep their info handy")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    VendorsView(appState: AppState())
}
