//
//  ChatView.swift
//  Elsewhere
//
//  Created on 12/12/25.
//

import SwiftUI

struct ChatView: View {
    @ObservedObject var appState: AppState
    @StateObject private var viewModel: ChatViewModel
    
    @State private var inputText: String = ""
    @State private var callbackSetup: Bool = false
    
    init(appState: AppState) {
        self.appState = appState
        // For Phase 1 MVP: Use placeholder IDs until auth/house setup is complete
        let houseId = appState.currentHouse?.id ?? "placeholder-house-id"
        let userId = appState.currentUser?.id ?? "placeholder-user-id"
        let isOnboarding = appState.currentHouse == nil
        
        _viewModel = StateObject(wrappedValue: ChatViewModel(
            houseId: houseId,
            userId: userId,
            houseProfile: appState.houseProfile,
            isOnboarding: isOnboarding
        ))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            
                            if viewModel.isTyping {
                                TypingIndicator()
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let lastMessage = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Input area
                HStack(spacing: 12) {
                    TextField("Ask about your house...", text: $inputText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)
                        .disabled(appState.isAuthenticating)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(inputText.isEmpty || appState.isAuthenticating ? .gray : .blue)
                    }
                    .disabled(inputText.isEmpty || viewModel.isTyping || appState.isAuthenticating)
                }
                .padding()
                .overlay {
                    if appState.isAuthenticating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.trailing, 16)
                    }
                }
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        appState.currentHouse = nil
                        appState.houseProfile = nil
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Homes")
                        }
                    }
                }
            }
        }
        .onChange(of: appState.houseProfile) { _, newProfile in
            viewModel.setHouseProfile(newProfile)
        }
        .onChange(of: appState.isAuthenticated) { _, isAuthenticated in
            // Update view model when authentication completes
            if isAuthenticated, let userId = appState.currentUser?.id {
                viewModel.updateUserId(userId)
            }
        }
        .onChange(of: appState.currentUser?.id) { _, newUserId in
            // Update view model when user ID changes
            if let userId = newUserId, userId != "placeholder-user-id" {
                viewModel.updateUserId(userId)
            }
        }
        .onChange(of: appState.currentHouse?.id) { _, newHouseId in
            // If house is created during onboarding, update the view model
            if let houseId = newHouseId, viewModel.isOnboarding {
                viewModel.updateHouseId(houseId)
                viewModel.isOnboarding = false
            } else if newHouseId == nil && !viewModel.isOnboarding {
                // House was deleted, restart onboarding
                viewModel.resetForNewOnboarding()
            }
        }
        .onAppear {
            // Set up callback for house creation - only once
            if !callbackSetup {
                print("🔧 Setting up onHouseCreated callback in ChatView")
                viewModel.onHouseCreated = { house, profile in
                    print("🎯 onHouseCreated callback invoked!")
                    print("   House ID: \(house.id)")
                    print("   Profile ID: \(profile.id)")
                    print("   Profile location: \(profile.location?.address ?? "nil")")
                    print("   Profile age: \(profile.age?.description ?? "nil")")
                    print("   Profile systems: \(profile.systems.count)")
                    
                    // Set both house and profile directly (we just created them)
                    appState.setCurrentHouse(house, profile: profile)
                    
                    print("✅ After setCurrentHouse - appState.currentHouse: \(appState.currentHouse?.id ?? "nil")")
                    print("✅ After setCurrentHouse - appState.houseProfile: \(appState.houseProfile?.id ?? "nil")")
                }
                callbackSetup = true
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let messageToSend = inputText
        inputText = ""
        viewModel.sendMessage(messageToSend)
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        message.role == .user
                            ? Color.blue
                            : Color(.systemGray5)
                    )
                    .foregroundColor(
                        message.role == .user
                            ? .white
                            : .primary
                    )
                    .cornerRadius(18)
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if message.role == .agent {
                Spacer()
            }
        }
    }
}

struct TypingIndicator: View {
    @State private var animationPhase = 0
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 8, height: 8)
                        .opacity(animationPhase == index ? 0.3 : 1.0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGray5))
            .cornerRadius(18)
            
            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}

#Preview {
    ChatView(appState: AppState())
}

