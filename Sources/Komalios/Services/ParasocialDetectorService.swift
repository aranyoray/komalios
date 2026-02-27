import Foundation
import os.log

// MARK: - Configuration Models

struct ParasocialSignalConfig: Codable {
    let version: String
    let categories: [SignalCategory]
}

struct SignalCategory: Codable {
    let id: String
    let weight: Double
    let phrases: [String]
}

// MARK: - Scan Result

struct ParasocialScanResult {
    let score: Double
    let riskLevel: ContentRiskLevel
    let triggeredSignals: [TriggeredSignal]
    let categoryScores: [String: Double]
}

struct TriggeredSignal {
    let categoryId: String
    let matchedPhrase: String
}

// MARK: - Report

struct ParasocialReport: Codable {
    let riskLevel: String
    let score: Double
    let triggeredSignals: [String]
    let recommendation: String

    enum CodingKeys: String, CodingKey {
        case riskLevel = "risk_level"
        case score
        case triggeredSignals = "triggered_signals"
        case recommendation
    }
}

// MARK: - Thresholds

struct ParasocialThresholds {
    var lowCeiling: Double = 0.30
    var mediumCeiling: Double = 0.60

    static let `default` = ParasocialThresholds()
}

// MARK: - Detector Service

final class ParasocialDetectorService {
    static let shared = ParasocialDetectorService()

    private static let logger = Logger(subsystem: "com.komalios", category: "ParasocialDetector")

    private let config: ParasocialSignalConfig
    private let thresholds: ParasocialThresholds

    // MARK: - Production init (loads from bundle)

    init(bundle: Bundle = .main, thresholds: ParasocialThresholds = .default) {
        self.thresholds = thresholds

        guard let url = bundle.url(forResource: "parasocial_signals", withExtension: "json") else {
            Self.logger.error("parasocial_signals.json not found in bundle — using empty config")
            self.config = ParasocialSignalConfig(version: "fallback", categories: [])
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(ParasocialSignalConfig.self, from: data)

            // Validate weights sum to ~1.0
            let weightSum = decoded.categories.reduce(0.0) { $0 + $1.weight }
            if abs(weightSum - 1.0) > 0.01 {
                Self.logger.warning("Category weights sum to \(weightSum, format: .fixed(precision: 3)), expected ~1.0")
            }

            self.config = decoded
            Self.logger.info("Loaded parasocial signals v\(decoded.version) with \(decoded.categories.count) categories")
        } catch {
            Self.logger.error("Failed to decode parasocial_signals.json: \(error.localizedDescription)")
            self.config = ParasocialSignalConfig(version: "fallback", categories: [])
        }
    }

    // MARK: - Test init (injected config)

    init(config: ParasocialSignalConfig, thresholds: ParasocialThresholds = .default) {
        self.config = config
        self.thresholds = thresholds
    }

    // MARK: - Scan
    //
    // Scoring algorithm:
    //   Per-category score = min(matchCount / 2.0, 1.0)
    //     → 1 phrase match = 0.5 (partial signal)
    //     → 2+ matches = 1.0 (full signal, reduces false positives from single benign phrases)
    //   Overall score = sum(categoryScore * categoryWeight), clamped to [0, 1]
    //   Risk mapping: 0=safe, (0, 0.30)=low, [0.30, 0.60)=medium, [0.60, 1.0]=high
    //   Only .high triggers filtering (requires signals across multiple weighted categories).

    func scan(_ text: String) -> ParasocialScanResult {
        let lowercased = text.lowercased()
        var triggeredSignals: [TriggeredSignal] = []
        var categoryScores: [String: Double] = [:]
        var overallScore: Double = 0.0

        for category in config.categories {
            var matchCount = 0
            for phrase in category.phrases {
                if lowercased.contains(phrase.lowercased()) {
                    matchCount += 1
                    triggeredSignals.append(TriggeredSignal(
                        categoryId: category.id,
                        matchedPhrase: phrase
                    ))
                }
            }

            let catScore = min(Double(matchCount) / 2.0, 1.0)
            categoryScores[category.id] = catScore
            overallScore += catScore * category.weight
        }

        let clampedScore = min(max(overallScore, 0.0), 1.0)

        let riskLevel: ContentRiskLevel
        if clampedScore == 0.0 {
            riskLevel = .safe
        } else if clampedScore < thresholds.lowCeiling {
            riskLevel = .low
        } else if clampedScore < thresholds.mediumCeiling {
            riskLevel = .medium
        } else {
            riskLevel = .high
        }

        let result = ParasocialScanResult(
            score: clampedScore,
            riskLevel: riskLevel,
            triggeredSignals: triggeredSignals,
            categoryScores: categoryScores
        )

        // Log blocked or flagged scans
        if riskLevel == .high {
            Self.logger.warning("Parasocial HIGH risk (score=\(clampedScore, format: .fixed(precision: 3))) — \(triggeredSignals.count) signals in categories: \(Set(triggeredSignals.map(\.categoryId)).sorted().joined(separator: ", "))")
        } else if riskLevel == .medium {
            Self.logger.info("Parasocial MEDIUM risk (score=\(clampedScore, format: .fixed(precision: 3))) — \(triggeredSignals.count) signals")
        }

        return result
    }

    // MARK: - Report

    func formatReport(score: Double, signals: [TriggeredSignal]) -> ParasocialReport {
        let riskLevel: String
        let recommendation: String

        if score < thresholds.lowCeiling {
            riskLevel = "low"
            recommendation = "pass"
        } else if score < thresholds.mediumCeiling {
            riskLevel = "medium"
            recommendation = "flag_for_review"
        } else {
            riskLevel = "high"
            recommendation = "block"
        }

        let uniqueCategories = Array(Set(signals.map(\.categoryId))).sorted()

        return ParasocialReport(
            riskLevel: riskLevel,
            score: score,
            triggeredSignals: uniqueCategories,
            recommendation: recommendation
        )
    }
}
