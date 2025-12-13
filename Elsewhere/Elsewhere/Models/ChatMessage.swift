//
//  ChatMessage.swift
//  Elsewhere
//
//  Created on 12/12/25.
//

import Foundation

struct ChatMessage: Identifiable, Codable {
    var id: String
    var houseId: String
    var userId: String
    var role: MessageRole
    var content: String
    var timestamp: Date
    var relatedTaskId: String?
    var relatedContactId: String?
    
    init(
        id: String = UUID().uuidString,
        houseId: String,
        userId: String,
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        relatedTaskId: String? = nil,
        relatedContactId: String? = nil
    ) {
        self.id = id
        self.houseId = houseId
        self.userId = userId
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.relatedTaskId = relatedTaskId
        self.relatedContactId = relatedContactId
    }
}

enum MessageRole: String, Codable {
    case user = "user"
    case agent = "assistant"
    case system = "system"
}

