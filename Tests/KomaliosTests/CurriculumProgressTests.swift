import XCTest
@testable import Komalios

final class CurriculumProgressTests: XCTestCase {

    func testInitialProgressIsEmpty() {
        let progress = SELCurriculumProgress()
        XCTAssertTrue(progress.completedSessionIds.isEmpty)
        XCTAssertNil(progress.currentSessionId)
        XCTAssertEqual(progress.currentStepIndex, 0)
        XCTAssertEqual(progress.nextSessionNumber, 1)
    }

    func testNextSessionNumberIncrementsAfterCompletion() {
        var progress = SELCurriculumProgress()
        progress.completedSessionIds.append("curriculum-s1")
        XCTAssertEqual(progress.nextSessionNumber, 2)

        progress.completedSessionIds.append("curriculum-s2")
        XCTAssertEqual(progress.nextSessionNumber, 3)
    }

    func testProgressPersistenceRoundTrip() throws {
        var progress = SELCurriculumProgress()
        progress.completedSessionIds = ["curriculum-s1", "curriculum-s2"]
        progress.currentSessionId = "curriculum-s3"
        progress.currentStepIndex = 2

        let data = try JSONEncoder().encode(progress)
        let decoded = try JSONDecoder().decode(SELCurriculumProgress.self, from: data)

        XCTAssertEqual(decoded.completedSessionIds, ["curriculum-s1", "curriculum-s2"])
        XCTAssertEqual(decoded.currentSessionId, "curriculum-s3")
        XCTAssertEqual(decoded.currentStepIndex, 2)
        XCTAssertEqual(decoded.nextSessionNumber, 3)
    }

    func testCompletedSessionIdsUpdatesAfterSessionFinish() {
        var progress = SELCurriculumProgress()
        progress.currentSessionId = "curriculum-s1"
        progress.currentStepIndex = 3

        // Simulate session completion
        progress.completedSessionIds.append("curriculum-s1")
        progress.currentSessionId = nil
        progress.currentStepIndex = 0

        XCTAssertEqual(progress.completedSessionIds, ["curriculum-s1"])
        XCTAssertNil(progress.currentSessionId)
        XCTAssertEqual(progress.nextSessionNumber, 2)
    }

    func testCurriculumLibraryHasFiveSessions() {
        XCTAssertEqual(SELCurriculumLibrary.sessions.count, 5)
    }

    func testSessionLookupByNumber() {
        for n in 1...5 {
            let session = SELCurriculumLibrary.session(forNumber: n)
            XCTAssertNotNil(session, "Session \(n) should exist")
            XCTAssertEqual(session?.sessionNumber, n)
        }
        XCTAssertNil(SELCurriculumLibrary.session(forNumber: 6), "Session 6 should not exist")
    }

    func testLocalizedDialogueIsNotEmpty() {
        // Verify that localized strings are actually populated (not just returning key)
        for session in SELCurriculumLibrary.sessions {
            XCTAssertFalse(session.theme.contains("curriculum."), "Theme should be localized, not a raw key: \(session.theme)")
            for step in session.steps {
                XCTAssertFalse(step.avatarDialogue.contains("curriculum."), "Dialogue should be localized, not a raw key: \(step.id)")
                XCTAssertFalse(step.participationPrompt.contains("curriculum."), "Prompt should be localized, not a raw key: \(step.id)")
                XCTAssertFalse(step.expectedKeywords.isEmpty, "Keywords should not be empty for step \(step.id)")
            }
        }
    }
}
