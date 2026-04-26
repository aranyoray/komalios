import XCTest
@testable import Komalios

final class CurriculumScoringTests: XCTestCase {

    // MARK: - Score Calculation Tests

    func testSilentStepScoresOne() {
        // Empty response = score 1 (silent/auto-advanced)
        let step = SELCurriculumLibrary.sessions[0].steps[0]
        let score = Self.scoreStep(response: "", step: step)
        XCTAssertEqual(score, 1, "Silent step should score 1")
    }

    func testVerbalResponseWithoutKeywordScoresTwo() {
        let step = SELCurriculumLibrary.sessions[0].steps[0]
        // Response that doesn't match any expectedKeywords
        let score = Self.scoreStep(response: "I think the weather is nice today", step: step)
        XCTAssertEqual(score, 2, "Verbal response without keyword match should score 2")
    }

    func testResponseWithKeywordScoresThree() {
        let step = SELCurriculumLibrary.sessions[0].steps[0]
        // "like" is an expectedKeyword for s1-1
        let score = Self.scoreStep(response: "I like playing soccer with my friends", step: step)
        XCTAssertEqual(score, 3, "Response with keyword match should score 3")
    }

    func testKeywordMatchIsCaseInsensitive() {
        let step = SELCurriculumLibrary.sessions[0].steps[0]
        let score = Self.scoreStep(response: "I LOVE reading books", step: step)
        XCTAssertEqual(score, 3, "Keyword match should be case insensitive")
    }

    // MARK: - Fan-out Tests

    func testOneSELCheckResultPerDomain() {
        // Step s1-1 has targetDomains: [.socialCommunication, .languageDevelopment]
        let step = SELCurriculumLibrary.sessions[0].steps[0]
        let stepResult = (stepId: step.id, score: 3, domains: step.targetDomains, competency: step.targetGoals[0])

        var checkResults: [SELCheckResult] = []
        for domain in stepResult.domains {
            checkResults.append(SELCheckResult(
                checkId: stepResult.stepId,
                domain: domain,
                competency: stepResult.competency,
                score: stepResult.score
            ))
        }

        XCTAssertEqual(checkResults.count, step.targetDomains.count, "Should have one SELCheckResult per domain")
        XCTAssertEqual(checkResults[0].domain, .socialCommunication)
        XCTAssertEqual(checkResults[1].domain, .languageDevelopment)
    }

    func testCompetencyIsFirstTargetGoal() {
        let step = SELCurriculumLibrary.sessions[0].steps[0]
        XCTAssertEqual(step.targetGoals[0], "Basic conversation skills")
    }

    // MARK: - Scoring Helper (mirrors CurriculumSessionView.scoreCurrentStep)

    private static func scoreStep(response: String, step: SELCurriculumStep) -> Int {
        let lowered = response.lowercased()
        if lowered.isEmpty { return 1 }

        for keyword in step.expectedKeywords {
            if lowered.contains(keyword.lowercased()) {
                return 3
            }
        }
        return 2
    }
}
