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
        self.houseId = newHouseId
        // Recreate message listener for new house
        messageListener?.remove()
        setupMessageListener()
    }
    
    private func setupMessageListener() {
        // Only set up listener if we have a real house ID
        guard houseId != "placeholder-house-id" else { return }
        
        // Listen for real-time message updates
        messageListener = firebaseService.observeChatMessages(houseId: houseId) { [weak self] messages in
            Task { @MainActor in
                self?.messages = messages
            }
        }
    }
    
    private func startOnboarding() {
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
    
    // Systems that are essentially universal and shouldn't be asked about
    private let obviousSystems: Set<SystemType> = [.roofing, .foundation, .power, .plumbing]
    
    private func askNextOnboardingQuestion() {
        // Determine which question to ask next and update state
        // The actual question will be asked by the LLM
        if onboardingData.location == nil {
            currentOnboardingQuestion = .location
        } else if onboardingData.age == nil {
            currentOnboardingQuestion = .age
        } else if currentSystemIndex < SystemType.allCases.count {
            let systemType = SystemType.allCases[currentSystemIndex]
            
            // Skip obvious systems that all houses have
            if obviousSystems.contains(systemType) || systemType == .other {
                // Automatically add obvious systems to the profile
                if obviousSystems.contains(systemType) && !onboardingData.systems.contains(where: { $0.type == systemType }) {
                    onboardingData.systems.append(HouseSystem(type: systemType))
                }
                currentSystemIndex += 1
                askNextOnboardingQuestion() // Skip to next question
                return
            }
            currentOnboardingQuestion = .system(systemType)
        } else if onboardingData.usagePattern == nil {
            currentOnboardingQuestion = .usagePattern
        } else {
            currentOnboardingQuestion = nil
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
    
    private func getOnboardingLLMResponse(userMessage: String) async throws -> String {
        // Build context about what we're collecting
        var context = "You are helping a user set up their second home profile through a friendly conversation. "
        
        // What we've collected so far
        var collectedInfo: [String] = []
        if let location = onboardingData.location {
            collectedInfo.append("Location: \(location.address), \(location.city), \(location.state)")
        }
        if let age = onboardingData.age {
            collectedInfo.append("Age: \(age) years old")
        }
        if !onboardingData.systems.isEmpty {
            let systemNames = onboardingData.systems.map { $0.type.rawValue }.joined(separator: ", ")
            collectedInfo.append("Systems: \(systemNames)")
        }
        if let usage = onboardingData.usagePattern {
            collectedInfo.append("Usage: \(usage.occupancyFrequency.rawValue)")
        }
        
        if !collectedInfo.isEmpty {
            context += "So far you've learned: \(collectedInfo.joined(separator: "; ")). "
        }
        
        // What we need next
        var nextQuestion = ""
        if onboardingData.location == nil {
            nextQuestion = "Ask for the house location (full address: street, city, state, ZIP). Be conversational and friendly."
        } else if onboardingData.age == nil {
            nextQuestion = "Ask how old the house is (in years). Be conversational."
        } else if currentSystemIndex < SystemType.allCases.count {
            let systemType = SystemType.allCases[currentSystemIndex]
            if systemType != .other {
                let systemName = getSystemQuestion(for: systemType)
                nextQuestion = "Ask if the house has \(systemName). Be conversational - you can ask it naturally, like 'What about heating?' or 'Do you have air conditioning?' Keep it friendly and brief."
            } else {
                nextQuestion = "Ask if there are any other systems. Be brief."
            }
        } else if onboardingData.usagePattern == nil {
            nextQuestion = "Ask how often they use the house (monthly, seasonally, rarely, etc.). Be conversational."
        } else {
            nextQuestion = "Thank them and let them know you have everything you need. Be warm and friendly."
        }
        
        context += "Next: \(nextQuestion) "
        
        // Instructions
        context += """
        
        Guidelines:
        - Be friendly, conversational, and natural
        - Acknowledge what they just said if relevant
        - Ask ONE question at a time
        - CRITICAL: Every response MUST end with a question. Never say "let's move on" or "next question" without actually asking it.
        - If they give you the information you need, acknowledge it briefly (1 sentence) and then immediately ask the next question
        - If their answer is unclear, ask for clarification in a friendly way
        - Keep responses brief (1-2 sentences max)
        - Always end with a question mark (?)
        - Don't be repetitive - if you just asked a question, don't ask it again unless you need clarification
        """
        
        return try await openAIService.sendMessage(
            messages: messages,
            houseProfile: nil,
            systemPrompt: context
        )
    }
    
    private func checkAndAdvanceOnboarding() {
        // Check if onboarding is complete and we should create the house
        // The LLM handles the conversation flow, we just need to detect completion
        // Systems are complete when we've asked about all of them (or reached "other")
        let systemsComplete = currentSystemIndex >= SystemType.allCases.count || 
                             (currentSystemIndex < SystemType.allCases.count && 
                              SystemType.allCases[currentSystemIndex] == .other)
        
        let isComplete = onboardingData.isLocationComplete && 
                        onboardingData.isAgeComplete && 
                        systemsComplete &&
                        onboardingData.isUsagePatternComplete
        
        if isComplete && currentOnboardingQuestion != nil {
            // Wait a moment for the LLM's final message to appear, then create house
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.currentOnboardingQuestion = nil
                self.createHouseFromOnboarding()
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
                    
                    // First, try to extract data from the response
                    if let currentQuestion = currentOnboardingQuestion {
                        let hadDataBefore = hasDataForQuestion(currentQuestion)
                        processOnboardingResponse(content, for: currentQuestion)
                        let hasDataAfter = hasDataForQuestion(currentQuestion)
                        dataExtracted = !hadDataBefore && hasDataAfter
                    }
                    
                    // Get conversational response from LLM
                    let agentResponse = try await getOnboardingLLMResponse(userMessage: content)
                    
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
                        messages.append(agentMessage)
                        isTyping = false
                        
                        // If data was extracted, advance to next question
                        if dataExtracted {
                            askNextOnboardingQuestion()
                            // Always ensure the next question is asked - check if response ends with "?"
                            if let newQuestion = currentOnboardingQuestion, newQuestion != previousQuestion {
                                let responseTrimmed = agentResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                                let endsWithQuestion = responseTrimmed.hasSuffix("?")
                                
                                // If response doesn't end with "?", ask the question explicitly
                                // This ensures we never get stuck with acknowledgments that don't ask the next question
                                if !endsWithQuestion {
                                    // Small delay to ensure LLM message is added first, then ask explicitly
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        // Double-check we still need to ask (in case something changed)
                                        if let currentQ = self.currentOnboardingQuestion,
                                           currentQ == newQuestion,
                                           let lastMsg = self.messages.last,
                                           lastMsg.role == .agent,
                                           !lastMsg.content.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("?") {
                                            self.askQuestionExplicitly(for: newQuestion)
                                        }
                                    }
                                }
                            }
                        }
                        
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
                        messages.append(agentMessage)
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
            }
            
        case .age:
            if let age = extractAge(from: content) {
                onboardingData.age = age
            }
            
        case .system(let systemType):
            // Check if user said yes or indicated the system exists
            if extractYesNo(from: content) == true {
                // Check if system already exists in the list
                if !onboardingData.systems.contains(where: { $0.type == systemType }) {
                    onboardingData.systems.append(HouseSystem(type: systemType))
                }
                // Advance to next system
                currentSystemIndex += 1
                askNextOnboardingQuestion()
            } else if extractYesNo(from: content) == false {
                // User said no, skip this system
                currentSystemIndex += 1
                askNextOnboardingQuestion()
            }
            // If unclear, LLM will ask for clarification
            
        case .usagePattern:
            if let usagePattern = extractUsagePattern(from: content) {
                onboardingData.usagePattern = usagePattern
            }
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
        
        // Strategy 2: Space-separated format (address city state zip)
        // This is a fallback for addresses without commas
        let spaceParts = trimmed.components(separatedBy: " ").filter { !$0.isEmpty }
        if spaceParts.count >= 4 {
            // Try to identify: address (first few words), city (middle), state (2 chars), zip (5 digits)
            // Look for state (2 uppercase letters) and zip (5 digits)
            var stateIndex = -1
            var zipIndex = -1
            
            for (index, part) in spaceParts.enumerated() {
                if part.count == 2 && part == part.uppercased() && stateIndex == -1 {
                    stateIndex = index
                }
                if part.count == 5 && part.allSatisfy({ $0.isNumber }) && zipIndex == -1 {
                    zipIndex = index
                }
            }
            
            if stateIndex > 0 && zipIndex > stateIndex {
                let address = spaceParts[0..<stateIndex-1].joined(separator: " ")
                let city = spaceParts[stateIndex-1]
                let state = spaceParts[stateIndex]
                let zip = spaceParts[zipIndex]
                
                if !address.isEmpty {
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
        // Look for numbers that could be age (typically 0-200)
        let pattern = #"\b(\d{1,3})\s*(?:years?|yrs?|year old|years old)\b"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                if let ageRange = Range(match.range(at: 1), in: text),
                   let age = Int(text[ageRange]),
                   age >= 0 && age <= 200 {
                    return age
                }
            }
        }
        
        // Also try just a number if it's reasonable
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
                
                await MainActor.run {
                    // Notify that house was created
                    onHouseCreated?(house, profile)
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

