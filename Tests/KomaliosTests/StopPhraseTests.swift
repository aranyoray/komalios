import XCTest

final class StopPhraseTests: XCTestCase {

    private let stopPhrases = ["shut up", "stop talking", "be quiet", "leave me alone",
                               "go away", "i don't want to talk", "stop it", "just stop"]

    private func containsStopPhrase(_ transcript: String) -> Bool {
        let lower = transcript.lowercased()
        return stopPhrases.contains(where: { lower.contains($0) })
    }

    func testShutUpDetected() {
        XCTAssertTrue(containsStopPhrase("shut up momo"))
    }

    func testStopTalkingDetected() {
        XCTAssertTrue(containsStopPhrase("stop talking please"))
    }

    func testLeaveMeAloneDetected() {
        XCTAssertTrue(containsStopPhrase("leave me alone"))
    }

    func testBusStopNotDetected() {
        XCTAssertFalse(containsStopPhrase("I told a story about a bus stop"))
    }

    func testBeQuietDetected() {
        XCTAssertTrue(containsStopPhrase("be quiet"))
    }

    func testEmptyNotDetected() {
        XCTAssertFalse(containsStopPhrase(""))
    }

    func testUppercaseDetected() {
        XCTAssertTrue(containsStopPhrase("SHUT UP"))
    }
}
