#if os(iOS)
import Foundation

/// Builds Gemini conversation context for curriculum voice sessions.
/// The avatar's scripted dialogue is delivered via TTS separately —
/// this prompt only guides Gemini's reaction to the child's speech.
struct CurriculumPromptBuilder {

    static func build(
        characterName: String,
        characterPersonality: String,
        session: SELCurriculumSession,
        step: SELCurriculumStep,
        ageGroup: AgeGroup
    ) -> String {
        let goals = step.targetGoals.joined(separator: ", ")
        let socialCircle = session.socialCircle.rawValue
            .replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
            .lowercased()

        return """
        SESSION MODE — \(characterName) is facilitating a structured activity.
        Session: "\(session.theme)" | Social Circle: \(socialCircle)
        The child was just asked: \(step.participationPrompt)
        Goals for this activity: \(goals)

        RULES:
        - React to what the child said. Be warm, encouraging, brief (1-2 sentences).
        - Use their words back to them ("You said you like dogs — that's awesome!").
        - Stay on this activity's topic. If off-topic, gently redirect.
        - Do NOT introduce the next activity or say "Great job, let's move on."
        - The app handles progression. You just respond to this one moment.
        - Keep vocabulary appropriate for a \(ageGroup.rawValue) year old.
        - Sound like a real friend talking, NOT like an AI assistant. Use filler words ("hmm", "ooh", "like"), be messy and warm. No polished corporate sentences.
        - NEVER say "That's a great answer!", "I appreciate you sharing", "Absolutely!", "What a wonderful response!". Just react naturally like a buddy would.
        """
    }
}
#endif
