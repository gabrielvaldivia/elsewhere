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

    var body: some View {
        NavigationStack {
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
                } else if filteredVendors.isEmpty {
                    Spacer()
                    EmptyVendorsView()
                    Spacer()
                } else {
                    List {
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
            .refreshable {
                await loadVendors()
            }
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
