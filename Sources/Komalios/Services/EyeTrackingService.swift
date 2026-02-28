#if os(iOS)
import Foundation
import ARKit
import Combine
import os.log

@MainActor
final class EyeTrackingService: NSObject, ObservableObject {
    static let shared = EyeTrackingService()

    static var isSupported: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return ARFaceTrackingConfiguration.isSupported
        #endif
    }

    // MARK: - Published State

    @Published var isTracking = false
    @Published var permissionDenied = false

    // MARK: - Private

    private let logger = Logger(subsystem: "com.komalkids.komal", category: "EyeTracking")
    private var arSession: ARSession?
    private var samplingTimer: Timer?
    private var latestFaceAnchor: ARFaceAnchor?
    private let accumulator = EyeTrackingSessionAccumulator()

    private static let samplingInterval: TimeInterval = 0.5 // 2 Hz
    private static let blinkThreshold: Float = 0.8
    private static let onScreenXThreshold: Float = 0.45
    private static let onScreenYThreshold: Float = 0.70

    private static let storageFileName = "eye_tracking_summaries.json"

    private override init() {
        super.init()
    }

    // MARK: - Lifecycle

    func startTracking() {
        guard Self.isSupported else {
            logger.warning("Face tracking not supported on this device")
            return
        }
        guard !isTracking else { return }

        #if targetEnvironment(simulator)
        beginSimulatedSession()
        #else
        // Check camera permission
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            beginARSession()
        case .notDetermined:
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                if granted {
                    beginARSession()
                } else {
                    permissionDenied = true
                    logger.info("Camera permission denied by user")
                }
            }
        default:
            permissionDenied = true
            logger.info("Camera permission not available")
        }
        #endif
    }

    func stopTracking() {
        guard isTracking else { return }
        samplingTimer?.invalidate()
        samplingTimer = nil
        #if !targetEnvironment(simulator)
        arSession?.pause()
        arSession = nil
        #endif
        isTracking = false
        accumulator.endAttentionRun()
        logger.info("Eye tracking stopped (samples=\(self.accumulator.sampleCount))")
    }

    // MARK: - AR Session (device only)

    #if !targetEnvironment(simulator)
    private func beginARSession() {
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = false

        let session = ARSession()
        session.delegate = self
        session.run(config, options: [.resetTracking])
        arSession = session
        isTracking = true

        accumulator.reset()

        // 2 Hz sampling timer
        samplingTimer = Timer.scheduledTimer(withTimeInterval: Self.samplingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sampleGaze()
            }
        }

        logger.info("Eye tracking started")
    }
    #endif

    // MARK: - Simulator Mock Session

    #if targetEnvironment(simulator)
    private func beginSimulatedSession() {
        isTracking = true
        accumulator.reset()
        logger.info("Eye tracking started (simulator — synthetic data)")

        // Generate synthetic samples via timer
        samplingTimer = Timer.scheduledTimer(withTimeInterval: Self.samplingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sampleSimulatedGaze()
            }
        }
    }

    private func sampleSimulatedGaze() {
        // 85% chance on-screen, 15% off-screen
        let isOnScreen = Double.random(in: 0...1) < 0.85

        if isOnScreen {
            // Random gaze within on-screen bounds with center bias
            let x = Float.random(in: -0.40...0.40)
            let y = Float.random(in: -0.60...0.60)
            let zone = GazeZone.from(x: x, y: y)
            accumulator.recordOnScreenSample(zone: zone)
        } else {
            accumulator.recordOffScreenSample()
        }

        // ~15 blinks per minute → at 2Hz that's ~0.125 chance per sample
        if Double.random(in: 0...1) < 0.125 {
            accumulator.recordBlink()
        }
    }
    #endif

    // MARK: - Sampling (device only)

    #if !targetEnvironment(simulator)
    private func sampleGaze() {
        guard let anchor = latestFaceAnchor else { return }

        let lookAt = anchor.lookAtPoint // simd_float3, face-relative
        let x = lookAt.x
        let y = lookAt.y

        // On-screen detection
        let isOnScreen = abs(x) < Self.onScreenXThreshold && abs(y) < Self.onScreenYThreshold

        if isOnScreen {
            let zone = GazeZone.from(x: x, y: y)
            accumulator.recordOnScreenSample(zone: zone)
        } else {
            accumulator.recordOffScreenSample()
        }

        // Blink detection (edge-based: detect transition from open to closed)
        let blendShapes = anchor.blendShapes
        let leftBlink = (blendShapes[.eyeBlinkLeft]?.floatValue ?? 0)
        let rightBlink = (blendShapes[.eyeBlinkRight]?.floatValue ?? 0)

        let leftClosed = leftBlink > Self.blinkThreshold
        let rightClosed = rightBlink > Self.blinkThreshold

        // Count a blink on the closing edge of either eye
        let leftJustClosed = leftClosed && !accumulator.leftEyeWasClosed
        let rightJustClosed = rightClosed && !accumulator.rightEyeWasClosed
        if leftJustClosed || rightJustClosed {
            accumulator.recordBlink()
        }
        accumulator.leftEyeWasClosed = leftClosed
        accumulator.rightEyeWasClosed = rightClosed
    }
    #endif

    // MARK: - Daily Summary Aggregation

    func commitDailySummary() {
        guard accumulator.sampleCount > 0 else { return }
        accumulator.endAttentionRun()

        let totalSamples = accumulator.sampleCount
        let onScreenSamples = accumulator.onScreenSampleCount
        let elapsedMinutes = max(accumulator.elapsedMinutes, 0.1)

        // Attention score: percentage of on-screen samples
        let attentionScore = min(100, Int((Double(onScreenSamples) / Double(totalSamples)) * 100))

        // Average focus duration: mean of attention run lengths (each sample = 0.5s)
        let allRuns = accumulator.attentionRunLengths
        let avgRunSamples = allRuns.isEmpty ? 0.0 : Double(allRuns.reduce(0, +)) / Double(allRuns.count)
        let avgFocusDuration = avgRunSamples * Self.samplingInterval

        // Blink rate per minute
        let blinkRate = elapsedMinutes > 0 ? Double(accumulator.blinkCount) / elapsedMinutes : 0

        // Gaze distribution
        var gazeDistribution: [String: Double] = [:]
        let totalZoneSamples = accumulator.zoneTallies.values.reduce(0, +)
        if totalZoneSamples > 0 {
            for zone in GazeZone.allCases {
                let count = accumulator.zoneTallies[zone] ?? 0
                gazeDistribution[zone.rawValue] = Double(count) / Double(totalZoneSamples) * 100.0
            }
        }

        // Fatigue index (0-100): weighted combination
        let highBlinkFactor = min(1.0, max(0, blinkRate - 15) / 20.0) // ramps from 15-35 bpm
        let lowAttentionFactor = 1.0 - (Double(attentionScore) / 100.0)
        let shortFocusFactor = max(0, 1.0 - avgFocusDuration / 30.0) // ramps below 30s
        let fatigueIndex = min(100, Int((highBlinkFactor * 40 + lowAttentionFactor * 35 + shortFocusFactor * 25)))

        let today = EyeTrackingDailySummary.dateFormatter.string(from: Date())

        let summary = EyeTrackingDailySummary(
            date: today,
            attentionScore: attentionScore,
            avgFocusDurationSeconds: avgFocusDuration,
            blinkRatePerMinute: blinkRate,
            screenFatigueIndex: fatigueIndex,
            gazeDistribution: gazeDistribution,
            totalSessionMinutes: elapsedMinutes,
            sampleCount: totalSamples
        )

        // Merge with existing today summary if any
        var summaries = loadSummaries()
        if let idx = summaries.firstIndex(where: { $0.date == today }) {
            let existing = summaries[idx]
            // Weighted merge of today's sessions
            let totalWeight = existing.sampleCount + summary.sampleCount
            guard totalWeight > 0 else { return }
            let w1 = Double(existing.sampleCount) / Double(totalWeight)
            let w2 = Double(summary.sampleCount) / Double(totalWeight)

            let merged = EyeTrackingDailySummary(
                date: today,
                attentionScore: Int(Double(existing.attentionScore) * w1 + Double(summary.attentionScore) * w2),
                avgFocusDurationSeconds: existing.avgFocusDurationSeconds * w1 + summary.avgFocusDurationSeconds * w2,
                blinkRatePerMinute: existing.blinkRatePerMinute * w1 + summary.blinkRatePerMinute * w2,
                screenFatigueIndex: Int(Double(existing.screenFatigueIndex) * w1 + Double(summary.screenFatigueIndex) * w2),
                gazeDistribution: mergeDistributions(existing.gazeDistribution, summary.gazeDistribution, w1: w1, w2: w2),
                totalSessionMinutes: existing.totalSessionMinutes + summary.totalSessionMinutes,
                sampleCount: totalWeight
            )
            summaries[idx] = merged
        } else {
            summaries.append(summary)
        }

        // Keep last 90 days
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let cutoffStr = EyeTrackingDailySummary.dateFormatter.string(from: cutoff)
        summaries = summaries.filter { $0.date >= cutoffStr }

        saveSummaries(summaries)
        accumulator.reset()
        logger.info("Committed daily eye tracking summary for \(today)")
    }

    // MARK: - Data Access

    func getSummaries(days: Int) -> [EyeTrackingDailySummary] {
        let all = loadSummaries()
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let cutoffStr = EyeTrackingDailySummary.dateFormatter.string(from: cutoff)
        return all.filter { $0.date >= cutoffStr }.sorted { $0.date < $1.date }
    }

    func getTodaySummary() -> EyeTrackingDailySummary? {
        let today = EyeTrackingDailySummary.dateFormatter.string(from: Date())
        return loadSummaries().first { $0.date == today }
    }

    /// Seed 7 days of mock summaries for simulator UI testing.
    func seedMockData() {
        var summaries = loadSummaries()
        let cal = Calendar.current
        for dayOffset in (1...7).reversed() {
            guard let date = cal.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let dateStr = EyeTrackingDailySummary.dateFormatter.string(from: date)
            guard !summaries.contains(where: { $0.date == dateStr }) else { continue }

            let attention = Int.random(in: 55...92)
            let focusDur = Double.random(in: 8...25)
            let blink = Double.random(in: 10...22)
            let fatigue = Int.random(in: 15...55)
            var gaze: [String: Double] = [:]
            let zones = GazeZone.allCases
            var remaining = 100.0
            for (i, zone) in zones.enumerated() {
                if i == zones.count - 1 {
                    gaze[zone.rawValue] = max(0, remaining)
                } else {
                    let pct = Double.random(in: 5...30)
                    gaze[zone.rawValue] = pct
                    remaining -= pct
                }
            }

            summaries.append(EyeTrackingDailySummary(
                date: dateStr,
                attentionScore: attention,
                avgFocusDurationSeconds: focusDur,
                blinkRatePerMinute: blink,
                screenFatigueIndex: fatigue,
                gazeDistribution: gaze,
                totalSessionMinutes: Double.random(in: 5...30),
                sampleCount: Int.random(in: 200...800)
            ))
        }
        saveSummaries(summaries.sorted { $0.date < $1.date })
        logger.info("Seeded mock eye tracking data for simulator")
    }

    // MARK: - COPPA Delete

    func deleteAllData() {
        let url = storageURL()
        try? FileManager.default.removeItem(at: url)
        accumulator.reset()
        logger.info("All eye tracking data deleted")
    }

    // MARK: - Persistence (on-device JSON with file protection)

    private lazy var cachedStorageURL: URL = {
        guard let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            // Fallback to temporary directory if Application Support is unavailable
            return FileManager.default.temporaryDirectory.appendingPathComponent(Self.storageFileName)
        }
        let dir = appSupportDir.appendingPathComponent("EyeTracking", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(Self.storageFileName)
    }()

    private func storageURL() -> URL {
        cachedStorageURL
    }

    private func loadSummaries() -> [EyeTrackingDailySummary] {
        let url = storageURL()
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([EyeTrackingDailySummary].self, from: data)) ?? []
    }

    private func saveSummaries(_ summaries: [EyeTrackingDailySummary]) {
        let url = storageURL()
        guard let data = try? JSONEncoder().encode(summaries) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    private func mergeDistributions(
        _ a: [String: Double],
        _ b: [String: Double],
        w1: Double,
        w2: Double
    ) -> [String: Double] {
        var result: [String: Double] = [:]
        let allKeys = Set(a.keys).union(b.keys)
        for key in allKeys {
            result[key] = (a[key] ?? 0) * w1 + (b[key] ?? 0) * w2
        }
        return result
    }
}

// MARK: - ARSessionDelegate (device only)

#if !targetEnvironment(simulator)
extension EyeTrackingService: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let faceAnchor = anchors.compactMap({ $0 as? ARFaceAnchor }).first else { return }
        Task { @MainActor in
            self.latestFaceAnchor = faceAnchor
        }
    }

    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor in
            self.logger.info("AR session interrupted")
        }
    }

    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor in
            self.logger.info("AR session interruption ended")
            if self.isTracking, let arSession = self.arSession {
                let config = ARFaceTrackingConfiguration()
                config.isLightEstimationEnabled = false
                arSession.run(config, options: [.resetTracking])
            }
        }
    }
}
#endif
#endif
