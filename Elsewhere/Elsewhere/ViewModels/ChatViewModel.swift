//
//  ChatViewModel.swift
//  Elsewhere
//
//  Created on 12/12/25.
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isTyping: Bool = false
    @Published var errorMessage: String?
    
    private let houseId: String
    private var userId: String
    private let firebaseService = FirebaseService.shared
    private let openAIService = OpenAIService.shared
    private var messageListener: ListenerRegistration?
    private var houseProfile: HouseProfile?
    
    init(houseId: String, userId: String, houseProfile: HouseProfile? = nil) {
        self.houseId = houseId
        self.userId = userId
        self.houseProfile = houseProfile
        setupMessageListener()
    }
    
    deinit {
        messageListener?.remove()
    }
    
    func setHouseProfile(_ profile: HouseProfile?) {
        self.houseProfile = profile
    }
    
    func updateUserId(_ newUserId: String) {
        self.userId = newUserId
    }
    
    private func setupMessageListener() {
        // Listen for real-time message updates
        messageListener = firebaseService.observeChatMessages(houseId: houseId) { [weak self] messages in
            Task { @MainActor in
                self?.messages = messages
            }
        }
    }
    
    func sendMessage(_ content: String) {
        guard !content.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        // Check if we have a valid user ID (not placeholder)
        guard userId != "placeholder-user-id" else {
            errorMessage = "Authentication in progress. Please wait a moment and try again."
            return
        }
        
        let userMessage = ChatMessage(
            houseId: houseId,
            userId: userId,
            role: .user,
            content: content
        )
        
        // Add user message immediately for better UX
        messages.append(userMessage)
        
        Task {
            do {
                // Save user message to Firebase
                try await firebaseService.saveChatMessage(userMessage)
                
                // Get agent response
                isTyping = true
                errorMessage = nil
                
                let agentResponse = try await openAIService.sendMessage(
                    messages: messages,
                    houseProfile: houseProfile
                )
                
                let agentMessage = ChatMessage(
                    houseId: houseId,
                    userId: userId,
                    role: .agent,
                    content: agentResponse
                )
                
                // Save agent message to Firebase
                try await firebaseService.saveChatMessage(agentMessage)
                
                // Message will be added via listener, but add it here too for immediate feedback
                await MainActor.run {
                    messages.append(agentMessage)
                    isTyping = false
                }
            } catch {
                await MainActor.run {
                    isTyping = false
                    errorMessage = error.localizedDescription
                    
                    // Fallback to placeholder response if OpenAI fails
                    let fallbackMessage = ChatMessage(
                        houseId: houseId,
                        userId: userId,
                        role: .agent,
                        content: generatePlaceholderResponse(to: content)
                    )
                    messages.append(fallbackMessage)
                }
            }
        }
    }
    
    private func generatePlaceholderResponse(to userMessage: String) -> String {
        // Fallback responses if OpenAI is unavailable
        let responses = [
            "I understand you're asking about: \(userMessage). I'm still learning about your house. Can you tell me more?",
            "That's a great question! I'm here to help you manage your second home.",
            "Thanks for that information. I'm building my understanding of your house so I can provide better recommendations."
        ]
        return responses.randomElement() ?? "I'm here to help!"
    }
}

