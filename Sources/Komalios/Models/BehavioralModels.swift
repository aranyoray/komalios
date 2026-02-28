//
//  BehavioralModels.swift
//  Komalios
//
//  Komal v2 — Behavioral state models per architecture spec sections 2-3.
//  IntentVector, ChildStateGraph, and AvatarTrustScore for longitudinal
//  state modeling, intent inference, and avatar trust degradation.
//

#if os(iOS)
import Foundation

// MARK: - Intent Inference Engine (Layer 2)

/// Real-time intent vector computed on-device from multimodal signals.
/// Must resolve in <300ms. No cloud inference for raw signals.
struct IntentVector: Codable {
    /// Curiosity level inferred from search patterns, browsing depth (0–1)
    var curiosityLevel: Double = 0

    /// Emotional arousal from speech prosody, typing patterns (0–1)
    var emotionalArousal: Double = 0

    /// Probability of emotional dysregulation (0–1)
    var dysregulationProbability: Double = 0

    /// Parasocial attachment risk score (0–1)
    var parasocialAttachmentScore: Double = 0

    /// Suggestive content risk from recent browsing (0–1)
    var suggestiveContentRisk: Double = 0

    /// Polarizing content risk from recent browsing (0–1)
    var polarizingContentRisk: Double = 0

    /// Compulsive loop score — rapid tab switching, repeated searches (0–1)
    var compulsiveLoopScore: Double = 0

    /// Fatigue level from session duration, time of day (0–1)
    var fatigueLevel: Double = 0

    /// Timestamp of last computation
    var lastUpdated: Date = Date()

    /// Overall risk level derived from vector components
    var overallRisk: RiskLevel {
        let maxRisk = max(dysregulationProbability, suggestiveContentRisk, polarizingContentRisk)
        if maxRisk >= 0.8 { return .severe }
        if maxRisk >= 0.5 { return .moderate }
        return .low
    }

    enum RiskLevel: String, Codable {
        case low, moderate, severe
    }
}

// MARK: - Longitudinal State Model (Layer 3)

/// Dynamic per-child state graph. Edges weighted by recent history,
/// decay factor applied weekly, no static rules.
struct ChildStateGraph: Codable {
    var developmentalDomains: DevelopmentalDomains = DevelopmentalDomains()
    var riskTrajectories: [RiskTrajectoryPoint] = []
    var triggerPatterns: [TriggerPattern] = []
    var recoveryLatency: TimeInterval = 0
    var avatarTrustScore: AvatarTrustScore = AvatarTrustScore()
    var lastDecayDate: String?
}

/// Developmental domain scores (0–1 each), updated from chat/reflection data
struct DevelopmentalDomains: Codable {
    var emotional: Double = 0.5
    var social: Double = 0.5
    var cognitive: Double = 0.5
    var communication: Double = 0.5
    var lifeSkills: Double = 0.5

    /// Apply weekly decay — edges weighted by recent history
    mutating func applyWeeklyDecay(factor: Double = 0.95) {
        emotional = max(0, emotional * factor)
        social = max(0, social * factor)
        cognitive = max(0, cognitive * factor)
        communication = max(0, communication * factor)
        lifeSkills = max(0, lifeSkills * factor)
    }
}

/// A single point on the risk trajectory (for weekly caregiver reports)
struct RiskTrajectoryPoint: Codable, Identifiable {
    let id: UUID
    let weekStart: String // "yyyy-MM-dd"
    let averageDysregulation: Double
    let averageCuriosity: Double
    let averageFatigue: Double
    let interventionCount: Int

    init(id: UUID = UUID(), weekStart: String, averageDysregulation: Double, averageCuriosity: Double, averageFatigue: Double, interventionCount: Int) {
        self.id = id
        self.weekStart = weekStart
        self.averageDysregulation = averageDysregulation
        self.averageCuriosity = averageCuriosity
        self.averageFatigue = averageFatigue
        self.interventionCount = interventionCount
    }
}

/// Known trigger patterns for this child
struct TriggerPattern: Codable, Identifiable {
    let id: UUID
    let pattern: String        // e.g. "rapid_search_after_block"
    var frequency: Int          // how often it's occurred
    var lastOccurred: Date

    init(id: UUID = UUID(), pattern: String, frequency: Int = 1, lastOccurred: Date = Date()) {
        self.id = id
        self.pattern = pattern
        self.frequency = frequency
        self.lastOccurred = lastOccurred
    }
}

// MARK: - Avatar Trust Degradation (Edge Case E)

/// Tracks trust between child and avatar. If child repeatedly dismisses,
/// reduce intervention frequency, increase autonomy, adjust peer tone.
struct AvatarTrustScore: Codable {
    /// Trust score (0–1). Starts high, degrades on dismissals.
    var score: Double = 0.8

    /// Number of times the child dismissed an intervention
    var dismissalCount: Int = 0

    /// Number of successful (non-dismissed) interventions
    var acceptedCount: Int = 0

    /// Computed intervention frequency multiplier (0.3–1.0).
    /// Lower trust → less frequent interventions.
    var interventionFrequencyMultiplier: Double {
        if score >= 0.7 { return 1.0 }
        if score >= 0.5 { return 0.7 }
        if score >= 0.3 { return 0.5 }
        return 0.3
    }

    /// Record a dismissed intervention
    mutating func recordDismissal() {
        dismissalCount += 1
        score = max(0.1, score - 0.05)
    }

    /// Record an accepted/engaged intervention
    mutating func recordAcceptance() {
        acceptedCount += 1
        score = min(1.0, score + 0.02)
    }

    /// Weekly recovery — trust slowly regenerates
    mutating func applyWeeklyRecovery() {
        score = min(1.0, score + 0.05)
    }
}

// MARK: - Intervention Engine (Section 3)

/// Decision output from the intervention planner
enum InterventionDecision {
    /// Severe risk — redirect to sandbox with educational framing
    case redirectToSandbox
    /// Moderate dysregulation — apply micro-guidance nudge
    case microGuidanceNudge
    /// Low risk — allow exploration, embed reflection opportunity
    case allowWithReflection

    static func decide(from intent: IntentVector, trustScore: AvatarTrustScore) -> InterventionDecision {
        // Apply trust multiplier — lower trust means higher threshold for intervention
        let effectiveThreshold = 0.5 / trustScore.interventionFrequencyMultiplier

        switch intent.overallRisk {
        case .severe:
            return .redirectToSandbox
        case .moderate:
            if intent.dysregulationProbability >= effectiveThreshold {
                return .microGuidanceNudge
            }
            return .allowWithReflection
        case .low:
            return .allowWithReflection
        }
    }
}

// MARK: - Technique Fatigue Tracking (Section 8)

/// Tracks how often each micro-guidance technique has been used this week,
/// to avoid pattern fatigue. No technique reused more than X times per week.
struct TechniqueFatigueTracker: Codable {
    private var usageCounts: [String: Int] = [:]
    private var weekStart: String = ""

    private static let maxUsagePerWeek = 5
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-'W'ww"
        return f
    }()

    /// Record usage of a technique
    mutating func recordUsage(_ technique: String) {
        resetIfNewWeek()
        usageCounts[technique, default: 0] += 1
    }

    /// Check if a technique can still be used this week
    mutating func canUse(_ technique: String) -> Bool {
        resetIfNewWeek()
        return (usageCounts[technique] ?? 0) < Self.maxUsagePerWeek
    }

    /// Get the least-used technique from a list of candidates
    mutating func leastUsed(from candidates: [String]) -> String? {
        resetIfNewWeek()
        return candidates.min { (usageCounts[$0] ?? 0) < (usageCounts[$1] ?? 0) }
    }

    private mutating func resetIfNewWeek() {
        let currentWeek = Self.dayFormatter.string(from: Date())
        if currentWeek != weekStart {
            usageCounts.removeAll()
            weekStart = currentWeek
        }
    }
}
#endif
