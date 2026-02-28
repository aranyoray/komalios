#if os(iOS)
import SwiftUI

// MARK: - SEL Domain

enum SELDomain: String, Codable, CaseIterable {
    case socialCommunication
    case emotionalIntelligence
    case cognitiveDevelopment
    case lifeSkills
    case languageDevelopment

    var label: String {
        LanguageManager.localized(localizationKey)
    }

    var localizationKey: String {
        switch self {
        case .socialCommunication: return "sel.domain.social_communication"
        case .emotionalIntelligence: return "sel.domain.emotional_intelligence"
        case .cognitiveDevelopment: return "sel.domain.cognitive_development"
        case .lifeSkills: return "sel.domain.life_skills"
        case .languageDevelopment: return "sel.domain.language_development"
        }
    }

    var color: Color {
        switch self {
        case .socialCommunication: return Color(red: 0.51, green: 0.41, blue: 1.0)    // 3.81:1 on white
        case .emotionalIntelligence: return Color(red: 0.97, green: 0.34, blue: 0.49) // 3.11:1 on white
        case .cognitiveDevelopment: return Color(red: 0.78, green: 0.44, blue: 0.12)  // 3.57:1 on white (darkened)
        case .lifeSkills: return Color(red: 0.22, green: 0.58, blue: 0.54)            // 3.59:1 on white (darkened)
        case .languageDevelopment: return Color(red: 0.18, green: 0.55, blue: 0.52)   // 3.94:1 on white (darkened)
        }
    }

    var emoji: String {
        switch self {
        case .socialCommunication: return "🤝"
        case .emotionalIntelligence: return "💜"
        case .cognitiveDevelopment: return "🧠"
        case .lifeSkills: return "🌱"
        case .languageDevelopment: return "💬"
        }
    }

    var icon: String {
        switch self {
        case .socialCommunication: return "person.2.fill"
        case .emotionalIntelligence: return "heart.circle.fill"
        case .cognitiveDevelopment: return "brain.head.profile"
        case .lifeSkills: return "leaf.fill"
        case .languageDevelopment: return "text.bubble.fill"
        }
    }
}

// MARK: - SEL Option

struct SELOption: Codable, Equatable {
    let text: String
    let emoji: String
    let score: Int // 1=emerging, 2=developing, 3=proficient
}

// MARK: - SEL Check

struct SELCheck: Codable, Identifiable {
    let id: String
    let competency: String
    let question: String
    let options: [SELOption]
}

// MARK: - SEL Scenario

struct SELScenario: Codable, Identifiable {
    let id: String
    let domain: SELDomain
    let title: String
    let narrative: String
    let emoji: String
    let checks: [SELCheck] // always 3
}

// MARK: - SEL Check Result

struct SELCheckResult: Codable {
    let checkId: String
    let domain: SELDomain
    let competency: String
    let score: Int // 1-3
}

// MARK: - SEL Daily Record

struct SELDailyRecord: Codable, Identifiable {
    let id: String
    let date: String // yyyy-MM-dd
    let completedAt: String // ISO timestamp
    let domainScores: [SELDomain: Int] // 0-100
    let checkResults: [SELCheckResult]
    let mindfulnessCompleted: Bool
}

// MARK: - SEL Profile Summary

struct SELProfileSummary {
    let strengths: [SELDomain]
    let growthAreas: [SELDomain]
    let overallScore: Int // 0-100
    let trend: SELTrend
    let insight: String
}

enum SELTrend: String {
    case improving
    case stable
    case declining
}

// MARK: - Scoring Functions

func computeDomainScore(results: [SELCheckResult], domain: SELDomain) -> Int {
    let domainResults = results.filter { $0.domain == domain }
    guard !domainResults.isEmpty else { return 0 }
    let total = domainResults.reduce(0) { $0 + $1.score }
    let max = domainResults.count * 3
    return Int(round(Double(total) / Double(max) * 100))
}

func computeAllDomainScores(results: [SELCheckResult]) -> [SELDomain: Int] {
    var scores: [SELDomain: Int] = [:]
    for domain in SELDomain.allCases {
        scores[domain] = computeDomainScore(results: results, domain: domain)
    }
    return scores
}
#endif
