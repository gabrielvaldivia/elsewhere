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
        TabView {
            ChatView(appState: appState)
                .tabItem {
                    Label("Chat", systemImage: "message.fill")
                }
            
            HouseProfileView(appState: appState)
                .tabItem {
                    Label("Profile", systemImage: "house.fill")
                }
        }
        .environmentObject(appState)
    }
}

#Preview {
    ContentView()
}
