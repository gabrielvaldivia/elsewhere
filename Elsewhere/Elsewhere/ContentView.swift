//
//  ContentView.swift
//  Elsewhere
//
//  Created by Gabriel Valdivia on 12/12/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "message.fill")
                }
            
            // Placeholder for future tabs
            Text("Profile")
                .tabItem {
                    Label("Profile", systemImage: "house.fill")
                }
        }
    }
}

#Preview {
    ContentView()
}
