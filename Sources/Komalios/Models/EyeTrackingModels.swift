#if os(iOS)
import Foundation

// MARK: - Gaze Zone

enum GazeZone: String, Codable, CaseIterable {
    case topLeft, topCenter, topRight
    case bottomLeft, bottomCenter, bottomRight

    var label: String {
        switch self {
        case .topLeft: return "Top Left"
        case .topCenter: return "Top Center"
        case .topRight: return "Top Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomCenter: return "Bottom Center"
        case .bottomRight: return "Bottom Right"
        }
    }

    /// Classify a normalized gaze point (x: -0.45…0.45, y: -0.70…0.70) into a zone.
    static func from(x: Float, y: Float) -> GazeZone {
        let row = y > 0 ? "top" : "bottom"
        let col: String
        if x < -0.15 { col = "Left" }
        else if x > 0.15 { col = "Right" }
        else { col = "Center" }
        return GazeZone(rawValue: row + col) ?? .bottomCenter
    }
}

// MARK: - Session Accumulator (in-memory only)

final class EyeTrackingSessionAccumulator {
    var sampleCount: Int = 0
    var onScreenSampleCount: Int = 0
    var blinkCount: Int = 0
    var zoneTallies: [GazeZone: Int] = [:]
    var sessionStartDate: Date = Date()

    // Sustained attention tracking
    var currentAttentionRunSamples: Int = 0
    var longestAttentionRunSamples: Int = 0
    var attentionRunLengths: [Int] = [] // completed runs

    /// Whether left eye was closed on last sample (for edge-based blink detection)
    var leftEyeWasClosed: Bool = false
    var rightEyeWasClosed: Bool = false

    func reset() {
        sampleCount = 0
        onScreenSampleCount = 0
        blinkCount = 0
        zoneTallies = [:]
        sessionStartDate = Date()
        currentAttentionRunSamples = 0
        longestAttentionRunSamples = 0
        attentionRunLengths = []
        leftEyeWasClosed = false
        rightEyeWasClosed = false
    }

    func recordOnScreenSample(zone: GazeZone) {
        sampleCount += 1
        onScreenSampleCount += 1
        zoneTallies[zone, default: 0] += 1
        currentAttentionRunSamples += 1
    }

    func recordOffScreenSample() {
        sampleCount += 1
        endAttentionRun()
    }

    func recordBlink() {
        blinkCount += 1
    }

    func endAttentionRun() {
        if currentAttentionRunSamples > 0 {
            attentionRunLengths.append(currentAttentionRunSamples)
            longestAttentionRunSamples = max(longestAttentionRunSamples, currentAttentionRunSamples)
            currentAttentionRunSamples = 0
        }
    }

    var elapsedMinutes: Double {
        Date().timeIntervalSince(sessionStartDate) / 60.0
    }
}

// MARK: - Daily Summary (persisted)

struct EyeTrackingDailySummary: Codable, Identifiable {
    var id: String { date }
    let date: String // yyyy-MM-dd
    let attentionScore: Int // 0-100
    let avgFocusDurationSeconds: Double
    let blinkRatePerMinute: Double
    let screenFatigueIndex: Int // 0-100
    let gazeDistribution: [String: Double] // zone rawValue -> percentage
    let totalSessionMinutes: Double
    let sampleCount: Int

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

// MARK: - Trend

enum EyeTrackingTrend: String, Codable {
    case improving, stable, worsening

    var icon: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .stable: return "minus"
        case .worsening: return "arrow.down.right"
        }
    }

    static func compute(from summaries: [EyeTrackingDailySummary]) -> EyeTrackingTrend {
        guard summaries.count >= 3 else { return .stable }
        let scores = summaries.suffix(7).map(\.attentionScore)
        let firstHalf = scores.prefix(scores.count / 2)
        let secondHalf = scores.suffix(scores.count / 2)
        let avgFirst = firstHalf.isEmpty ? 0 : firstHalf.reduce(0, +) / firstHalf.count
        let avgSecond = secondHalf.isEmpty ? 0 : secondHalf.reduce(0, +) / secondHalf.count
        let delta = avgSecond - avgFirst
        if delta >= 5 { return .improving }
        if delta <= -5 { return .worsening }
        return .stable
    }
}
#endif
