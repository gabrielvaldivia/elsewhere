//
//  ChatView.swift
//  Elsewhere
//
//  Created on 12/12/25.
//

import SwiftUI

struct ChatView: View {
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isTyping: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            
                            if isTyping {
                                TypingIndicator()
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let lastMessage = messages.last {
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
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(inputText.isEmpty ? .gray : .blue)
                    }
                    .disabled(inputText.isEmpty || isTyping)
                }
                .padding()
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let userMessage = ChatMessage(
            houseId: "placeholder-house-id", // TODO: Get from app state
            userId: "placeholder-user-id", // TODO: Get from auth
            role: .user,
            content: inputText
        )
        
        messages.append(userMessage)
        let messageToSend = inputText
        inputText = ""
        
        // TODO: Send to OpenAI API
        isTyping = true
        
        // Simulate agent response for now
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let agentMessage = ChatMessage(
                houseId: userMessage.houseId,
                userId: userMessage.userId,
                role: .agent,
                content: "I understand you're asking about: \(messageToSend). This feature is coming soon!"
            )
            messages.append(agentMessage)
            isTyping = false
        }
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
    ChatView()
}

