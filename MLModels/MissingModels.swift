//
//  MissingModels.swift
//  Komalios
//
//  Missing model definitions causing build errors
//

import Foundation

// MARK: - Age Group for Child Profile

enum ChildAgeGroup: String, Codable {
    case under10 = "under10"
    case tenToThirteen = "10-13"
    case thirteenToSixteen = "13-16"
    case sixteenToEighteen = "16-18"
}

// MARK: - Child Profile

struct ChildProfile: Codable, Identifiable {
    let id: UUID
    var name: String
    var ageGroup: ChildAgeGroup
    var avatar: String?
    var createdAt: Date
    
    init(id: UUID = UUID(), name: String, ageGroup: ChildAgeGroup, avatar: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.ageGroup = ageGroup
        self.avatar = avatar
        self.createdAt = createdAt
    }
    
    static var sample: ChildProfile {
        ChildProfile(name: "Sample Child", ageGroup: .tenToThirteen)
    }
}

// MARK: - Parent Settings

struct ParentSettings: Codable {
    var blockedDomains: [String]
    var allowedDomains: [String]
    var customBlockedKeywords: [String]
    var reflectionTimeEnabled: Bool
    var reflectionTimeIntervalMinutes: Int
    var notificationsEnabled: Bool
    
    init(
        blockedDomains: [String] = [],
        allowedDomains: [String] = [],
        customBlockedKeywords: [String] = [],
        reflectionTimeEnabled: Bool = true,
        reflectionTimeIntervalMinutes: Int = 30,
        notificationsEnabled: Bool = true
    ) {
        self.blockedDomains = blockedDomains
        self.allowedDomains = allowedDomains
        self.customBlockedKeywords = customBlockedKeywords
        self.reflectionTimeEnabled = reflectionTimeEnabled
        self.reflectionTimeIntervalMinutes = reflectionTimeIntervalMinutes
        self.notificationsEnabled = notificationsEnabled
    }
    
    static var sample: ParentSettings {
        ParentSettings()
    }
}

// MARK: - Account Mode

enum AccountMode: String, Codable {
    case child
    case parent
    case guest
}

// MARK: - Content Filter Preferences

struct ContentFilterPreferences: Codable {
    var strictnessLevel: StrictnessLevel
    var enabledCategories: Set<String>
    
    init(strictnessLevel: StrictnessLevel = .moderate, enabledCategories: Set<String> = []) {
        self.strictnessLevel = strictnessLevel
        self.enabledCategories = enabledCategories
    }
}

enum StrictnessLevel: String, Codable {
    case lenient
    case moderate
    case strict
}

// MARK: - Komal Web API (Stub)

struct KomalWebAPI {
    let baseURL: String
    
    init(baseURL: String) {
        self.baseURL = baseURL
    }
    
    func sendChatMessage(_ message: String, conversationId: String?) async throws -> ChatResponse {
        // TODO: Implement actual API call
        // For now, return a mock response
        return ChatResponse(
            response: "This is a mock response. Please implement the actual API call.",
            conversation_id: conversationId ?? UUID().uuidString,
            safety_check: nil
        )
    }
}

struct ChatResponse: Codable {
    let response: String
    let conversation_id: String
    let safety_check: SafetyCheck?
}

struct SafetyCheck: Codable {
    let filtered_content: Bool
    let reason: String?
}
