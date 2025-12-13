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
    
    private var houseId: String
    private var userId: String
    private let firebaseService = FirebaseService.shared
    private let openAIService = OpenAIService.shared
    private var messageListener: ListenerRegistration?
    private var houseProfile: HouseProfile?
    
    // Onboarding state
    @Published var isOnboarding: Bool
    @Published var onboardingData: HouseOnboardingData = HouseOnboardingData()
    @Published var currentOnboardingQuestion: OnboardingQuestion?
    private var currentSystemIndex: Int = 0 // Track which system we're asking about
    var onHouseCreated: ((House, HouseProfile) -> Void)?
    private var createdHouse: House? // Track if house has been created
    private var createdProfile: HouseProfile? // Track the profile we're building
    
    enum OnboardingQuestion: Equatable {
        case location
        case age
        case system(SystemType) // Ask about a specific system
        case usagePattern
    }
    
    init(houseId: String, userId: String, houseProfile: HouseProfile? = nil, isOnboarding: Bool = false) {
        self.houseId = houseId
        self.userId = userId
        self.houseProfile = houseProfile
        self.isOnboarding = isOnboarding
        setupMessageListener()
        
        if isOnboarding {
            startOnboarding()
        }
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
    
    func updateHouseId(_ newHouseId: String) {
        // If we're in onboarding, preserve existing messages and update their houseId
        if isOnboarding {
            // Update houseId in all existing messages
            for i in 0..<messages.count {
                messages[i].houseId = newHouseId
            }
            
            // Save existing messages to Firebase with the new house ID BEFORE setting up listener
            // This ensures they're in Firebase when the listener loads
            // Only save messages that haven't been saved yet (those with placeholder house ID)
            Task {
                // Save messages that were created with placeholder house ID
                // Messages already saved will be loaded by the listener
                let messagesToSave = messages.filter { $0.houseId == newHouseId }
                
                for message in messagesToSave {
                    do {
                        // Check if message already exists in Firebase by trying to fetch it
                        // If it doesn't exist or has different houseId, save it
                        try await firebaseService.saveChatMessage(message)
                        print("✅ Saved message to Firebase: \(message.id)")
                    } catch {
                        print("⚠️ Failed to save message to Firebase: \(error)")
                    }
                }
                
                // Now update houseId and set up listener
                await MainActor.run {
                    self.houseId = newHouseId
                    // Recreate message listener for new house
                    self.messageListener?.remove()
                    self.setupMessageListener()
                }
            }
        } else {
            // Not in onboarding, just update normally
            self.houseId = newHouseId
            messageListener?.remove()
            setupMessageListener()
        }
    }
    
    private func setupMessageListener() {
        // Only set up listener if we have a real house ID
        guard houseId != "placeholder-house-id" else { return }
        
        // Save current messages before setting up listener (in case we're transitioning from onboarding)
        let currentMessages = messages
        
        // Listen for real-time message updates
        messageListener = firebaseService.observeChatMessages(houseId: houseId) { [weak self] firebaseMessages in
            Task { @MainActor in
                guard let self = self else { return }
                
                // If we're in onboarding and have local messages, merge them with Firebase messages
                if self.isOnboarding && !currentMessages.isEmpty {
                    // Combine: existing local messages + new Firebase messages
                    // Use a Set to avoid duplicates based on message ID
                    var mergedMessages: [ChatMessage] = []
                    var seenIds = Set<String>()
                    
                    // First, add all current local messages
                    for message in currentMessages {
                        if !seenIds.contains(message.id) {
                            mergedMessages.append(message)
                            seenIds.insert(message.id)
                        }
                    }
                    
                    // Then, add Firebase messages we haven't seen
                    for message in firebaseMessages {
                        if !seenIds.contains(message.id) {
                            mergedMessages.append(message)
                            seenIds.insert(message.id)
                        }
                    }
                    
                    // Sort by timestamp
                    mergedMessages.sort { $0.timestamp < $1.timestamp }
                    
                    self.messages = mergedMessages
                } else {
                    // Normal case: just use Firebase messages
                    self.messages = firebaseMessages
                }
            }
        }
    }
    
    func startOnboarding() {
        // Don't load messages during onboarding - start fresh
        let welcomeMessage = ChatMessage(
            houseId: houseId,
            userId: userId,
            role: .agent,
            content: "Hello! I'm your Upstate Home Copilot. I'm here to help you manage your second home. Let's start by getting to know your house better. Where is your second home located?",
            timestamp: Date()
        )
        messages.append(welcomeMessage)
        
        // Set up the first question state
        currentOnboardingQuestion = .location
    }
    
    func resetForNewOnboarding() {
        // Reset all onboarding state
        messages = []
        onboardingData = HouseOnboardingData()
        currentOnboardingQuestion = nil
        currentSystemIndex = 0
        createdHouse = nil
        createdProfile = nil
        isOnboarding = true
        
        // Remove message listener
        messageListener?.remove()
        messageListener = nil
        
        // Reset house ID to placeholder (this will also remove the listener)
        updateHouseId("placeholder-house-id")
        
        // Start fresh onboarding
        startOnboarding()
    }
    
    // Systems that are essentially universal and shouldn't be asked about
    private let obviousSystems: Set<SystemType> = [.roofing, .foundation, .power, .plumbing]
    
    private func askNextOnboardingQuestion() {
        // Determine which question to ask next and update state
        // The actual question will be asked by the LLM
        if onboardingData.location == nil {
            currentOnboardingQuestion = .location
            print("📍 Next question: Location")
        } else if onboardingData.age == nil {
            currentOnboardingQuestion = .age
            print("📅 Next question: Age")
        } else if currentSystemIndex < SystemType.allCases.count {
            let systemType = SystemType.allCases[currentSystemIndex]
            
            // Skip obvious systems that all houses have
            if obviousSystems.contains(systemType) || systemType == .other {
                // Automatically add obvious systems to the profile
                if obviousSystems.contains(systemType) && !onboardingData.systems.contains(where: { $0.type == systemType }) {
                    onboardingData.systems.append(HouseSystem(type: systemType))
                    print("✅ Auto-added obvious system: \(systemType.rawValue)")
                }
                currentSystemIndex += 1
                print("⏭️ Skipping system: \(systemType.rawValue), moving to index \(currentSystemIndex)")
                askNextOnboardingQuestion() // Skip to next question
                return
            }
            currentOnboardingQuestion = .system(systemType)
            print("🔧 Next question: System - \(systemType.rawValue) (index \(currentSystemIndex))")
        } else if onboardingData.usagePattern == nil {
            currentOnboardingQuestion = .usagePattern
            print("📊 Next question: Usage Pattern")
        } else {
            currentOnboardingQuestion = nil
            print("✅ All questions answered!")
        }
        
        // The LLM will generate the actual question in response to user input
        // So we don't need to add a message here - it will be generated when the user responds
    }
    
    private func getSystemQuestion(for systemType: SystemType) -> String {
        // These are now just used as context for the LLM
        switch systemType {
        case .heating:
            return "heating system"
        case .cooling:
            return "air conditioning or cooling"
        case .water:
            return "water system or well"
        case .power:
            return "electrical power"
        case .waste:
            return "waste/septic system"
        case .plumbing:
            return "plumbing"
        case .electrical:
            return "electrical system"
        case .roofing:
            return "roof"
        case .foundation:
            return "foundation"
        case .landscaping:
            return "landscaping or outdoor areas to maintain"
        case .security:
            return "security system"
        case .other:
            return "other systems"
        }
    }
    
    private func getOnboardingResponse(userMessage: String) -> String {
        // Generate response directly from templates - don't use LLM to avoid it asking multiple questions
        // Only use brief acknowledgments and then the exact next question
        
        if onboardingData.location == nil {
            // Shouldn't get here if we have location, but handle it
            return "Where is your second home located? Please provide the full address (street address, city, state, and ZIP code)."
        } else if onboardingData.age == nil {
            // Just got location, acknowledge and ask for age
            return "Thanks! How old is your house? Please tell me the age in years."
        } else if currentSystemIndex < SystemType.allCases.count {
            let systemType = SystemType.allCases[currentSystemIndex]
            if systemType != .other {
                let systemName = getSystemQuestion(for: systemType)
                // Acknowledge previous answer briefly and ask about this system
                return "Thanks! Does your house have \(systemName)?"
            } else {
                return "Thanks! Are there any other systems I should know about?"
            }
        } else if onboardingData.usagePattern == nil {
            return "Thanks! How often do you use the house? For example: monthly, seasonally, rarely, weekly, etc."
        } else {
            return "Perfect! I have everything I need to help you manage your second home. Let's get started!"
        }
    }
    
    private func getClarificationResponse(for question: OnboardingQuestion, userMessage: String) async throws -> String {
        // Use LLM only for clarification, with very strict prompt
        let clarificationPrompt = """
        The user's answer was unclear. Ask for clarification with EXACTLY ONE simple question.
        
        Current question type: \(question)
        User's answer: \(userMessage)
        
        Respond with ONLY one clarifying question (1 sentence max). Be friendly and brief.
        Do NOT ask about anything else. Do NOT provide advice or information.
        Do NOT ask multiple questions or use lists.
        """
        
        // Create a simple message for clarification
        let clarificationMessage = ChatMessage(
            houseId: houseId,
            userId: userId,
            role: .user,
            content: userMessage
        )
        
        // Use lower temperature for more predictable responses
        return try await openAIService.sendMessage(
            messages: [clarificationMessage],
            houseProfile: nil,
            systemPrompt: clarificationPrompt,
            temperature: 0.2 // Much lower temperature for more deterministic responses
        )
    }
    
    private func needsClarification(for question: OnboardingQuestion, userMessage: String) -> Bool {
        // Check if we successfully extracted data for the current question
        switch question {
        case .location:
            return extractLocation(from: userMessage) == nil
        case .age:
            return extractAge(from: userMessage) == nil
        case .system:
            return extractYesNo(from: userMessage) == nil
        case .usagePattern:
            return extractUsagePattern(from: userMessage) == nil
        }
    }
    
    private func checkAndAdvanceOnboarding() {
        // Check if onboarding is complete
        // Systems are complete when we've asked about all of them (or reached "other")
        let systemsComplete = currentSystemIndex >= SystemType.allCases.count
        
        let isComplete = onboardingData.isLocationComplete && 
                        onboardingData.isAgeComplete && 
                        systemsComplete &&
                        onboardingData.isUsagePatternComplete
        
        print("🔍 Onboarding check - Location: \(onboardingData.isLocationComplete), Age: \(onboardingData.isAgeComplete), Systems: \(systemsComplete) (index: \(currentSystemIndex)/\(SystemType.allCases.count)), Usage: \(onboardingData.isUsagePatternComplete), Complete: \(isComplete)")
        
        if isComplete && currentOnboardingQuestion != nil {
            print("✅ Onboarding complete! Finalizing profile...")
            // Final update to ensure everything is saved
            Task {
                await updateProfileIncrementally()
                await MainActor.run {
                    self.currentOnboardingQuestion = nil
                    self.isOnboarding = false
                }
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
        // Check for duplicates before adding
        if !messages.contains(where: { $0.id == userMessage.id }) {
            messages.append(userMessage)
        }
        
        Task {
            do {
                // Only save to Firebase if we have a real house ID
                if houseId != "placeholder-house-id" {
                    try await firebaseService.saveChatMessage(userMessage)
                }
                
                // If onboarding, use LLM with structured prompts
                if isOnboarding {
                    isTyping = true
                    errorMessage = nil
                    
                    // Track what question we were on before processing
                    let previousQuestion = currentOnboardingQuestion
                    var dataExtracted = false
                    var needsClarificationForPrevious = false
                    
                    // First, try to extract data from the response
                    
                    if let currentQuestion = currentOnboardingQuestion {
                        let hadDataBefore = hasDataForQuestion(currentQuestion)
                        let systemIndexBefore = currentSystemIndex
                        processOnboardingResponse(content, for: currentQuestion)
                        let hasDataAfter = hasDataForQuestion(currentQuestion)
                        let systemIndexAfter = currentSystemIndex
                        
                        // Data is extracted if:
                        // 1. We got the data for the question (location, age, usage)
                        // 2. OR we advanced through a system (systemIndex changed)
                        dataExtracted = (!hadDataBefore && hasDataAfter) || (systemIndexBefore != systemIndexAfter)
                        
                        // Check if we need clarification BEFORE advancing to next question
                        if !dataExtracted {
                            needsClarificationForPrevious = self.needsClarification(for: currentQuestion, userMessage: content)
                        }
                        
                        if dataExtracted {
                            print("✅ Data extracted for question: \(currentQuestion)")
                            // Advance to next question BEFORE generating response
                            askNextOnboardingQuestion()
                        }
                    }
                    
                    // Get response - use template-based response (no LLM unless clarification needed)
                    let agentResponse: String
                    if needsClarificationForPrevious, let prevQuestion = previousQuestion {
                        // Need clarification for the previous question
                        agentResponse = try await getClarificationResponse(for: prevQuestion, userMessage: content)
                    } else {
                        // Normal flow - use template response
                        agentResponse = getOnboardingResponse(userMessage: content)
                    }
                    
                    let agentMessage = ChatMessage(
                        houseId: houseId,
                        userId: userId,
                        role: .agent,
                        content: agentResponse
                    )
                    
                    // Save agent message to Firebase if we have a real house
                    if houseId != "placeholder-house-id" {
                        try await firebaseService.saveChatMessage(agentMessage)
                    }
                    
                    await MainActor.run {
                        // Check for duplicates before adding
                        if !messages.contains(where: { $0.id == agentMessage.id }) {
                            messages.append(agentMessage)
                        }
                        isTyping = false
                        
                        // Response is already generated based on the next question (which was set above if data was extracted)
                        // Template-based responses always include the question, so no need for extra checks
                        
                        // Check if onboarding is complete
                        checkAndAdvanceOnboarding()
                    }
                } else {
                    // Normal chat mode
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
                    
                    // Save agent message to Firebase if we have a real house
                    if houseId != "placeholder-house-id" {
                        try await firebaseService.saveChatMessage(agentMessage)
                    }
                    
                    await MainActor.run {
                        // Check for duplicates before adding
                        if !messages.contains(where: { $0.id == agentMessage.id }) {
                            messages.append(agentMessage)
                        }
                        isTyping = false
                    }
                }
            } catch {
                await MainActor.run {
                    isTyping = false
                    errorMessage = error.localizedDescription
                    
                    // Fallback response
                    let fallbackMessage = ChatMessage(
                        houseId: houseId,
                        userId: userId,
                        role: .agent,
                        content: isOnboarding ? 
                            generateOnboardingFallback() : 
                            generatePlaceholderResponse(to: content)
                    )
                    messages.append(fallbackMessage)
                }
            }
        }
    }
    
    private func processOnboardingResponse(_ content: String, for question: OnboardingQuestion) {
        // Extract data based on the current question
        // This runs before the LLM response, so we try to extract what we can
        switch question {
        case .location:
            if let location = extractLocation(from: content) {
                onboardingData.location = location
                print("✅ Extracted location: \(location.address), \(location.city), \(location.state)")
                // Create house and profile when we get location
                Task {
                    await createHouseIfNeeded()
                    // Wait a bit for house/profile to be created
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    await updateProfileIncrementally()
                }
            } else {
                print("⚠️ Could not extract location from: \(content)")
            }
            
        case .age:
            if let age = extractAge(from: content) {
                onboardingData.age = age
                print("✅ Extracted age: \(age) years")
                print("📊 Current onboardingData - Location: \(onboardingData.location != nil), Age: \(age), Systems: \(onboardingData.systems.count)")
                Task {
                    await updateProfileIncrementally()
                }
            } else {
                print("⚠️ Could not extract age from: \(content)")
            }
            
        case .system(let systemType):
            // Check if user said yes or indicated the system exists
            if extractYesNo(from: content) == true {
                // Check if system already exists in the list
                if !onboardingData.systems.contains(where: { $0.type == systemType }) {
                    onboardingData.systems.append(HouseSystem(type: systemType))
                    print("✅ Added system: \(systemType.rawValue)")
                    print("📊 Current systems: \(onboardingData.systems.map { $0.type.rawValue }.joined(separator: ", "))")
                    Task {
                        await updateProfileIncrementally()
                    }
                } else {
                    print("ℹ️ System \(systemType.rawValue) already in list")
                }
                // Advance to next system
                currentSystemIndex += 1
                print("➡️ Advanced to system index: \(currentSystemIndex)")
                askNextOnboardingQuestion()
            } else if extractYesNo(from: content) == false {
                // User said no, skip this system
                print("❌ User said no to system: \(systemType.rawValue)")
                currentSystemIndex += 1
                print("➡️ Advanced to system index: \(currentSystemIndex)")
                askNextOnboardingQuestion()
            } else {
                print("⚠️ Could not determine yes/no for system: \(systemType.rawValue) from: \(content)")
            }
            // If unclear, LLM will ask for clarification
            
        case .usagePattern:
            if let usagePattern = extractUsagePattern(from: content) {
                onboardingData.usagePattern = usagePattern
                print("✅ Extracted usage pattern: \(usagePattern.occupancyFrequency.rawValue)")
                print("📊 Current onboardingData - Location: \(onboardingData.location != nil), Age: \(onboardingData.age != nil), Systems: \(onboardingData.systems.count), Usage: \(usagePattern.occupancyFrequency.rawValue)")
                Task {
                    await updateProfileIncrementally()
                }
            } else {
                print("⚠️ Could not extract usage pattern from: \(content)")
            }
        }
    }
    
    private func createHouseIfNeeded() async {
        // Only create house once, when we get location
        guard createdHouse == nil else { return }
        guard let userId = userId != "placeholder-user-id" ? userId : nil else {
            print("⚠️ Cannot create house: userId is placeholder")
            return
        }
        
        do {
            let house = House(
                createdBy: userId,
                ownerIds: [userId],
                memberIds: []
            )
            
            try await firebaseService.createHouse(house)
            
            // Create initial profile with just location
            var allSystems = onboardingData.systems
            // Add obvious systems
            for obviousSystem in obviousSystems {
                if !allSystems.contains(where: { $0.type == obviousSystem }) {
                    allSystems.append(HouseSystem(type: obviousSystem))
                }
            }
            
            let profile = HouseProfile(
                houseId: house.id,
                name: onboardingData.name,
                location: onboardingData.location,
                age: onboardingData.age,
                systems: allSystems,
                usagePattern: onboardingData.usagePattern,
                riskFactors: []
            )
            
            try await firebaseService.saveHouseProfile(profile)
            
            await MainActor.run {
                createdHouse = house
                createdProfile = profile
                
                // Update house ID in view model
                updateHouseId(house.id)
                
                // Notify AppState
                if let callback = onHouseCreated {
                    print("✅ House created early! Calling callback with initial profile")
                    callback(house, profile)
                } else {
                    print("⚠️ House created but callback not set yet")
                }
            }
            
            print("✅ House and initial profile created: \(house.id)")
        } catch {
            print("❌ Failed to create house: \(error)")
            await MainActor.run {
                errorMessage = "Failed to create house: \(error.localizedDescription)"
            }
        }
    }
    
    private func updateProfileIncrementally() async {
        guard let house = createdHouse else {
            print("⚠️ Cannot update profile: house not created yet")
            return
        }
        
        // Ensure we have a profile - if not, create it
        var profile = createdProfile ?? HouseProfile(
            houseId: house.id,
            name: onboardingData.name,
            location: onboardingData.location,
            age: onboardingData.age,
            systems: [],
            usagePattern: onboardingData.usagePattern
        )
        
        // Preserve the existing profile ID if we have one
        let profileId = profile.id
        
        // Update profile with latest data
        profile.location = onboardingData.location
        profile.age = onboardingData.age
        profile.usagePattern = onboardingData.usagePattern
        
        // Update systems - ensure obvious systems are included
        var allSystems = onboardingData.systems
        for obviousSystem in obviousSystems {
            if !allSystems.contains(where: { $0.type == obviousSystem }) {
                allSystems.append(HouseSystem(type: obviousSystem))
            }
        }
        profile.systems = allSystems
        
        // Update risk factors
        profile.riskFactors = []
        if let usagePattern = onboardingData.usagePattern {
            if usagePattern.occupancyFrequency == .rarely || usagePattern.occupancyFrequency == .seasonally {
                profile.riskFactors.append(RiskFactor(
                    type: .lowOccupancy,
                    severity: .medium
                ))
            }
        }
        if let age = onboardingData.age, age > 30 {
            profile.riskFactors.append(RiskFactor(
                type: .oldSystems,
                severity: .medium
            ))
        }
        
        profile.updatedAt = Date()
        
        // Preserve the ID
        profile.id = profileId
        
        print("💾 Updating profile - ID: \(profile.id), Location: \(profile.location?.address ?? "nil"), Age: \(profile.age?.description ?? "nil"), Systems: \(profile.systems.count), Usage: \(profile.usagePattern?.occupancyFrequency.rawValue ?? "nil")")
        
        do {
            try await firebaseService.saveHouseProfile(profile)
            
            await MainActor.run {
                createdProfile = profile
                
                // Always update AppState with new profile
                if let callback = onHouseCreated {
                    print("✅ Profile updated and saved - Location: \(profile.location != nil ? profile.location!.address : "nil"), Age: \(profile.age?.description ?? "nil"), Systems: \(profile.systems.count)")
                    callback(house, profile)
                } else {
                    print("⚠️ Warning: onHouseCreated callback not set - profile updated but AppState not notified")
                }
            }
        } catch {
            print("❌ Failed to update profile: \(error)")
        }
    }
    
    private func extractYesNo(from text: String) -> Bool? {
        let lowerText = text.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Check for yes
        let yesPatterns = ["yes", "yeah", "yep", "yup", "sure", "correct", "right", "have", "has", "does", "do", "is", "are"]
        for pattern in yesPatterns {
            if lowerText.contains(pattern) && !lowerText.contains("no") && !lowerText.contains("not") && !lowerText.contains("don't") && !lowerText.contains("doesn't") {
                return true
            }
        }
        
        // Check for no
        let noPatterns = ["no", "nope", "nah", "don't", "doesn't", "does not", "do not", "haven't", "hasn't", "not"]
        for pattern in noPatterns {
            if lowerText.contains(pattern) {
                return false
            }
        }
        
        // If text is very short and just "y" or "n"
        if lowerText == "y" || lowerText == "yes" {
            return true
        }
        if lowerText == "n" || lowerText == "no" {
            return false
        }
        
        return nil
    }
    
    private func getOnboardingAcknowledgment(for question: OnboardingQuestion) -> String {
        switch question {
        case .location:
            if let location = onboardingData.location {
                return "Got it! Your house is located at \(location.address), \(location.city), \(location.state)."
            }
            return "Thanks for the location information!"
            
        case .age:
            if let age = onboardingData.age {
                return "Perfect! Your house is \(age) years old."
            }
            return "Thanks for that information!"
            
        case .system(let systemType):
            // Check if we added the system or skipped it
            let hasSystem = onboardingData.systems.contains(where: { $0.type == systemType })
            if hasSystem {
                return "Great! I've noted that your house has \(systemType.rawValue.lowercased())."
            } else {
                return "Got it, no \(systemType.rawValue.lowercased())."
            }
            
        case .usagePattern:
            if let usage = onboardingData.usagePattern {
                return "Perfect! You use the house \(usage.occupancyFrequency.rawValue.lowercased())."
            }
            return "Thanks for that information!"
        }
    }
    
    private func getOnboardingClarification(for question: OnboardingQuestion) -> String {
        switch question {
        case .location:
            return "I need the full address to continue. Could you provide the street address, city, state, and ZIP code? For example: \"123 Main St, Lake Placid, NY 12946\""
            
        case .age:
            return "I need to know how old your house is. Could you tell me the age in years? For example: \"25 years\" or \"built in 1998\""
            
        case .system(let systemType):
            return "I just need a simple yes or no: Does your house have \(systemType.rawValue.lowercased())?"
            
        case .usagePattern:
            return "I need to know how often you use the house. Could you tell me? For example: \"monthly\", \"seasonally\", \"rarely\", or \"weekly\""
        }
    }
    
    private func extractLocation(from text: String) -> Location? {
        // Try multiple parsing strategies
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        
        // Strategy 1: Comma-separated format (address, city, state zip)
        let components = trimmed.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        if components.count >= 2 {
            let address = components[0]
            var city = ""
            var state = ""
            var zip = ""
            
            if components.count >= 3 {
                // Format: address, city, state zip
                city = components[1]
                let stateZip = components[2]
                let stateZipParts = stateZip.components(separatedBy: " ").filter { !$0.isEmpty }
                
                if stateZipParts.count >= 2 {
                    state = stateZipParts[0]
                    zip = stateZipParts[1]
                } else if stateZipParts.count == 1 {
                    // Could be state or zip
                    if stateZipParts[0].count <= 2 {
                        state = stateZipParts[0]
                    } else {
                        zip = stateZipParts[0]
                    }
                }
            } else if components.count == 2 {
                // Format: address, city state zip (no comma between state and zip)
                let cityStateZip = components[1]
                // Try to parse: "City ST ZIP" or "City State ZIP"
                let parts = cityStateZip.components(separatedBy: " ").filter { !$0.isEmpty }
                if parts.count >= 3 {
                    // Assume last is zip, second to last is state, rest is city
                    zip = parts.last ?? ""
                    state = parts[parts.count - 2]
                    city = parts[0..<parts.count-2].joined(separator: " ")
                } else if parts.count == 2 {
                    // Could be "City ST" or "City ZIP"
                    if parts[1].count <= 2 {
                        state = parts[1]
                        city = parts[0]
                    } else {
                        zip = parts[1]
                        city = parts[0]
                    }
                } else {
                    city = cityStateZip
                }
            }
            
            if !address.isEmpty && !city.isEmpty {
                return Location(
                    address: address,
                    city: city,
                    state: state,
                    zipCode: zip,
                    coordinates: nil
                )
            }
        }
        
        // Strategy 2: Space-separated format (address city state zip) - IMPROVED
        // This handles cases like "12 bully hill drive north branch ny 12736"
        let spaceParts = trimmed.components(separatedBy: " ").filter { !$0.isEmpty }
        if spaceParts.count >= 4 {
            // Look for state (2 uppercase letters) and zip (5 digits)
            var stateIndex = -1
            var zipIndex = -1
            
            for (index, part) in spaceParts.enumerated() {
                // State: 2 letters (case-insensitive - will convert to uppercase)
                if part.count == 2 && stateIndex == -1 {
                    let upperPart = part.uppercased()
                    // Check if it looks like a state abbreviation (2 letters, all alphabetic)
                    if upperPart.allSatisfy({ $0.isLetter }) {
                        stateIndex = index
                    }
                }
                // ZIP: 5 digits
                if part.count == 5 && part.allSatisfy({ $0.isNumber }) && zipIndex == -1 {
                    zipIndex = index
                }
            }
            
            // If we found both state and zip
            if stateIndex > 0 && zipIndex > stateIndex {
                // Address is everything before city
                // City is everything between address and state (could be multiple words)
                // State is at stateIndex
                // ZIP is at zipIndex
                if stateIndex > 0 {
                    // Find where address ends - typically after street number and street name
                    // For now, assume address is first 2-4 words, city is the rest before state
                    // More sophisticated: look for street indicators like "street", "drive", "road", etc.
                    var addressEndIndex = 0
                    let streetIndicators = ["street", "st", "drive", "dr", "road", "rd", "avenue", "ave", "lane", "ln", "court", "ct", "way", "blvd", "boulevard"]
                    
                    // Find the last street indicator
                    for (idx, part) in spaceParts.enumerated() {
                        if idx < stateIndex && streetIndicators.contains(part.lowercased()) {
                            addressEndIndex = idx + 1
                        }
                    }
                    
                    // If no street indicator found, assume address is first 2-3 words
                    if addressEndIndex == 0 {
                        addressEndIndex = min(3, stateIndex)
                    }
                    
                    let address = spaceParts[0..<addressEndIndex].joined(separator: " ")
                    let city = spaceParts[addressEndIndex..<stateIndex].joined(separator: " ")
                    let state = spaceParts[stateIndex].uppercased()
                    let zip = spaceParts[zipIndex]
                    
                    if !address.isEmpty && !city.isEmpty {
                        return Location(
                            address: address,
                            city: city,
                            state: state,
                            zipCode: zip,
                            coordinates: nil
                        )
                    }
                }
            } else if zipIndex > 0 {
                // Found ZIP but no clear state - try to infer
                // Assume ZIP is last, state might be before it
                let possibleStateIndex = zipIndex - 1
                if possibleStateIndex >= 0 && spaceParts[possibleStateIndex].count == 2 {
                    let upperPart = spaceParts[possibleStateIndex].uppercased()
                    if upperPart.allSatisfy({ $0.isLetter }) {
                        // Find address end
                        var addressEndIndex = 0
                        let streetIndicators = ["street", "st", "drive", "dr", "road", "rd", "avenue", "ave", "lane", "ln", "court", "ct", "way", "blvd", "boulevard"]
                        
                        for (idx, part) in spaceParts.enumerated() {
                            if idx < possibleStateIndex && streetIndicators.contains(part.lowercased()) {
                                addressEndIndex = idx + 1
                            }
                        }
                        
                        if addressEndIndex == 0 {
                            addressEndIndex = min(3, possibleStateIndex)
                        }
                        
                        let address = spaceParts[0..<addressEndIndex].joined(separator: " ")
                        let city = spaceParts[addressEndIndex..<possibleStateIndex].joined(separator: " ")
                        let state = spaceParts[possibleStateIndex].uppercased()
                        let zip = spaceParts[zipIndex]
                        
                        if !address.isEmpty && !city.isEmpty {
                            return Location(
                                address: address,
                                city: city,
                                state: state,
                                zipCode: zip,
                                coordinates: nil
                            )
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private func hasDataForQuestion(_ question: OnboardingQuestion) -> Bool {
        switch question {
        case .location:
            return onboardingData.location != nil
        case .age:
            return onboardingData.age != nil
        case .system(let systemType):
            return onboardingData.systems.contains(where: { $0.type == systemType }) || 
                   currentSystemIndex > SystemType.allCases.firstIndex(of: systemType) ?? -1
        case .usagePattern:
            return onboardingData.usagePattern != nil
        }
    }
    
    private func askQuestionExplicitly(for question: OnboardingQuestion) {
        // Explicitly ask the next question if LLM didn't
        let questionText: String
        switch question {
        case .location:
            questionText = "Where is your second home located? Please provide the full address (street address, city, state, and ZIP code)."
        case .age:
            questionText = "How old is your house? Please tell me the age in years."
        case .system(let systemType):
            let systemName = getSystemQuestion(for: systemType)
            questionText = "Does your house have \(systemName)?"
        case .usagePattern:
            questionText = "How often do you use the house? (For example: monthly, seasonally, rarely, weekly, etc.)"
        }
        
        let questionMessage = ChatMessage(
            houseId: houseId,
            userId: userId,
            role: .agent,
            content: questionText,
            timestamp: Date()
        )
        messages.append(questionMessage)
        
        // Save to Firebase if we have a real house
        if houseId != "placeholder-house-id" {
            Task {
                try? await firebaseService.saveChatMessage(questionMessage)
            }
        }
    }
    
    private func extractAge(from text: String) -> Int? {
        let lowerText = text.lowercased()
        let currentYear = Calendar.current.component(.year, from: Date())
        
        // Pattern 1: "built in 2009" or "built 2009"
        let builtInPattern = #"(?:built\s+in|built)\s+(\d{4})"#
        if let regex = try? NSRegularExpression(pattern: builtInPattern, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                if let yearRange = Range(match.range(at: 1), in: text),
                   let year = Int(text[yearRange]),
                   year >= 1800 && year <= currentYear {
                    let age = currentYear - year
                    if age >= 0 && age <= 200 {
                        return age
                    }
                }
            }
        }
        
        // Pattern 2: "25 years old" or "25 years"
        let agePattern = #"\b(\d{1,3})\s*(?:years?|yrs?|year old|years old)\b"#
        if let regex = try? NSRegularExpression(pattern: agePattern, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                if let ageRange = Range(match.range(at: 1), in: text),
                   let age = Int(text[ageRange]),
                   age >= 0 && age <= 200 {
                    return age
                }
            }
        }
        
        // Pattern 3: Just a 4-digit year (1800-2024)
        let yearPattern = #"\b(1[89]\d{2}|20[0-2]\d)\b"#
        if let regex = try? NSRegularExpression(pattern: yearPattern, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                if let yearRange = Range(match.range(at: 1), in: text),
                   let year = Int(text[yearRange]),
                   year >= 1800 && year <= currentYear {
                    let age = currentYear - year
                    if age >= 0 && age <= 200 {
                        return age
                    }
                }
            }
        }
        
        // Pattern 4: Just a number if it's reasonable (0-200)
        let numbers = text.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
            .filter { $0 >= 0 && $0 <= 200 }
        
        return numbers.first
    }
    
    private func extractSystems(from text: String) -> [HouseSystem]? {
        var foundSystems: [HouseSystem] = []
        
        let lowerText = text.lowercased()
        
        for systemType in SystemType.allCases {
            let systemName = systemType.rawValue.lowercased()
            if lowerText.contains(systemName) {
                foundSystems.append(HouseSystem(type: systemType))
            }
        }
        
        return foundSystems.isEmpty ? nil : foundSystems
    }
    
    private func extractUsagePattern(from text: String) -> UsagePattern? {
        let lowerText = text.lowercased()
        
        // Check for frequency
        var frequency: OccupancyFrequency?
        for freq in [OccupancyFrequency.daily, .weekly, .biweekly, .monthly, .seasonally, .rarely] {
            if lowerText.contains(freq.rawValue.lowercased()) {
                frequency = freq
                break
            }
        }
        
        // Check for seasonal
        let seasonal = lowerText.contains("seasonal") || lowerText.contains("season")
        
        if let frequency = frequency {
            return UsagePattern(
                occupancyFrequency: frequency,
                typicalStayDuration: nil,
                seasonalUsage: seasonal,
                notes: nil
            )
        }
        
        return nil
    }
    
    private func generateOnboardingFallback() -> String {
        if let question = currentOnboardingQuestion {
            return getOnboardingClarification(for: question)
        }
        return "I'm here to help you set up your house profile. Let's continue..."
    }
    
    private func createHouseFromOnboarding() {
        guard let userId = userId != "placeholder-user-id" ? userId : nil else {
            errorMessage = "Please wait for authentication"
            return
        }
        
        Task {
            do {
                let house = House(
                    createdBy: userId,
                    ownerIds: [userId],
                    memberIds: []
                )
                
                try await firebaseService.createHouse(house)
                
                // Create house profile
                // Ensure obvious systems are included
                var allSystems = onboardingData.systems
                for obviousSystem in obviousSystems {
                    if !allSystems.contains(where: { $0.type == obviousSystem }) {
                        allSystems.append(HouseSystem(type: obviousSystem))
                    }
                }
                
                var profile = HouseProfile(
                    houseId: house.id,
                    name: onboardingData.name,
                    location: onboardingData.location,
                    age: onboardingData.age,
                    systems: allSystems,
                    usagePattern: onboardingData.usagePattern,
                    riskFactors: []
                )
                
                // Add risk factors
                if let usagePattern = onboardingData.usagePattern {
                    if usagePattern.occupancyFrequency == .rarely || usagePattern.occupancyFrequency == .seasonally {
                        profile.riskFactors.append(RiskFactor(
                            type: .lowOccupancy,
                            severity: .medium
                        ))
                    }
                }
                
                if let age = onboardingData.age, age > 30 {
                    profile.riskFactors.append(RiskFactor(
                        type: .oldSystems,
                        severity: .medium
                    ))
                }
                
                try await firebaseService.saveHouseProfile(profile)
                
                print("✅ House created: \(house.id)")
                print("✅ Profile created - Location: \(profile.location != nil ? "\(profile.location!.address)" : "nil"), Age: \(profile.age ?? -1), Systems: \(profile.systems.count), Usage: \(profile.usagePattern != nil)")
                
                await MainActor.run {
                    // Notify that house was created
                    if let callback = onHouseCreated {
                        print("✅ Calling onHouseCreated callback")
                        callback(house, profile)
                    } else {
                        print("❌ ERROR: onHouseCreated callback is nil! Cannot update AppState.")
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create house: \(error.localizedDescription)"
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

