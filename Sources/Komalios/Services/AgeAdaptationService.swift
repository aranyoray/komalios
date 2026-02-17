#if os(iOS)
import Foundation

// MARK: - Age-Adapted Content Configuration

struct AgeAdaptedContent {
    let promptTone: String
    let maxResponseLength: Int
    let reflectionDepthMax: Int
    let identityProgressionSpeed: Double // multiplier: 1.0 = normal, 1.5 = faster, 0.75 = slower
    let sessionLengthMinutes: Int
    let promptFrequencyMultiplier: Double // 1.0 = normal, higher = more frequent

    static let under10 = AgeAdaptedContent(
        promptTone: "playful, simple, encouraging, uses short sentences",
        maxResponseLength: 200,
        reflectionDepthMax: 1,
        identityProgressionSpeed: 1.5,
        sessionLengthMinutes: 10,
        promptFrequencyMultiplier: 1.3
    )

    static let tenToThirteen = AgeAdaptedContent(
        promptTone: "friendly, curious, supportive, conversational",
        maxResponseLength: 300,
        reflectionDepthMax: 2,
        identityProgressionSpeed: 1.0,
        sessionLengthMinutes: 15,
        promptFrequencyMultiplier: 1.0
    )

    static let thirteenToSixteen = AgeAdaptedContent(
        promptTone: "respectful, thoughtful, engaging, slightly more mature",
        maxResponseLength: 400,
        reflectionDepthMax: 2,
        identityProgressionSpeed: 0.85,
        sessionLengthMinutes: 15,
        promptFrequencyMultiplier: 0.8
    )

    static let sixteenToEighteen = AgeAdaptedContent(
        promptTone: "mature, reflective, intellectually stimulating",
        maxResponseLength: 500,
        reflectionDepthMax: 3,
        identityProgressionSpeed: 0.75,
        sessionLengthMinutes: 20,
        promptFrequencyMultiplier: 0.7
    )

    static let eighteenPlus = AgeAdaptedContent(
        promptTone: "adult, reflective, analytical",
        maxResponseLength: 500,
        reflectionDepthMax: 3,
        identityProgressionSpeed: 0.75,
        sessionLengthMinutes: 20,
        promptFrequencyMultiplier: 0.6
    )
}

// MARK: - Age Adaptation Service

final class AgeAdaptationService {
    static let shared = AgeAdaptationService()

    private init() {}

    /// Get age-adapted content configuration for the given age group
    func getContent(for ageGroup: AgeGroup) -> AgeAdaptedContent {
        switch ageGroup {
        case .under10:
            return .under10
        case .tenToThirteen:
            return .tenToThirteen
        case .thirteenToSixteen:
            return .thirteenToSixteen
        case .sixteenToEighteen:
            return .sixteenToEighteen
        case .eighteenPlus:
            return .eighteenPlus
        }
    }

    /// Get the prompt tone string for AI system prompts
    func getPromptTone(for ageGroup: AgeGroup) -> String {
        getContent(for: ageGroup).promptTone
    }

    /// Get max response length for AI generation
    func getMaxResponseLength(for ageGroup: AgeGroup) -> Int {
        getContent(for: ageGroup).maxResponseLength
    }

    /// Get max reflection follow-up depth
    func getReflectionDepthMax(for ageGroup: AgeGroup) -> Int {
        getContent(for: ageGroup).reflectionDepthMax
    }

    /// Get identity progression speed multiplier
    func getProgressionSpeed(for ageGroup: AgeGroup) -> Double {
        getContent(for: ageGroup).identityProgressionSpeed
    }

    /// Get recommended session length in minutes
    func getSessionLength(for ageGroup: AgeGroup) -> Int {
        getContent(for: ageGroup).sessionLengthMinutes
    }

    /// Get prompt frequency multiplier (higher = show more prompts)
    func getPromptFrequency(for ageGroup: AgeGroup) -> Double {
        getContent(for: ageGroup).promptFrequencyMultiplier
    }
}
#endif
