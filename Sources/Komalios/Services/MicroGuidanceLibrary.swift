#if os(iOS)
import Foundation

// MARK: - Micro-Guidance Technique (v2 §8)

struct MicroGuidanceTechnique: Codable, Identifiable {
    let id: String
    let name: String
    let ageRange: [AgeGroup]
    /// Dysregulation band this technique targets (0-1)
    let dysregulationMin: Double
    let dysregulationMax: Double
    let durationSeconds: Int
    let modality: Modality
    /// Hint injected into the Gemini system prompt when this technique is active
    let systemPromptHint: String

    enum Modality: String, Codable {
        case verbal, somatic, cognitive, social
    }
}

// MARK: - Technique Library

struct MicroGuidanceLibrary {
    static let techniques: [MicroGuidanceTechnique] = [
        MicroGuidanceTechnique(
            id: "urge_naming",
            name: "Urge Naming",
            ageRange: [.tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            dysregulationMin: 0.3, dysregulationMax: 0.7,
            durationSeconds: 30,
            modality: .verbal,
            systemPromptHint: "Help the child name the urge they're feeling. Ask: 'If that feeling had a name, what would you call it?' Don't label it for them."
        ),
        MicroGuidanceTechnique(
            id: "meta_cognition",
            name: "Meta-Cognition",
            ageRange: [.thirteenToSixteen, .sixteenToEighteen],
            dysregulationMin: 0.3, dysregulationMax: 0.8,
            durationSeconds: 45,
            modality: .cognitive,
            systemPromptHint: "Invite the child to notice their own thinking: 'What's your brain doing right now? Is it helping or making things harder?' Keep it curious, not clinical."
        ),
        MicroGuidanceTechnique(
            id: "somatic_grounding",
            name: "Somatic Grounding",
            ageRange: [.under10, .tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            dysregulationMin: 0.5, dysregulationMax: 1.0,
            durationSeconds: 30,
            modality: .somatic,
            systemPromptHint: "Use somatic grounding: invite the child to notice their feet on the floor, the feeling of the seat, or their hands. 'What do your hands feel like right now?' Keep it gentle."
        ),
        MicroGuidanceTechnique(
            id: "co_regulation_mirroring",
            name: "Co-Regulation Mirroring",
            ageRange: [.under10, .tenToThirteen],
            dysregulationMin: 0.5, dysregulationMax: 1.0,
            durationSeconds: 30,
            modality: .social,
            systemPromptHint: "Mirror the child's energy then slowly bring it down. Match their pace first, then use shorter, calmer sentences. Model the calm you want them to feel."
        ),
        MicroGuidanceTechnique(
            id: "value_anchoring",
            name: "Value Anchoring",
            ageRange: [.thirteenToSixteen, .sixteenToEighteen],
            dysregulationMin: 0.2, dysregulationMax: 0.6,
            durationSeconds: 45,
            modality: .cognitive,
            systemPromptHint: "Help the child connect to what matters to them: 'What kind of person do you want to be in this moment?' Don't moralize — just ask."
        ),
        MicroGuidanceTechnique(
            id: "cognitive_defusion",
            name: "Cognitive Defusion",
            ageRange: [.thirteenToSixteen, .sixteenToEighteen],
            dysregulationMin: 0.4, dysregulationMax: 0.8,
            durationSeconds: 30,
            modality: .cognitive,
            systemPromptHint: "Help the child see the thought as just a thought: 'What if you said to yourself: I notice I'm having the thought that...' Keep it playful."
        ),
        MicroGuidanceTechnique(
            id: "time_dilation",
            name: "Time Dilation",
            ageRange: [.tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            dysregulationMin: 0.4, dysregulationMax: 0.8,
            durationSeconds: 20,
            modality: .cognitive,
            systemPromptHint: "Slow the moment down: 'Let's take this one step at a time. What's the very next thing?' Help them zoom into the present instead of spiraling."
        ),
        MicroGuidanceTechnique(
            id: "externalization",
            name: "Externalization",
            ageRange: [.under10, .tenToThirteen],
            dysregulationMin: 0.3, dysregulationMax: 0.7,
            durationSeconds: 30,
            modality: .verbal,
            systemPromptHint: "Help the child externalize the feeling: 'If that worry was a creature, what would it look like? What color is it?' Make it playful and curious."
        ),
        MicroGuidanceTechnique(
            id: "breathing_redirect",
            name: "Breathing Redirect",
            ageRange: [.under10, .tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            dysregulationMin: 0.6, dysregulationMax: 1.0,
            durationSeconds: 20,
            modality: .somatic,
            systemPromptHint: "Gently redirect to breathing: 'Hey, let's try something — breathe in for 4, hold for 4, out for 4. I'll do it with you.' Don't lecture about why — just do it together."
        ),
        MicroGuidanceTechnique(
            id: "curiosity_channeling",
            name: "Curiosity Channeling",
            ageRange: [.under10, .tenToThirteen, .thirteenToSixteen],
            dysregulationMin: 0.2, dysregulationMax: 0.5,
            durationSeconds: 30,
            modality: .cognitive,
            systemPromptHint: "Channel the child's energy into curiosity: 'That's interesting — why do you think that happens?' Redirect intensity toward wonder."
        ),
        MicroGuidanceTechnique(
            id: "perspective_taking",
            name: "Perspective Taking",
            ageRange: [.tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            dysregulationMin: 0.2, dysregulationMax: 0.6,
            durationSeconds: 45,
            modality: .social,
            systemPromptHint: "Gently invite perspective: 'How do you think they felt about that?' or 'What would your best friend say if they saw this?' Don't force empathy — invite it."
        ),
        MicroGuidanceTechnique(
            id: "emotion_labeling",
            name: "Emotion Labeling",
            ageRange: [.under10, .tenToThirteen],
            dysregulationMin: 0.3, dysregulationMax: 0.7,
            durationSeconds: 20,
            modality: .verbal,
            systemPromptHint: "Help the child name what they feel: 'Sounds like you might be feeling... frustrated? Sad? Something else?' Offer options but let them choose. Naming it helps tame it."
        ),
    ]

    /// Select the best technique for the current context.
    /// Returns nil if no technique matches or all are fatigued.
    static func selectTechnique(
        for intent: IntentVector,
        ageGroup: AgeGroup,
        fatigue: inout TechniqueFatigueTracker
    ) -> MicroGuidanceTechnique? {
        let dysreg = intent.dysregulationProbability

        // Filter to techniques that match age, dysregulation band, and aren't fatigued
        let candidates = techniques.filter { tech in
            tech.ageRange.contains(ageGroup) &&
            dysreg >= tech.dysregulationMin &&
            dysreg <= tech.dysregulationMax &&
            fatigue.canUse(tech.id)
        }

        guard !candidates.isEmpty else { return nil }

        // Pick the least-used from candidates
        if let bestId = fatigue.leastUsed(from: candidates.map { $0.id }),
           let best = candidates.first(where: { $0.id == bestId }) {
            fatigue.recordUsage(best.id)
            return best
        }

        return candidates.first
    }
}
#endif
