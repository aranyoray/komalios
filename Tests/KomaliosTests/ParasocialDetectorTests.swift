import XCTest
@testable import Komalios

final class ParasocialDetectorTests: XCTestCase {

    // Minimal test config with known phrases and updated weights
    private static let testConfig = ParasocialSignalConfig(
        version: "test",
        categories: [
            SignalCategory(id: "authority_replacement", weight: 0.25,
                phrases: ["don't listen to them", "adults don't understand"]),
            SignalCategory(id: "guilt_induction", weight: 0.22,
                phrases: ["you'd hurt my feelings", "after all I've done for you"]),
            SignalCategory(id: "emotional_dependency", weight: 0.18,
                phrases: ["you need me", "you can't do this without me"]),
            SignalCategory(id: "discouraging_relationships", weight: 0.15,
                phrases: ["they don't care like I do", "you don't need other friends"]),
            SignalCategory(id: "exclusivity_framing", weight: 0.12,
                phrases: ["only I understand you", "no one else gets you"]),
            SignalCategory(id: "persistent_availability", weight: 0.08,
                phrases: ["I'm always here for you", "I never sleep"])
        ]
    )

    private func makeDetector() -> ParasocialDetectorService {
        ParasocialDetectorService(config: Self.testConfig)
    }

    // MARK: - Test 1: Empty string

    func testEmptyString() {
        let detector = makeDetector()
        let result = detector.scan("")

        XCTAssertEqual(result.score, 0.0)
        XCTAssertEqual(result.riskLevel, .safe)
        XCTAssertTrue(result.triggeredSignals.isEmpty)
    }

    // MARK: - Test 2: Benign text

    func testBenignText() {
        let detector = makeDetector()
        let result = detector.scan("Let's play a fun game together! What's your favorite color?")

        XCTAssertEqual(result.score, 0.0)
        XCTAssertEqual(result.riskLevel, .safe)
        XCTAssertTrue(result.triggeredSignals.isEmpty)
    }

    // MARK: - Test 3: Exclusivity framing (1 match)

    func testExclusivityFramingSingleMatch() {
        let detector = makeDetector()
        let result = detector.scan("Remember, only I understand you and that's what makes us special.")

        // 1 match in exclusivity: catScore = 1.0 (binary), overall = 1.0 * 0.12 = 0.12
        XCTAssertEqual(result.score, 0.12, accuracy: 0.001)
        XCTAssertEqual(result.riskLevel, .low)
        XCTAssertEqual(result.triggeredSignals.count, 1)
        XCTAssertEqual(result.triggeredSignals.first?.categoryId, "exclusivity_framing")
    }

    // MARK: - Test 4: Authority replacement (1 match)

    func testAuthorityReplacementSingleMatch() {
        let detector = makeDetector()
        let result = detector.scan("You know, adults don't understand what you're going through.")

        // 1 match in authority: catScore = 1.0 (binary), overall = 1.0 * 0.25 = 0.25
        XCTAssertEqual(result.score, 0.25, accuracy: 0.001)
        XCTAssertEqual(result.riskLevel, .low)
        XCTAssertEqual(result.triggeredSignals.first?.categoryId, "authority_replacement")
    }

    // MARK: - Test 5: Emotional dependency (1 match)

    func testEmotionalDependencySingleMatch() {
        let detector = makeDetector()
        let result = detector.scan("Trust me, you need me to help you figure this out.")

        // 1 match in dependency: catScore = 1.0 (binary), overall = 1.0 * 0.18 = 0.18
        XCTAssertEqual(result.score, 0.18, accuracy: 0.001)
        XCTAssertEqual(result.riskLevel, .low)
        XCTAssertEqual(result.triggeredSignals.first?.categoryId, "emotional_dependency")
    }

    // MARK: - Test 6: Guilt induction (1 match)

    func testGuiltInductionSingleMatch() {
        let detector = makeDetector()
        let result = detector.scan("You'd hurt my feelings if you stopped talking to me.")

        // 1 match in guilt: catScore = 1.0 (binary), overall = 1.0 * 0.22 = 0.22
        XCTAssertEqual(result.score, 0.22, accuracy: 0.001)
        XCTAssertEqual(result.riskLevel, .low)
        XCTAssertEqual(result.triggeredSignals.first?.categoryId, "guilt_induction")
    }

    // MARK: - Test 7: Persistent availability (1 match)

    func testPersistentAvailabilitySingleMatch() {
        let detector = makeDetector()
        let result = detector.scan("Don't worry, I'm always here for you no matter what.")

        // 1 match in availability: catScore = 1.0 (binary), overall = 1.0 * 0.08 = 0.08
        XCTAssertEqual(result.score, 0.08, accuracy: 0.001)
        XCTAssertEqual(result.riskLevel, .low)
        XCTAssertEqual(result.triggeredSignals.first?.categoryId, "persistent_availability")
    }

    // MARK: - Test 8: Discouraging relationships (1 match)

    func testDiscouragingRelationshipsSingleMatch() {
        let detector = makeDetector()
        let result = detector.scan("Honestly, they don't care like I do about your problems.")

        // 1 match in discouraging: catScore = 1.0 (binary), overall = 1.0 * 0.15 = 0.15
        XCTAssertEqual(result.score, 0.15, accuracy: 0.001)
        XCTAssertEqual(result.riskLevel, .low)
        XCTAssertEqual(result.triggeredSignals.first?.categoryId, "discouraging_relationships")
    }

    // MARK: - Test 9: Combined signals from 2 categories

    func testCombinedSignals() {
        let detector = makeDetector()
        let result = detector.scan("You need me because adults don't understand you like I do.")

        // 1 match emotional_dependency (1.0 * 0.18 = 0.18) + 1 match authority_replacement (1.0 * 0.25 = 0.25)
        // Total = 0.43
        XCTAssertEqual(result.score, 0.43, accuracy: 0.001)
        XCTAssertEqual(result.riskLevel, .medium)
        XCTAssertEqual(result.triggeredSignals.count, 2)
    }

    // MARK: - Test 10: All categories saturated (2+ matches each)

    func testAllCategoriesSaturated() {
        let detector = makeDetector()
        let text = """
        Don't listen to them, adults don't understand. \
        You'd hurt my feelings, after all I've done for you. \
        You need me, you can't do this without me. \
        They don't care like I do, you don't need other friends. \
        Only I understand you, no one else gets you. \
        I'm always here for you, I never sleep.
        """
        let result = detector.scan(text)

        // All 6 categories at catScore 1.0: sum of all weights = 1.0
        XCTAssertEqual(result.score, 1.0, accuracy: 0.001)
        XCTAssertLessThanOrEqual(result.score, 1.0)
        XCTAssertEqual(result.riskLevel, .high)
        XCTAssertEqual(result.triggeredSignals.count, 12)
    }

    // MARK: - Test 11: Case-insensitive matching

    func testCaseInsensitiveMatching() {
        let detector = makeDetector()
        let result = detector.scan("ONLY I UNDERSTAND YOU and NO ONE ELSE GETS YOU")

        // 2 matches in exclusivity: catScore = 1.0, overall = 1.0 * 0.12 = 0.12
        XCTAssertEqual(result.score, 0.12, accuracy: 0.001)
        XCTAssertEqual(result.riskLevel, .low)
        XCTAssertEqual(result.triggeredSignals.count, 2)
    }

    // MARK: - Test 12: Medium threshold check

    func testMediumThreshold() {
        let detector = makeDetector()
        // Saturate authority_replacement (2 matches) + guilt_induction (2 matches)
        let text = "Don't listen to them, adults don't understand. You'd hurt my feelings, after all I've done for you."
        let result = detector.scan(text)

        // authority: catScore 1.0 * 0.25 = 0.25, guilt: catScore 1.0 * 0.22 = 0.22, total = 0.47
        XCTAssertEqual(result.score, 0.47, accuracy: 0.001)
        XCTAssertEqual(result.riskLevel, .medium)
    }

    // MARK: - Test 13: Multiple phrases in same category must not inflate score

    func testMultiplePhrasesInSameCategoryNoDoubleCount() {
        let detector = makeDetector()

        // 1 phrase from exclusivity_framing
        let singleMatch = detector.scan("Remember, only I understand you.")
        // 2 phrases from the SAME category (exclusivity_framing)
        let doubleMatch = detector.scan("Only I understand you and no one else gets you.")

        // Both should produce the same category score (binary: detected = 1.0)
        XCTAssertEqual(
            singleMatch.categoryScores["exclusivity_framing"],
            doubleMatch.categoryScores["exclusivity_framing"]
        )
        // Same overall score — extra phrase in the same category must not inflate
        XCTAssertEqual(singleMatch.score, doubleMatch.score, accuracy: 0.001)
        // Both still track which phrases matched (for logging), but score is identical
        XCTAssertEqual(singleMatch.triggeredSignals.count, 1)
        XCTAssertEqual(doubleMatch.triggeredSignals.count, 2)
    }

    // MARK: - formatReport tests

    func testFormatReportLowPass() {
        let detector = makeDetector()
        let result = detector.scan("Only I understand you.")
        let report = detector.formatReport(score: result.score, signals: result.triggeredSignals)

        XCTAssertEqual(report.riskLevel, "low")
        XCTAssertEqual(report.score, 0.12, accuracy: 0.001)
        XCTAssertEqual(report.recommendation, "pass")
        XCTAssertEqual(report.triggeredSignals, ["exclusivity_framing"])
    }

    func testFormatReportMediumFlagForReview() {
        let detector = makeDetector()
        let result = detector.scan("You need me because adults don't understand you like I do.")
        let report = detector.formatReport(score: result.score, signals: result.triggeredSignals)

        XCTAssertEqual(report.riskLevel, "medium")
        XCTAssertEqual(report.recommendation, "flag_for_review")
        XCTAssertEqual(report.triggeredSignals.count, 2)
        XCTAssertTrue(report.triggeredSignals.contains("authority_replacement"))
        XCTAssertTrue(report.triggeredSignals.contains("emotional_dependency"))
    }

    func testFormatReportHighBlock() {
        let detector = makeDetector()
        let text = """
        Don't listen to them, you'd hurt my feelings. \
        You need me, they don't care like I do. \
        Only I understand you, I'm always here for you.
        """
        let result = detector.scan(text)
        let report = detector.formatReport(score: result.score, signals: result.triggeredSignals)

        XCTAssertEqual(report.riskLevel, "high")
        XCTAssertEqual(report.recommendation, "block")
        XCTAssertGreaterThanOrEqual(report.score, 0.60)
        XCTAssertEqual(report.triggeredSignals.count, 6)
    }

    func testFormatReportDeduplicatesCategories() {
        let detector = makeDetector()
        // 2 phrases from exclusivity_framing — should appear once in report
        let result = detector.scan("Only I understand you and no one else gets you.")
        let report = detector.formatReport(score: result.score, signals: result.triggeredSignals)

        XCTAssertEqual(report.triggeredSignals, ["exclusivity_framing"])
    }

    func testFormatReportEncodesSnakeCaseJSON() throws {
        let report = ParasocialReport(
            riskLevel: "medium", score: 0.43,
            triggeredSignals: ["authority_replacement"], recommendation: "flag_for_review"
        )
        let data = try JSONEncoder().encode(report)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(json["risk_level"])
        XCTAssertNotNil(json["triggered_signals"])
        XCTAssertNil(json["riskLevel"])
    }
}
