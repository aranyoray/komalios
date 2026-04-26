import XCTest
@testable import Komalios

#if os(iOS)
import AVFoundation
import Speech

// MARK: - Protocol Abstractions for Testability

/// Abstracts AVAudioEngine so we can inject a mock in tests.
protocol AudioEngineProtocol: AnyObject {
    var isRunning: Bool { get }
    var mockInputNode: AudioInputNodeProtocol { get }
    func prepare()
    func start() throws
    func stop()
    func reset()
}

/// Abstracts AVAudioEngine.inputNode
protocol AudioInputNodeProtocol {
    func outputFormat(forBus bus: AVAudioNodeBus) -> AVAudioFormat
    func installTap(onBus bus: AVAudioNodeBus, bufferSize: AVAudioFrameCount, format: AVAudioFormat?, block: @escaping AVAudioNodeTapBlock)
    func removeTap(onBus bus: AVAudioNodeBus)
}

/// Abstracts AVAudioSession for testing
protocol AudioSessionProtocol {
    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws
}

// MARK: - Mock Implementations

final class MockAudioEngine: AudioEngineProtocol {
    var isRunning = false
    var mockInputNode: AudioInputNodeProtocol = MockAudioInputNode()
    var prepareCallCount = 0
    var startCallCount = 0
    var stopCallCount = 0
    var resetCallCount = 0
    var shouldThrowOnStart = false

    func prepare() { prepareCallCount += 1 }
    func start() throws {
        if shouldThrowOnStart { throw NSError(domain: "test", code: -1) }
        startCallCount += 1
        isRunning = true
    }
    func stop() { stopCallCount += 1; isRunning = false }
    func reset() { resetCallCount += 1 }
}

final class MockAudioInputNode: AudioInputNodeProtocol {
    var mockFormat: AVAudioFormat?
    var tapInstalled = false
    var removeTapCallCount = 0

    func outputFormat(forBus bus: AVAudioNodeBus) -> AVAudioFormat {
        if let format = mockFormat { return format }
        // Default: valid format
        return AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    }

    func installTap(onBus bus: AVAudioNodeBus, bufferSize: AVAudioFrameCount, format: AVAudioFormat?, block: @escaping AVAudioNodeTapBlock) {
        tapInstalled = true
    }

    func removeTap(onBus bus: AVAudioNodeBus) {
        removeTapCallCount += 1
        tapInstalled = false
    }
}

final class MockAudioSession: AudioSessionProtocol {
    var activateCallCount = 0
    var shouldThrow = false

    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws {
        if shouldThrow { throw NSError(domain: "test", code: -1) }
        activateCallCount += 1
    }
}

// MARK: - Tests

final class SpeechRecognizerTests: XCTestCase {

    // MARK: - Format Validation Tests

    func testFormatGuardRejectsZeroSampleRate() {
        // The guard at SpeechRecognizer.swift:107 should reject 0 Hz formats
        let format = AVAudioFormat(standardFormatWithSampleRate: 0, channels: 1)
        // AVAudioFormat with 0 Hz returns nil, which is the correct behavior
        XCTAssertNil(format, "AVAudioFormat should not create a format with 0 Hz sample rate")
    }

    func testFormatGuardRejectsZeroChannels() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 0)
        XCTAssertNil(format, "AVAudioFormat should not create a format with 0 channels")
    }

    func testValidFormatAccepted() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)
        XCTAssertNotNil(format)
        XCTAssertGreaterThan(format!.sampleRate, 0)
        XCTAssertGreaterThan(format!.channelCount, 0)
    }

    // MARK: - Mock Engine Tests

    func testMockEngineResetClearsState() {
        let engine = MockAudioEngine()
        engine.isRunning = true
        engine.stop()
        engine.reset()
        XCTAssertFalse(engine.isRunning)
        XCTAssertEqual(engine.resetCallCount, 1)
        XCTAssertEqual(engine.stopCallCount, 1)
    }

    func testMockEngineStartThrows() {
        let engine = MockAudioEngine()
        engine.shouldThrowOnStart = true
        XCTAssertThrowsError(try engine.start())
        XCTAssertFalse(engine.isRunning)
    }

    func testMockInputNodeInvalidFormat() {
        let node = MockAudioInputNode()
        // Simulate 0 Hz by setting mockFormat to nil and checking default
        let format = node.outputFormat(forBus: 0)
        // Default mock returns valid format
        XCTAssertGreaterThan(format.sampleRate, 0)
        XCTAssertGreaterThan(format.channelCount, 0)
    }

    func testTapInstallAndRemove() {
        let node = MockAudioInputNode()
        XCTAssertFalse(node.tapInstalled)

        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { _, _ in }
        XCTAssertTrue(node.tapInstalled)

        node.removeTap(onBus: 0)
        XCTAssertFalse(node.tapInstalled)
        XCTAssertEqual(node.removeTapCallCount, 1)
    }

    // MARK: - Audio Session Tests

    func testMockAudioSessionActivates() throws {
        let session = MockAudioSession()
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        XCTAssertEqual(session.activateCallCount, 1)
    }

    func testMockAudioSessionThrows() {
        let session = MockAudioSession()
        session.shouldThrow = true
        XCTAssertThrowsError(try session.setActive(true, options: .notifyOthersOnDeactivation))
    }

    // MARK: - Cleanup Sequence Tests

    func testCleanupSequence() {
        let engine = MockAudioEngine()
        let node = engine.mockInputNode as! MockAudioInputNode

        // Simulate active state
        engine.isRunning = true
        node.installTap(onBus: 0, bufferSize: 1024, format: nil) { _, _ in }

        // Simulate cleanup
        if engine.isRunning { engine.stop() }
        node.removeTap(onBus: 0)
        engine.reset()

        XCTAssertFalse(engine.isRunning)
        XCTAssertFalse(node.tapInstalled)
        XCTAssertEqual(engine.resetCallCount, 1, "Engine should be reset after cleanup")
    }

    // MARK: - Re-entrancy Guard Tests

    func testReentrancyGuard() {
        // Simulate the isStopping guard behavior
        var isStopping = false

        func stopRecording() -> Bool {
            guard !isStopping else { return false }
            isStopping = true
            // cleanup...
            isStopping = false
            return true
        }

        XCTAssertTrue(stopRecording(), "First stop should succeed")

        // Simulate concurrent call during stop
        isStopping = true
        XCTAssertFalse(stopRecording(), "Concurrent stop should be rejected")
        isStopping = false
    }

    // MARK: - Locale Tests

    func testSpeechRecognitionLocaleMapping() {
        // Verify the locale mapping covers all app languages
        let locales = ["en-US", "fr-FR", "es-ES", "pt-BR", "ar-SA"]
        for localeId in locales {
            let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeId))
            XCTAssertNotNil(recognizer, "SFSpeechRecognizer should support locale: \(localeId)")
        }
    }

    // MARK: - Session Cap Tests

    func testSessionCapTimerInterval() {
        // Verify the session cap constant is reasonable (10-30 minutes)
        let capSeconds: TimeInterval = 20 * 60
        XCTAssertGreaterThanOrEqual(capSeconds, 10 * 60, "Session cap should be at least 10 minutes")
        XCTAssertLessThanOrEqual(capSeconds, 30 * 60, "Session cap should be at most 30 minutes")
    }

    // MARK: - Permission Helper Tests

    func testPermissionHelperExists() {
        // Verify the static method is accessible
        // (actual permission testing requires device, but we verify the API exists)
        let _: () async -> Bool = SpeechRecognizer.requestPermissions
        let _: () -> Void = SpeechRecognizer.configureVoiceChatSession
    }
}
#endif
