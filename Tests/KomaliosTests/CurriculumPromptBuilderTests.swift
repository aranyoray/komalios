import XCTest
@testable import Komalios

final class CurriculumPromptBuilderTests: XCTestCase {

    private let character = RikiCharacter.allCharacters[0] // Momo

    func testPromptIncludesSessionTheme() {
        let session = SELCurriculumLibrary.sessions[0]
        let step = session.steps[0]

        let prompt = CurriculumPromptBuilder.build(
            characterName: character.name,
            characterPersonality: character.personality,
            session: session,
            step: step,
            ageGroup: .tenToThirteen
        )

        XCTAssertTrue(prompt.contains(session.theme), "Prompt should include session theme")
    }

    func testPromptIncludesSocialCircle() {
        let session = SELCurriculumLibrary.sessions[0]
        let step = session.steps[0]

        let prompt = CurriculumPromptBuilder.build(
            characterName: character.name,
            characterPersonality: character.personality,
            session: session,
            step: step,
            ageGroup: .tenToThirteen
        )

        // closeFamily -> "close family"
        XCTAssertTrue(prompt.lowercased().contains("close"), "Prompt should include social circle")
    }

    func testPromptIncludesParticipationPrompt() {
        let session = SELCurriculumLibrary.sessions[0]
        let step = session.steps[0]

        let prompt = CurriculumPromptBuilder.build(
            characterName: character.name,
            characterPersonality: character.personality,
            session: session,
            step: step,
            ageGroup: .tenToThirteen
        )

        XCTAssertTrue(prompt.contains(step.participationPrompt), "Prompt should include participation prompt")
    }

    func testPromptIncludesCharacterName() {
        let session = SELCurriculumLibrary.sessions[0]
        let step = session.steps[0]

        let prompt = CurriculumPromptBuilder.build(
            characterName: character.name,
            characterPersonality: character.personality,
            session: session,
            step: step,
            ageGroup: .tenToThirteen
        )

        XCTAssertTrue(prompt.contains("Momo"), "Prompt should include character name")
    }

    func testPromptDoesNotIncludeAvatarDialogue() {
        let session = SELCurriculumLibrary.sessions[0]
        let step = session.steps[0]

        let prompt = CurriculumPromptBuilder.build(
            characterName: character.name,
            characterPersonality: character.personality,
            session: session,
            step: step,
            ageGroup: .tenToThirteen
        )

        // avatarDialogue is delivered via TTS, NOT included in the Gemini prompt
        XCTAssertFalse(prompt.contains(step.avatarDialogue), "Prompt should NOT include avatarDialogue (that's for TTS)")
    }

    func testPromptIncludesStayOnTopicGuardrail() {
        let session = SELCurriculumLibrary.sessions[0]
        let step = session.steps[0]

        let prompt = CurriculumPromptBuilder.build(
            characterName: character.name,
            characterPersonality: character.personality,
            session: session,
            step: step,
            ageGroup: .tenToThirteen
        )

        XCTAssertTrue(prompt.contains("Stay on this activity's topic"), "Prompt should include stay-on-topic guardrail")
    }
}
