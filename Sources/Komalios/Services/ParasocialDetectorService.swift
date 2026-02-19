import Foundation

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

// MARK: - Detector Service

final class ParasocialDetectorService {
    static let shared = ParasocialDetectorService()

    private let config: ParasocialSignalConfig

    // MARK: - Production init (loads from bundle)

    init(bundle: Bundle = .main) {
        if let url = bundle.url(forResource: "parasocial_signals", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(ParasocialSignalConfig.self, from: data) {
            self.config = decoded
        } else {
            self.config = ParasocialSignalConfig(version: "fallback", categories: [])
        }
    }

    // MARK: - Test init (injected config)

    init(config: ParasocialSignalConfig) {
        self.config = config
    }

    // MARK: - Scan

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

            let catScore = matchCount > 0 ? 1.0 : 0.0
            categoryScores[category.id] = catScore
            overallScore += catScore * category.weight
        }

        let clampedScore = min(max(overallScore, 0.0), 1.0)

        let riskLevel: ContentRiskLevel
        if clampedScore == 0.0 {
            riskLevel = .safe
        } else if clampedScore < 0.30 {
            riskLevel = .low
        } else if clampedScore < 0.60 {
            riskLevel = .medium
        } else {
            riskLevel = .high
        }

        return ParasocialScanResult(
            score: clampedScore,
            riskLevel: riskLevel,
            triggeredSignals: triggeredSignals,
            categoryScores: categoryScores
        )
    }

    // MARK: - Report

    func formatReport(score: Double, signals: [TriggeredSignal]) -> ParasocialReport {
        let riskLevel: String
        let recommendation: String

        if score < 0.30 {
            riskLevel = "low"
            recommendation = "pass"
        } else if score < 0.60 {
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
