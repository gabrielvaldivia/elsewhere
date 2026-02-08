//
//  ContentView.swift
//  Elsewhere
//
//  Created by Gabriel Valdivia on 12/12/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        Group {
            if appState.isAuthenticating {
                VStack(spacing: 20) {
                    ProgressView()
                    Text("Loading...")
                        .foregroundColor(.secondary)
                }
            } else if appState.showAuthenticationView {
                AuthenticationView(appState: appState)
            } else if appState.isAuthenticated {
                HomeSelectionView(appState: appState)
            } else {
                AuthenticationView(appState: appState)
            }
        }
        .environmentObject(appState)
    }
}

struct MainTabView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        TabView {
            ChatView(appState: appState)
                .tabItem {
                    Label("Chat", systemImage: "message.fill")
                }

            MaintenanceView(appState: appState)
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }

            VendorsView(appState: appState)
                .tabItem {
                    Label("Vendors", systemImage: "person.2.fill")
                }

            HouseProfileView(appState: appState)
                .tabItem {
                    Label("Profile", systemImage: "house.fill")
                }
        }
    }
}

#Preview {
    ContentView()
}
