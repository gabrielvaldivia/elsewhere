//
//  House.swift
//  Elsewhere
//
//  Created on 12/12/25.
//

import Foundation

struct House: Identifiable, Codable, Hashable {
    var id: String
    var name: String?
    var createdAt: Date
    var updatedAt: Date
    var createdBy: String
    
    // Denormalized access lists for Firestore security rule performance
    // Synced from HouseAccess collection via Cloud Function
    var ownerIds: [String]
    var memberIds: [String]
    
    // Soft delete support
    var isDeleted: Bool
    var deletedAt: Date?
    var deletedBy: String?
    
    init(
        id: String = UUID().uuidString,
        name: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        createdBy: String,
        ownerIds: [String] = [],
        memberIds: [String] = [],
        isDeleted: Bool = false,
        deletedAt: Date? = nil,
        deletedBy: String? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
        self.ownerIds = ownerIds
        self.memberIds = memberIds
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
        self.deletedBy = deletedBy
    }
}

