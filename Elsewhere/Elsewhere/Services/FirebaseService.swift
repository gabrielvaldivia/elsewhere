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
            createdAt: Date(),
            isAnonymous: true
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
            "createdAt": Timestamp(date: user.createdAt),
            "isAnonymous": user.isAnonymous,
            "appleUserId": user.appleUserId ?? NSNull(),
            "photoURL": user.photoURL ?? NSNull()
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
            "isPrimary": house.isPrimary,
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
        print("🏠 Fetching houses for user: \(userId)")

        // Query for houses where user is owner (simpler query, filter isDeleted in memory)
        let ownerSnapshot = try await db.collection("houses")
            .whereField("ownerIds", arrayContains: userId)
            .getDocuments()

        print("🏠 Found \(ownerSnapshot.documents.count) houses where user is owner")

        var houses = try ownerSnapshot.documents.compactMap { doc -> House? in
            let house = try decodeHouse(from: doc.data())
            // Filter out deleted houses in memory
            return house.isDeleted ? nil : house
        }

        // Also query for houses where user is member
        let memberSnapshot = try await db.collection("houses")
            .whereField("memberIds", arrayContains: userId)
            .getDocuments()

        print("🏠 Found \(memberSnapshot.documents.count) houses where user is member")

        let memberHouses = try memberSnapshot.documents.compactMap { doc -> House? in
            let house = try decodeHouse(from: doc.data())
            return house.isDeleted ? nil : house
        }

        // Combine and deduplicate
        let existingIds = Set(houses.map { $0.id })
        for house in memberHouses {
            if !existingIds.contains(house.id) {
                houses.append(house)
            }
        }

        print("🏠 Total houses after deduplication: \(houses.count)")
        return houses.sorted { $0.createdAt < $1.createdAt }
    }

    func updateHouse(_ house: House) async throws {
        var updatedHouse = house
        updatedHouse.updatedAt = Date()

        let houseRef = db.collection("houses").document(house.id)
        try await houseRef.setData([
            "id": updatedHouse.id,
            "name": updatedHouse.name ?? NSNull(),
            "createdAt": Timestamp(date: updatedHouse.createdAt),
            "updatedAt": Timestamp(date: updatedHouse.updatedAt),
            "createdBy": updatedHouse.createdBy,
            "ownerIds": updatedHouse.ownerIds,
            "memberIds": updatedHouse.memberIds,
            "isPrimary": updatedHouse.isPrimary,
            "isDeleted": updatedHouse.isDeleted,
            "deletedAt": updatedHouse.deletedAt != nil ? Timestamp(date: updatedHouse.deletedAt!) : NSNull(),
            "deletedBy": updatedHouse.deletedBy ?? NSNull()
        ])
    }

    func setHousePrimary(houseId: String, userId: String) async throws {
        let houses = try await fetchUserHouses(userId: userId)
        for var house in houses {
            if house.isPrimary && house.id != houseId {
                house.isPrimary = false
                try await updateHouse(house)
            }
        }
        var targetHouse = try await fetchHouse(houseId: houseId)
        targetHouse.isPrimary = true
        try await updateHouse(targetHouse)
    }

    // MARK: - Invitation Operations

    func createInvitation(_ invitation: Invitation) async throws {
        let inviteRef = db.collection("invitations").document(invitation.id)
        try await inviteRef.setData([
            "id": invitation.id,
            "email": invitation.email.lowercased(),
            "houseId": invitation.houseId,
            "houseName": invitation.houseName ?? NSNull(),
            "role": invitation.role.rawValue,
            "invitedBy": invitation.invitedBy,
            "inviterName": invitation.inviterName ?? NSNull(),
            "status": invitation.status.rawValue,
            "createdAt": Timestamp(date: invitation.createdAt),
            "expiresAt": Timestamp(date: invitation.expiresAt)
        ])
    }

    func fetchPendingInvitations(forEmail email: String) async throws -> [Invitation] {
        let snapshot = try await db.collection("invitations")
            .whereField("email", isEqualTo: email.lowercased())
            .whereField("status", isEqualTo: InvitationStatus.pending.rawValue)
            .getDocuments()

        return try snapshot.documents.compactMap { doc in
            try decodeInvitation(from: doc.data())
        }.filter { !$0.isExpired }
    }

    func fetchInvitations(forHouse houseId: String) async throws -> [Invitation] {
        let snapshot = try await db.collection("invitations")
            .whereField("houseId", isEqualTo: houseId)
            .getDocuments()

        return try snapshot.documents.compactMap { doc in
            try decodeInvitation(from: doc.data())
        }
    }

    func updateInvitationStatus(_ invitationId: String, status: InvitationStatus) async throws {
        let inviteRef = db.collection("invitations").document(invitationId)
        try await inviteRef.updateData([
            "status": status.rawValue
        ])
    }

    func acceptInvitation(_ invitation: Invitation, userId: String) async throws {
        // Update invitation status
        try await updateInvitationStatus(invitation.id, status: .accepted)

        // Add user to house
        let house = try await fetchHouse(houseId: invitation.houseId)
        var updatedHouse = house

        switch invitation.role {
        case .owner:
            if !updatedHouse.ownerIds.contains(userId) {
                updatedHouse.ownerIds.append(userId)
            }
        case .member:
            if !updatedHouse.memberIds.contains(userId) {
                updatedHouse.memberIds.append(userId)
            }
        }

        try await updateHouse(updatedHouse)
    }

    func deleteInvitation(_ invitationId: String) async throws {
        try await db.collection("invitations").document(invitationId).delete()
    }

    // MARK: - House Access Operations

    func fetchHouseMembers(houseId: String) async throws -> [HouseAccess] {
        let house = try await fetchHouse(houseId: houseId)
        var members: [HouseAccess] = []

        // Create HouseAccess entries for owners
        for ownerId in house.ownerIds {
            if let user = try? await fetchUser(userId: ownerId) {
                members.append(HouseAccess(
                    userId: ownerId,
                    userEmail: user.email,
                    userName: user.displayName,
                    houseId: houseId,
                    role: .owner,
                    grantedBy: house.createdBy
                ))
            } else {
                members.append(HouseAccess(
                    userId: ownerId,
                    houseId: houseId,
                    role: .owner,
                    grantedBy: house.createdBy
                ))
            }
        }

        // Create HouseAccess entries for members
        for memberId in house.memberIds {
            if let user = try? await fetchUser(userId: memberId) {
                members.append(HouseAccess(
                    userId: memberId,
                    userEmail: user.email,
                    userName: user.displayName,
                    houseId: houseId,
                    role: .member,
                    grantedBy: house.createdBy
                ))
            } else {
                members.append(HouseAccess(
                    userId: memberId,
                    houseId: houseId,
                    role: .member,
                    grantedBy: house.createdBy
                ))
            }
        }

        return members
    }

    func removeUserFromHouse(userId: String, houseId: String) async throws {
        var house = try await fetchHouse(houseId: houseId)
        house.ownerIds.removeAll { $0 == userId }
        house.memberIds.removeAll { $0 == userId }
        try await updateHouse(house)
    }

    func updateUserRole(userId: String, houseId: String, newRole: HouseRole) async throws {
        var house = try await fetchHouse(houseId: houseId)

        // Remove from current lists
        house.ownerIds.removeAll { $0 == userId }
        house.memberIds.removeAll { $0 == userId }

        // Add to appropriate list
        switch newRole {
        case .owner:
            house.ownerIds.append(userId)
        case .member:
            house.memberIds.append(userId)
        }

        try await updateHouse(house)
    }

    private func decodeInvitation(from data: [String: Any]) throws -> Invitation {
        guard let id = data["id"] as? String,
              let email = data["email"] as? String,
              let houseId = data["houseId"] as? String,
              let roleString = data["role"] as? String,
              let role = HouseRole(rawValue: roleString),
              let invitedBy = data["invitedBy"] as? String,
              let statusString = data["status"] as? String,
              let status = InvitationStatus(rawValue: statusString) else {
            throw FirebaseError.invalidData
        }

        return Invitation(
            id: id,
            email: email,
            houseId: houseId,
            houseName: data["houseName"] as? String,
            role: role,
            invitedBy: invitedBy,
            inviterName: data["inviterName"] as? String,
            status: status,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            expiresAt: (data["expiresAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    // MARK: - Maintenance Item Operations

    func saveMaintenanceItem(_ item: MaintenanceItem) async throws {
        let itemRef = db.collection("maintenanceItems").document(item.id)
        var data: [String: Any] = [
            "id": item.id,
            "houseId": item.houseId,
            "title": item.title,
            "category": item.category.rawValue,
            "priority": item.priority.rawValue,
            "status": item.status.rawValue,
            "isWeatherTriggered": item.isWeatherTriggered,
            "createdAt": Timestamp(date: item.createdAt),
            "updatedAt": Timestamp(date: item.updatedAt),
            "createdBy": item.createdBy
        ]

        if let description = item.description {
            data["description"] = description
        }
        if let dueDate = item.dueDate {
            data["dueDate"] = Timestamp(date: dueDate)
        }
        if let reminderDate = item.reminderDate {
            data["reminderDate"] = Timestamp(date: reminderDate)
        }
        if let relatedSystem = item.relatedSystem {
            data["relatedSystem"] = relatedSystem.rawValue
        }
        if let relatedVendorId = item.relatedVendorId {
            data["relatedVendorId"] = relatedVendorId
        }
        if let weatherTrigger = item.weatherTrigger {
            data["weatherTrigger"] = [
                "type": weatherTrigger.type.rawValue,
                "threshold": weatherTrigger.threshold ?? NSNull()
            ] as [String : Any]
        }
        if let recurrence = item.recurrence {
            data["recurrence"] = [
                "frequency": recurrence.frequency.rawValue,
                "interval": recurrence.interval,
                "endDate": recurrence.endDate != nil ? Timestamp(date: recurrence.endDate!) : NSNull()
            ] as [String : Any]
        }
        if let notes = item.notes {
            data["notes"] = notes
        }
        if let completedAt = item.completedAt {
            data["completedAt"] = Timestamp(date: completedAt)
        }

        try await itemRef.setData(data)
    }

    func fetchMaintenanceItems(houseId: String) async throws -> [MaintenanceItem] {
        let snapshot = try await db.collection("maintenanceItems")
            .whereField("houseId", isEqualTo: houseId)
            .getDocuments()

        return try snapshot.documents.compactMap { doc in
            try decodeMaintenanceItem(from: doc.data())
        }.sorted { $0.createdAt > $1.createdAt }
    }

    func fetchPendingMaintenanceItems(houseId: String) async throws -> [MaintenanceItem] {
        let snapshot = try await db.collection("maintenanceItems")
            .whereField("houseId", isEqualTo: houseId)
            .whereField("status", in: [MaintenanceStatus.pending.rawValue, MaintenanceStatus.inProgress.rawValue])
            .getDocuments()

        return try snapshot.documents.compactMap { doc in
            try decodeMaintenanceItem(from: doc.data())
        }.sorted { item1, item2 in
            // Sort by priority first, then by due date
            if item1.priority.sortOrder != item2.priority.sortOrder {
                return item1.priority.sortOrder < item2.priority.sortOrder
            }
            if let date1 = item1.dueDate, let date2 = item2.dueDate {
                return date1 < date2
            }
            return item1.dueDate != nil
        }
    }

    func deleteMaintenanceItem(_ itemId: String) async throws {
        try await db.collection("maintenanceItems").document(itemId).delete()
    }

    private func decodeMaintenanceItem(from data: [String: Any]) throws -> MaintenanceItem {
        guard let id = data["id"] as? String,
              let houseId = data["houseId"] as? String,
              let title = data["title"] as? String,
              let categoryString = data["category"] as? String,
              let category = MaintenanceCategory(rawValue: categoryString),
              let priorityString = data["priority"] as? String,
              let priority = MaintenancePriority(rawValue: priorityString),
              let statusString = data["status"] as? String,
              let status = MaintenanceStatus(rawValue: statusString),
              let createdBy = data["createdBy"] as? String else {
            throw FirebaseError.invalidData
        }

        var weatherTrigger: WeatherTrigger?
        if let triggerData = data["weatherTrigger"] as? [String: Any],
           let typeString = triggerData["type"] as? String,
           let type = WeatherTriggerType(rawValue: typeString) {
            weatherTrigger = WeatherTrigger(
                type: type,
                threshold: triggerData["threshold"] as? Double
            )
        }

        var recurrence: RecurrencePattern?
        if let recurrenceData = data["recurrence"] as? [String: Any],
           let frequencyString = recurrenceData["frequency"] as? String,
           let frequency = RecurrenceFrequency(rawValue: frequencyString),
           let interval = recurrenceData["interval"] as? Int {
            recurrence = RecurrencePattern(
                frequency: frequency,
                interval: interval,
                endDate: (recurrenceData["endDate"] as? Timestamp)?.dateValue()
            )
        }

        var relatedSystem: SystemType?
        if let systemString = data["relatedSystem"] as? String {
            relatedSystem = SystemType(rawValue: systemString)
        }

        return MaintenanceItem(
            id: id,
            houseId: houseId,
            title: title,
            description: data["description"] as? String,
            category: category,
            priority: priority,
            status: status,
            dueDate: (data["dueDate"] as? Timestamp)?.dateValue(),
            reminderDate: (data["reminderDate"] as? Timestamp)?.dateValue(),
            relatedSystem: relatedSystem,
            relatedVendorId: data["relatedVendorId"] as? String,
            isWeatherTriggered: data["isWeatherTriggered"] as? Bool ?? false,
            weatherTrigger: weatherTrigger,
            recurrence: recurrence,
            notes: data["notes"] as? String,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date(),
            completedAt: (data["completedAt"] as? Timestamp)?.dateValue(),
            createdBy: createdBy
        )
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
        let isAnonymous = data["isAnonymous"] as? Bool ?? true
        let appleUserId = data["appleUserId"] as? String
        let photoURL = data["photoURL"] as? String

        return User(
            id: id,
            email: email,
            displayName: displayName,
            createdAt: createdAt,
            isAnonymous: isAnonymous,
            appleUserId: appleUserId,
            photoURL: photoURL
        )
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
        let isPrimary = data["isPrimary"] as? Bool ?? false
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
            isPrimary: isPrimary,
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
            var coordinates: Coordinates?
            if let coordData = locationData["coordinates"] as? [String: Any],
               let lat = coordData["latitude"] as? Double,
               let lon = coordData["longitude"] as? Double {
                coordinates = Coordinates(latitude: lat, longitude: lon)
            }
            location = Location(
                address: locationData["address"] as? String ?? "",
                city: locationData["city"] as? String ?? "",
                state: locationData["state"] as? String ?? "",
                zipCode: locationData["zipCode"] as? String ?? "",
                coordinates: coordinates
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
    // MARK: - Vendor Operations

    func saveVendor(_ vendor: Vendor) async throws {
        let vendorRef = db.collection("vendors").document(vendor.id)
        var data: [String: Any] = [
            "id": vendor.id,
            "houseId": vendor.houseId,
            "name": vendor.name,
            "category": vendor.category.rawValue,
            "isFavorite": vendor.isFavorite,
            "source": vendor.source.rawValue,
            "createdAt": Timestamp(date: vendor.createdAt),
            "updatedAt": Timestamp(date: vendor.updatedAt)
        ]

        if let phone = vendor.phone {
            data["phone"] = phone
        }
        if let email = vendor.email {
            data["email"] = email
        }
        if let address = vendor.address {
            data["address"] = address
        }
        if let notes = vendor.notes {
            data["notes"] = notes
        }
        if let googlePlaceId = vendor.googlePlaceId {
            data["googlePlaceId"] = googlePlaceId
        }
        if let rating = vendor.rating {
            data["rating"] = rating
        }

        data["workHistory"] = vendor.workHistory.map { entry -> [String: Any] in
            var entryData: [String: Any] = [
                "id": entry.id,
                "date": Timestamp(date: entry.date),
                "description": entry.description
            ]
            if let cost = entry.cost {
                entryData["cost"] = cost
            }
            if let notes = entry.notes {
                entryData["notes"] = notes
            }
            return entryData
        }

        try await vendorRef.setData(data)
    }

    func fetchVendors(houseId: String) async throws -> [Vendor] {
        let snapshot = try await db.collection("vendors")
            .whereField("houseId", isEqualTo: houseId)
            .getDocuments()

        return try snapshot.documents.compactMap { doc in
            try decodeVendor(from: doc.data())
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func fetchVendor(vendorId: String) async throws -> Vendor {
        let doc = try await db.collection("vendors").document(vendorId).getDocument()
        guard let data = doc.data() else {
            throw FirebaseError.documentNotFound
        }
        return try decodeVendor(from: data)
    }

    func deleteVendor(_ vendorId: String) async throws {
        try await db.collection("vendors").document(vendorId).delete()
    }

    private func decodeVendor(from data: [String: Any]) throws -> Vendor {
        guard let id = data["id"] as? String,
              let houseId = data["houseId"] as? String,
              let name = data["name"] as? String,
              let categoryString = data["category"] as? String,
              let category = VendorCategory(rawValue: categoryString),
              let sourceString = data["source"] as? String,
              let source = VendorSource(rawValue: sourceString) else {
            throw FirebaseError.invalidData
        }

        let workHistoryData = data["workHistory"] as? [[String: Any]] ?? []
        let workHistory = workHistoryData.compactMap { entry -> WorkHistoryEntry? in
            guard let id = entry["id"] as? String,
                  let description = entry["description"] as? String else {
                return nil
            }
            return WorkHistoryEntry(
                id: id,
                date: (entry["date"] as? Timestamp)?.dateValue() ?? Date(),
                description: description,
                cost: entry["cost"] as? Double,
                notes: entry["notes"] as? String
            )
        }

        return Vendor(
            id: id,
            houseId: houseId,
            name: name,
            category: category,
            phone: data["phone"] as? String,
            email: data["email"] as? String,
            address: data["address"] as? String,
            notes: data["notes"] as? String,
            isFavorite: data["isFavorite"] as? Bool ?? false,
            source: source,
            googlePlaceId: data["googlePlaceId"] as? String,
            rating: data["rating"] as? Double,
            workHistory: workHistory,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
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

