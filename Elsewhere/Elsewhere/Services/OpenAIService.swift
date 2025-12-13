//
//  OpenAIService.swift
//  Elsewhere
//
//  Created on 12/12/25.
//

import Foundation

@MainActor
class OpenAIService {
    static let shared = OpenAIService()
    
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    private init() {
        // TODO: Load from environment or config file
        // For now, this should be set via Info.plist or environment variable
        self.apiKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String ?? ""
        
        if apiKey.isEmpty {
            print("⚠️ WARNING: OpenAI API key not found. Set OPENAI_API_KEY in Info.plist")
        }
    }
    
    func sendMessage(
        messages: [ChatMessage],
        houseProfile: HouseProfile?,
        systemPrompt: String? = nil,
        temperature: Double = 0.7
    ) async throws -> String {
        guard !apiKey.isEmpty else {
            throw OpenAIError.apiKeyMissing
        }
        
        // Build system prompt
        let defaultSystemPrompt: String
        if houseProfile != nil {
            defaultSystemPrompt = """
            You are Upstate Home Copilot, an AI assistant that helps owners manage their second homes.
            
            Your role:
            - Assist, suggest, draft, and remember
            - Never pretend to be a contractor or property manager
            - Reference what you know about the house explicitly
            - Be comfortable with partial knowledge and uncertainty
            - Stay calm and timely, not urgent by default
            - Know when to stay quiet
            
            House Context:
            \(houseProfileContext(houseProfile))
            
            Guidelines:
            - Ask questions to learn about the house when relevant
            - Suggest tasks based on house profile and systems
            - Recommend vendor categories based on house needs
            - Reference specific house details in your responses
            - Offer to help complete tasks or coordinate vendors
            - Be concise and actionable
            """
        } else {
            defaultSystemPrompt = """
            You are Upstate Home Copilot, an AI assistant that helps owners manage their second homes.
            
            Your role:
            - Assist, suggest, draft, and remember
            - Never pretend to be a contractor or property manager
            - Be friendly and conversational
            - Ask one question at a time
            """
        }
        
        let finalSystemPrompt = systemPrompt ?? defaultSystemPrompt
        
        // Convert messages to OpenAI format
        var openAIMessages: [[String: Any]] = [
            ["role": "system", "content": finalSystemPrompt]
        ]
        
        for message in messages {
            openAIMessages.append([
                "role": message.role.rawValue,
                "content": message.content
            ])
        }
        
        // Prepare request
        let requestBody: [String: Any] = [
            "model": "gpt-4", // Can be changed to gpt-3.5-turbo for cost savings
            "messages": openAIMessages,
            "temperature": temperature,
            "stream": false
        ]
        
        guard let url = URL(string: baseURL) else {
            throw OpenAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OpenAIError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.invalidResponse
        }
        
        return content
    }
    
    private func houseProfileContext(_ profile: HouseProfile?) -> String {
        guard let profile = profile else {
            return "No house profile available yet. Ask the user questions to learn about their house."
        }
        
        var context = "House Profile:\n"
        
        if let location = profile.location {
            context += "- Location: \(location.address), \(location.city), \(location.state) \(location.zipCode)\n"
        }
        
        if let age = profile.age {
            context += "- Age: \(age) years\n"
        }
        
        if !profile.systems.isEmpty {
            context += "- Systems: \(profile.systems.map { $0.type.rawValue }.joined(separator: ", "))\n"
        }
        
        if let usagePattern = profile.usagePattern {
            if let frequency = usagePattern.occupancyFrequency {
                context += "- Usage: \(frequency.rawValue), Seasonal: \(usagePattern.seasonalUsage)\n"
            } else {
                context += "- Usage: Not specified, Seasonal: \(usagePattern.seasonalUsage)\n"
            }
        }
        
        if !profile.riskFactors.isEmpty {
            context += "- Risk Factors: \(profile.riskFactors.map { "\($0.type.rawValue) (\($0.severity.rawValue))" }.joined(separator: ", "))\n"
        }
        
        return context.isEmpty ? "House profile is being built." : context
    }
}

enum OpenAIError: LocalizedError {
    case apiKeyMissing
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "OpenAI API key is missing. Please configure it in Info.plist."
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from OpenAI API"
        case .apiError(let statusCode, let message):
            return "OpenAI API error (\(statusCode)): \(message)"
        }
    }
}

