//
//  Invitation.swift
//  Elsewhere
//
//  Created on 2/8/26.
//

import Foundation

struct Invitation: Identifiable, Codable {
    var id: String
    var email: String
    var houseId: String
    var houseName: String?
    var role: HouseRole
    var invitedBy: String
    var inviterName: String?
    var status: InvitationStatus
    var createdAt: Date
    var expiresAt: Date

    init(
        id: String = UUID().uuidString,
        email: String,
        houseId: String,
        houseName: String? = nil,
        role: HouseRole = .member,
        invitedBy: String,
        inviterName: String? = nil,
        status: InvitationStatus = .pending,
        createdAt: Date = Date(),
        expiresAt: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    ) {
        self.id = id
        self.email = email
        self.houseId = houseId
        self.houseName = houseName
        self.role = role
        self.invitedBy = invitedBy
        self.inviterName = inviterName
        self.status = status
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }

    var isExpired: Bool {
        Date() > expiresAt
    }
}

enum InvitationStatus: String, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
    case expired = "expired"
}

enum HouseRole: String, Codable, CaseIterable {
    case owner = "owner"
    case member = "member"

    var displayName: String {
        switch self {
        case .owner:
            return "Owner"
        case .member:
            return "Member"
        }
    }

    var description: String {
        switch self {
        case .owner:
            return "Can manage house settings and invite others"
        case .member:
            return "Can view and edit house information"
        }
    }
}

struct HouseAccess: Identifiable, Codable {
    var id: String
    var userId: String
    var userEmail: String?
    var userName: String?
    var houseId: String
    var role: HouseRole
    var grantedBy: String
    var grantedAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String,
        userEmail: String? = nil,
        userName: String? = nil,
        houseId: String,
        role: HouseRole,
        grantedBy: String,
        grantedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.userEmail = userEmail
        self.userName = userName
        self.houseId = houseId
        self.role = role
        self.grantedBy = grantedBy
        self.grantedAt = grantedAt
    }
}
