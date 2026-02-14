// KomalWebAPI.swift
// API client for Komalweb backend (Flask endpoints)

import Foundation

actor KomalWebAPI {
    
    // MARK: - Configuration
    
    // Change this to your deployed backend URL or use localhost for testing
    private let baseURL: String
    
    init(baseURL: String = "http://localhost:5000") {
        self.baseURL = baseURL
    }
    
    // MARK: - Models
    
    struct FilterRequest: Codable {
        let text: String
        let age_group: String
        let domain: String?
        let has_media: Bool
    }
    
    struct FilterResponse: Codable {
        let action: String  // "ALLOW", "GATE", "BLOCK"
        let categories: [String]
        let confidence: Double
        let reason: String
        let details: ResponseDetails?
        
        struct ResponseDetails: Codable {
            let major_categories: [String: Double]
            let subcategories: [String: Double]?
            let needs_vision: Bool
            let processing_time_ms: Double
        }
    }
    
    struct ChatRequest: Codable {
        let message: String
        let conversation_id: String?
    }
    
    struct ChatResponse: Codable {
        let response: String
        let conversation_id: String
        let safety_check: SafetyCheck?
        
        struct SafetyCheck: Codable {
            let is_safe: Bool
            let filtered_content: Bool
            let reason: String?
        }
    }
    
    // MARK: - API Methods
    
    /// Analyze content safety using the /api/filter endpoint
    func analyzeContent(_ text: String, ageGroup: String, domain: String? = nil) async throws -> FilterResponse {
        let endpoint = "\(baseURL)/api/filter"
        
        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = FilterRequest(
            text: text,
            age_group: ageGroup,
            domain: domain,
            has_media: false
        )
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(FilterResponse.self, from: data)
    }
    
    /// Send message to chatbot using /api/chat endpoint
    func sendChatMessage(_ message: String, conversationId: String? = nil) async throws -> ChatResponse {
        let endpoint = "\(baseURL)/api/chat"
        
        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ChatRequest(
            message: message,
            conversation_id: conversationId
        )
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(ChatResponse.self, from: data)
    }
    
    /// Health check
    func healthCheck() async throws -> Bool {
        let endpoint = "\(baseURL)/api/health"
        
        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }
        
        let (_, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        
        return httpResponse.statusCode == 200
    }
    
    // MARK: - Error Handling
    
    enum APIError: LocalizedError {
        case invalidURL
        case invalidResponse
        case serverError(Int)
        case decodingError
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid API URL"
            case .invalidResponse:
                return "Invalid server response"
            case .serverError(let code):
                return "Server error: \(code)"
            case .decodingError:
                return "Failed to decode response"
            }
        }
    }
}
