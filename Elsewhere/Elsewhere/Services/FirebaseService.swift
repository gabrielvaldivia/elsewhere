//
//  FirebaseService.swift
//  Elsewhere
//
//  Created on 12/12/25.
//

import Foundation
import Combine
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

@MainActor
class FirebaseService: ObservableObject {
    static let shared = FirebaseService()
    
    private let db: Firestore
    
    private init() {
        // Firebase will be configured in ElsewhereApp
        self.db = Firestore.firestore()
    }
    
    // MARK: - Authentication
    
    func signInAnonymously() async throws -> User {
        let authResult = try await Auth.auth().signInAnonymously()
        let user = User(
            id: authResult.user.uid,
            email: authResult.user.email ?? "",
            displayName: authResult.user.displayName,
            createdAt: Date()
        )
        return user
    }
    
    func signIn(withEmail email: String, password: String) async throws -> User {
        let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
        let user = User(
            id: authResult.user.uid,
            email: authResult.user.email ?? "",
            displayName: authResult.user.displayName,
            createdAt: Date()
        )
        return user
    }
    
    func createUser(withEmail email: String, password: String, displayName: String?) async throws -> User {
        let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
        
        // Update display name if provided
        if let displayName = displayName {
            let changeRequest = authResult.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()
        }
        
        let user = User(
            id: authResult.user.uid,
            email: authResult.user.email ?? "",
            displayName: authResult.user.displayName,
            createdAt: Date()
        )
        
        // Save user document to Firestore
        try await saveUser(user)
        
        return user
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
    }
    
    var currentAuthUser: FirebaseAuth.User? {
        Auth.auth().currentUser
    }
    
    // MARK: - User Operations
    
    func saveUser(_ user: User) async throws {
        let userRef = db.collection("users").document(user.id)
        try await userRef.setData([
            "id": user.id,
            "email": user.email,
            "displayName": user.displayName ?? NSNull(),
            "createdAt": Timestamp(date: user.createdAt)
        ])
    }
    
    func fetchUser(userId: String) async throws -> User {
        let userDoc = try await db.collection("users").document(userId).getDocument()
        guard let data = userDoc.data() else {
            throw FirebaseError.documentNotFound
        }
        
        return try decodeUser(from: data)
    }
    
    // MARK: - House Operations
    
    func createHouse(_ house: House) async throws {
        let houseRef = db.collection("houses").document(house.id)
        try await houseRef.setData([
            "id": house.id,
            "name": house.name ?? NSNull(),
            "createdAt": Timestamp(date: house.createdAt),
            "updatedAt": Timestamp(date: house.updatedAt),
            "createdBy": house.createdBy,
            "ownerIds": house.ownerIds,
            "memberIds": house.memberIds,
            "isDeleted": house.isDeleted,
            "deletedAt": house.deletedAt != nil ? Timestamp(date: house.deletedAt!) : NSNull(),
            "deletedBy": house.deletedBy ?? NSNull()
        ])
    }
    
    func fetchHouse(houseId: String) async throws -> House {
        let houseDoc = try await db.collection("houses").document(houseId).getDocument()
        guard let data = houseDoc.data() else {
            throw FirebaseError.documentNotFound
        }
        
        return try decodeHouse(from: data)
    }
    
    func fetchUserHouses(userId: String) async throws -> [House] {
        // For Phase 1: Simple query for houses where user is owner
        // In Phase 3, we'll use HouseAccess collection
        let snapshot = try await db.collection("houses")
            .whereField("ownerIds", arrayContains: userId)
            .whereField("isDeleted", isEqualTo: false)
            .getDocuments()
        
        return try snapshot.documents.map { doc in
            try decodeHouse(from: doc.data())
        }
    }
    
    // MARK: - House Profile Operations
    
    func saveHouseProfile(_ profile: HouseProfile) async throws {
        let profileRef = db.collection("houseProfiles").document(profile.id)
        try await profileRef.setData(try encodeHouseProfile(profile))
    }
    
    func fetchHouseProfile(houseId: String) async throws -> HouseProfile? {
        let snapshot = try await db.collection("houseProfiles")
            .whereField("houseId", isEqualTo: houseId)
            .limit(to: 1)
            .getDocuments()
        
        guard let doc = snapshot.documents.first,
              let data = doc.data() as? [String: Any] else {
            return nil
        }
        
        return try decodeHouseProfile(from: data)
    }
    
    // MARK: - Chat Message Operations
    
    func saveChatMessage(_ message: ChatMessage) async throws {
        let messageRef = db.collection("chatMessages").document(message.id)
        var data: [String: Any] = [
            "id": message.id,
            "houseId": message.houseId,
            "userId": message.userId,
            "role": message.role.rawValue,
            "content": message.content,
            "timestamp": Timestamp(date: message.timestamp)
        ]
        if let relatedTaskId = message.relatedTaskId {
            data["relatedTaskId"] = relatedTaskId
        }
        if let relatedContactId = message.relatedContactId {
            data["relatedContactId"] = relatedContactId
        }
        try await messageRef.setData(data)
    }
    
    func fetchChatMessages(houseId: String, limit: Int = 50) async throws -> [ChatMessage] {
        let snapshot = try await db.collection("chatMessages")
            .whereField("houseId", isEqualTo: houseId)
            .order(by: "timestamp", descending: false)
            .limit(to: limit)
            .getDocuments()
        
        return try snapshot.documents.map { doc in
            try decodeChatMessage(from: doc.data())
        }
    }
    
    func observeChatMessages(houseId: String, onUpdate: @escaping ([ChatMessage]) -> Void) -> ListenerRegistration {
        return db.collection("chatMessages")
            .whereField("houseId", isEqualTo: houseId)
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    if let error = error {
                        print("Error fetching messages: \(error)")
                    }
                    return
                }
                
                let messages = documents.compactMap { doc -> ChatMessage? in
                    do {
                        return try self.decodeChatMessage(from: doc.data())
                    } catch {
                        print("Error decoding message: \(error)")
                        return nil
                    }
                }
                
                onUpdate(messages)
            }
    }
    
    // MARK: - Delete Operations (for testing)
    
    func deleteAllDataForHouse(houseId: String) async throws {
        // Delete all chat messages
        let messagesSnapshot = try await db.collection("chatMessages")
            .whereField("houseId", isEqualTo: houseId)
            .getDocuments()
        
        for doc in messagesSnapshot.documents {
            try await doc.reference.delete()
        }
        print("✅ Deleted \(messagesSnapshot.documents.count) chat messages")
        
        // Delete house profile
        let profileSnapshot = try await db.collection("houseProfiles")
            .whereField("houseId", isEqualTo: houseId)
            .getDocuments()
        
        for doc in profileSnapshot.documents {
            try await doc.reference.delete()
        }
        print("✅ Deleted \(profileSnapshot.documents.count) house profiles")
        
        // Delete house
        try await db.collection("houses").document(houseId).delete()
        print("✅ Deleted house: \(houseId)")
    }
    
    // MARK: - Encoding/Decoding Helpers
    
    private func encodeHouseProfile(_ profile: HouseProfile) throws -> [String: Any] {
        var data: [String: Any] = [
            "id": profile.id,
            "houseId": profile.houseId,
            "createdAt": Timestamp(date: profile.createdAt),
            "updatedAt": Timestamp(date: profile.updatedAt),
            "systems": try profile.systems.map { system -> [String: Any] in
                var systemData: [String: Any] = [
                    "id": system.id,
                    "type": system.type.rawValue
                ]
                if let description = system.description {
                    systemData["description"] = description
                }
                if let age = system.age {
                    systemData["age"] = age
                }
                if let lastServiced = system.lastServiced {
                    systemData["lastServiced"] = Timestamp(date: lastServiced)
                }
                if let notes = system.notes {
                    systemData["notes"] = notes
                }
                return systemData
            }
        ]
        
        if let name = profile.name {
            data["name"] = name
        }
        
        if let location = profile.location {
            var locationData: [String: Any] = [
                "address": location.address,
                "city": location.city,
                "state": location.state,
                "zipCode": location.zipCode
            ]
            if let coordinates = location.coordinates {
                locationData["coordinates"] = [
                    "latitude": coordinates.latitude,
                    "longitude": coordinates.longitude
                ]
            }
            data["location"] = locationData
        }
        
        if let size = profile.size {
            var sizeData: [String: Any] = [:]
            if let squareFeet = size.squareFeet {
                sizeData["squareFeet"] = squareFeet
            }
            if let bedrooms = size.bedrooms {
                sizeData["bedrooms"] = bedrooms
            }
            if let bathrooms = size.bathrooms {
                sizeData["bathrooms"] = bathrooms
            }
            if let lotSize = size.lotSize {
                sizeData["lotSize"] = lotSize
            }
            data["size"] = sizeData
        }
        
        if let age = profile.age {
            data["age"] = age
        }
        
        if let usagePattern = profile.usagePattern {
            var usageData: [String: Any] = [
                "seasonalUsage": usagePattern.seasonalUsage
            ]
            if let occupancyFrequency = usagePattern.occupancyFrequency {
                usageData["occupancyFrequency"] = occupancyFrequency.rawValue
            }
            if let typicalStayDuration = usagePattern.typicalStayDuration {
                usageData["typicalStayDuration"] = typicalStayDuration
            }
            if let notes = usagePattern.notes {
                usageData["notes"] = notes
            }
            data["usagePattern"] = usageData
        }
        
        data["riskFactors"] = try profile.riskFactors.map { risk -> [String: Any] in
            var riskData: [String: Any] = [
                "id": risk.id,
                "type": risk.type.rawValue,
                "severity": risk.severity.rawValue
            ]
            if let description = risk.description {
                riskData["description"] = description
            }
            return riskData
        }
        
        if let seasonality = profile.seasonality {
            var seasonalityData: [String: Any] = [
                "yearRound": seasonality.yearRound
            ]
            if let primarySeason = seasonality.primarySeason {
                seasonalityData["primarySeason"] = primarySeason.rawValue
            }
            if let notes = seasonality.notes {
                seasonalityData["notes"] = notes
            }
            data["seasonality"] = seasonalityData
        }
        
        return data
    }
    
    private func decodeUser(from data: [String: Any]) throws -> User {
        guard let id = data["id"] as? String,
              let email = data["email"] as? String else {
            throw FirebaseError.invalidData
        }
        
        let displayName = data["displayName"] as? String
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        
        return User(id: id, email: email, displayName: displayName, createdAt: createdAt)
    }
    
    private func decodeHouse(from data: [String: Any]) throws -> House {
        guard let id = data["id"] as? String,
              let createdBy = data["createdBy"] as? String else {
            throw FirebaseError.invalidData
        }
        
        let name = data["name"] as? String
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        let ownerIds = data["ownerIds"] as? [String] ?? []
        let memberIds = data["memberIds"] as? [String] ?? []
        let isDeleted = data["isDeleted"] as? Bool ?? false
        let deletedAt = (data["deletedAt"] as? Timestamp)?.dateValue()
        let deletedBy = data["deletedBy"] as? String
        
        return House(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            createdBy: createdBy,
            ownerIds: ownerIds,
            memberIds: memberIds,
            isDeleted: isDeleted,
            deletedAt: deletedAt,
            deletedBy: deletedBy
        )
    }
    
    private func decodeHouseProfile(from data: [String: Any]) throws -> HouseProfile {
        guard let id = data["id"] as? String,
              let houseId = data["houseId"] as? String else {
            throw FirebaseError.invalidData
        }
        
        let name = data["name"] as? String
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        let age = data["age"] as? Int
        
        // Decode location
        var location: Location?
        if let locationData = data["location"] as? [String: Any] {
            location = Location(
                address: locationData["address"] as? String ?? "",
                city: locationData["city"] as? String ?? "",
                state: locationData["state"] as? String ?? "",
                zipCode: locationData["zipCode"] as? String ?? "",
                coordinates: nil // TODO: Decode coordinates if needed
            )
        }
        
        // Decode systems
        let systemsData = data["systems"] as? [[String: Any]] ?? []
        let systems = try systemsData.map { systemData -> HouseSystem in
            guard let typeString = systemData["type"] as? String,
                  let type = SystemType(rawValue: typeString) else {
                throw FirebaseError.invalidData
            }
            return HouseSystem(
                id: systemData["id"] as? String ?? UUID().uuidString,
                type: type,
                description: systemData["description"] as? String,
                age: systemData["age"] as? Int,
                lastServiced: (systemData["lastServiced"] as? Timestamp)?.dateValue(),
                notes: systemData["notes"] as? String
            )
        }
        
        // Decode usage pattern
        var usagePattern: UsagePattern?
        if let usageData = data["usagePattern"] as? [String: Any] {
            let frequency: OccupancyFrequency? = (usageData["occupancyFrequency"] as? String).flatMap { OccupancyFrequency(rawValue: $0) }
            usagePattern = UsagePattern(
                occupancyFrequency: frequency,
                typicalStayDuration: usageData["typicalStayDuration"] as? Int,
                seasonalUsage: usageData["seasonalUsage"] as? Bool ?? false,
                notes: usageData["notes"] as? String
            )
        }
        
        // Decode risk factors
        let riskFactorsData = data["riskFactors"] as? [[String: Any]] ?? []
        let riskFactors = try riskFactorsData.map { riskData -> RiskFactor in
            guard let typeString = riskData["type"] as? String,
                  let type = RiskType(rawValue: typeString),
                  let severityString = riskData["severity"] as? String,
                  let severity = RiskSeverity(rawValue: severityString) else {
                throw FirebaseError.invalidData
            }
            return RiskFactor(
                id: riskData["id"] as? String ?? UUID().uuidString,
                type: type,
                description: riskData["description"] as? String,
                severity: severity
            )
        }
        
        return HouseProfile(
            id: id,
            houseId: houseId,
            name: name,
            location: location,
            size: nil, // TODO: Decode size if needed
            age: age,
            systems: systems,
            usagePattern: usagePattern,
            riskFactors: riskFactors,
            seasonality: nil, // TODO: Decode seasonality if needed
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    private func decodeChatMessage(from data: [String: Any]) throws -> ChatMessage {
        guard let id = data["id"] as? String,
              let houseId = data["houseId"] as? String,
              let userId = data["userId"] as? String,
              let roleString = data["role"] as? String,
              let role = MessageRole(rawValue: roleString),
              let content = data["content"] as? String else {
            throw FirebaseError.invalidData
        }
        
        let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        let relatedTaskId = data["relatedTaskId"] as? String
        let relatedContactId = data["relatedContactId"] as? String
        
        return ChatMessage(
            id: id,
            houseId: houseId,
            userId: userId,
            role: role,
            content: content,
            timestamp: timestamp,
            relatedTaskId: relatedTaskId,
            relatedContactId: relatedContactId
        )
    }
}

enum FirebaseError: LocalizedError {
    case documentNotFound
    case invalidData
    case authenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .documentNotFound:
            return "Document not found"
        case .invalidData:
            return "Invalid data format"
        case .authenticationFailed:
            return "Authentication failed"
        }
    }
}

