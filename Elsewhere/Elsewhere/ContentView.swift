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
            if appState.isAuthenticated {
                // Always show chat - it will handle onboarding conversationally
                TabView {
                    ChatView(appState: appState)
                        .tabItem {
                            Label("Chat", systemImage: "message.fill")
                        }
                    
                    if appState.currentHouse != nil {
                        HouseProfileView(appState: appState)
                            .tabItem {
                                Label("Profile", systemImage: "house.fill")
                            }
                    } else {
                        // Show placeholder during onboarding
                        VStack(spacing: 20) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            Text("Complete setup in Chat")
                                .foregroundColor(.secondary)
                        }
                        .tabItem {
                            Label("Profile", systemImage: "house.fill")
                        }
                    }
                }
            } else {
                // Show loading while authenticating
                VStack(spacing: 20) {
                    ProgressView()
                    Text("Setting up...")
                        .foregroundColor(.secondary)
                }
            }
        }
        .environmentObject(appState)
    }
}

#Preview {
    ContentView()
}
