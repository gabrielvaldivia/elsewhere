//
//  HomeSelectionView.swift
//  Elsewhere
//
//  Created on 2/8/26.
//

import SwiftUI

struct HomeSelectionView: View {
    @ObservedObject var appState: AppState
    @State private var showingAddHome = false
    @State private var showingAccountSettings = false
    @State private var houseToDelete: House?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                // Account Section
                Section {
                    Button {
                        showingAccountSettings = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.blue)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(appState.currentUser?.displayName ?? "Account")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(appState.currentUser?.email ?? "")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Homes Section
                Section {
                    if appState.userHouses.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "house")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("No homes yet")
                                .font(.headline)
                            Text("Add your first home to get started")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        ForEach(appState.userHouses) { house in
                            Button {
                                selectHome(house)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "house.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                        .frame(width: 32)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(house.name ?? "Unnamed Home")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    houseToDelete = house
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }

                    Button {
                        showingAddHome = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Add Home")
                                .foregroundColor(.primary)
                        }
                    }
                } header: {
                    Text("Your Homes")
                }

                // Sign Out Section
                Section {
                    Button(role: .destructive) {
                        appState.signOut()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Elsewhere")
            .sheet(isPresented: $showingAddHome) {
                AddHouseView(appState: appState)
            }
            .sheet(isPresented: $showingAccountSettings) {
                AccountSettingsView(appState: appState)
            }
            .onAppear {
                loadHouses()
            }
            .alert("Delete Home", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    houseToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let house = houseToDelete {
                        deleteHome(house)
                    }
                }
            } message: {
                Text("Are you sure you want to delete \"\(houseToDelete?.name ?? "this home")\"? This will permanently delete all data associated with this home including chat history, tasks, and vendors.")
            }
        }
    }

    private func deleteHome(_ house: House) {
        Task {
            do {
                try await FirebaseService.shared.deleteAllDataForHouse(houseId: house.id)
                await MainActor.run {
                    appState.userHouses.removeAll { $0.id == house.id }
                    houseToDelete = nil
                }
                print("✅ Deleted home: \(house.id)")
            } catch {
                print("❌ Failed to delete home: \(error)")
            }
        }
    }

    private func selectHome(_ house: House) {
        appState.currentHouse = house
        Task {
            if let profile = try? await FirebaseService.shared.fetchHouseProfile(houseId: house.id) {
                await MainActor.run {
                    appState.houseProfile = profile
                }
            }
        }
    }

    private func loadHouses() {
        Task {
            await appState.loadUserHouses()
        }
    }
}

// MARK: - Account Settings View

struct AccountSettingsView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(appState.currentUser?.displayName ?? "Not set")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Email")
                        Spacer()
                        Text(appState.currentUser?.email ?? "Not set")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Account Type")
                        Spacer()
                        Text(appState.currentUser?.isAnonymous == true ? "Anonymous" : "Apple ID")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Account Info")
                }

                if appState.currentUser?.isAnonymous == true {
                    Section {
                        Button {
                            upgradeAccount()
                        } label: {
                            HStack {
                                Image(systemName: "apple.logo")
                                Text("Upgrade to Apple Account")
                            }
                        }
                    } footer: {
                        Text("Link your account with Apple to keep your data across devices.")
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func upgradeAccount() {
        Task {
            do {
                let user = try await AuthenticationService.shared.linkAppleAccount()
                await MainActor.run {
                    appState.handleAccountUpgrade(user)
                    dismiss()
                }
            } catch {
                print("Failed to upgrade account: \(error)")
            }
        }
    }
}

#Preview {
    HomeSelectionView(appState: AppState())
}
