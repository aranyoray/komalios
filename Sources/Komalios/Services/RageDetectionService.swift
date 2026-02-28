#if os(iOS)
import Foundation
import Combine

/// Edge Case B: Child rage reaction detection and response.
/// Detects speech amplitude spikes, rapid tapping, fast scrolling.
/// Response: switch avatar tone to slower cadence, reduce verbosity,
/// introduce breathing mirroring.
@MainActor
final class RageDetectionService: ObservableObject {
    static let shared = RageDetectionService()

    @Published var isRageDetected = false
    @Published var rageLevel: RageLevel = .none

    enum RageLevel: Int, Comparable {
        case none = 0, mild = 1, moderate = 2, severe = 3
        static func < (lhs: RageLevel, rhs: RageLevel) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    // MARK: - Signal Tracking

    private var rapidTapTimestamps: [Date] = []
    private var rapidScrollTimestamps: [Date] = []
    private var amplitudeSpikes: [Date] = []
    private var cooldownTimer: Timer?

    /// Threshold: 5+ taps within 3 seconds = rage signal
    private let tapThreshold = 5
    private let tapWindow: TimeInterval = 3.0

    /// Threshold: 8+ rapid scrolls within 5 seconds
    private let scrollThreshold = 8
    private let scrollWindow: TimeInterval = 5.0

    /// Cooldown before rage state resets (30s of calm)
    private let rageCooldown: TimeInterval = 30.0

    private init() {}

    // MARK: - Signal Input

    /// Record a tap event (call from gesture recognizers)
    func recordTap() {
        let now = Date()
        rapidTapTimestamps.append(now)
        rapidTapTimestamps = rapidTapTimestamps.filter { now.timeIntervalSince($0) < tapWindow }

        if rapidTapTimestamps.count >= tapThreshold {
            escalateRage(signal: "rapid_taps")
        }
    }

    /// Record rapid scrolling (call from scroll tracking)
    func recordRapidScroll() {
        let now = Date()
        rapidScrollTimestamps.append(now)
        rapidScrollTimestamps = rapidScrollTimestamps.filter { now.timeIntervalSince($0) < scrollWindow }

        if rapidScrollTimestamps.count >= scrollThreshold {
            escalateRage(signal: "fast_scrolling")
        }
    }

    /// Record speech amplitude spike (call from speech recognizer)
    func recordAmplitudeSpike() {
        let now = Date()
        amplitudeSpikes.append(now)
        amplitudeSpikes = amplitudeSpikes.filter { now.timeIntervalSince($0) < 10.0 }

        if amplitudeSpikes.count >= 2 {
            escalateRage(signal: "amplitude_spike")
        }
    }

    // MARK: - Rage State Management

    private func escalateRage(signal: String) {
        let newLevel: RageLevel
        switch rageLevel {
        case .none: newLevel = .mild
        case .mild: newLevel = .moderate
        case .moderate, .severe: newLevel = .severe
        }

        if newLevel > rageLevel {
            rageLevel = newLevel
            isRageDetected = true
            resetCooldown()
        }
    }

    private func resetCooldown() {
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: rageCooldown, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.deescalate()
            }
        }
    }

    private func deescalate() {
        switch rageLevel {
        case .severe: rageLevel = .moderate
        case .moderate: rageLevel = .mild
        case .mild:
            rageLevel = .none
            isRageDetected = false
        case .none: break
        }

        if rageLevel != .none {
            resetCooldown()
        }
    }

    /// Reset all rage signals (e.g., when child leaves the chat)
    func reset() {
        cooldownTimer?.invalidate()
        cooldownTimer = nil
        rapidTapTimestamps.removeAll()
        rapidScrollTimestamps.removeAll()
        amplitudeSpikes.removeAll()
        rageLevel = .none
        isRageDetected = false
    }

    // MARK: - Context Modification for AI

    /// Returns a system context note to inject into the AI prompt
    /// when rage is detected, instructing slower cadence and breathing mirroring.
    var rageContextNote: String? {
        switch rageLevel {
        case .none:
            return nil
        case .mild:
            return "[SYSTEM NOTE: The child seems a bit agitated. Use slightly shorter sentences. Speak gently. Acknowledge their energy before redirecting.]"
        case .moderate:
            return "[SYSTEM NOTE: The child is showing signs of frustration. Switch to a calmer, slower tone. Use very short sentences (5-8 words). Introduce a quick grounding moment: 'Hey... take a breath with me for a sec.' Mirror their breathing in your rhythm — start a bit fast, then slow down.]"
        case .severe:
            return "[SYSTEM NOTE: The child appears very upset. Use the SLOWEST cadence possible. Maximum 1-2 short sentences. Lead with empathy: 'I hear you. That sounds really hard.' Then introduce breathing mirroring: 'Let's breathe together... in... and out...' Do NOT ask questions. Just hold space and be calm.]"
        }
    }
}
#endif
