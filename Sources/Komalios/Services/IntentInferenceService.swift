#if os(iOS)
import Foundation
import Combine

/// Pulls from existing signal sources to compute the IntentVector (v2 §L2).
/// Called from RootView on appear and tab switches.
@MainActor
final class IntentInferenceService: ObservableObject {
    static let shared = IntentInferenceService()

    @Published var currentIntent = IntentVector()

    private var cancellables = Set<AnyCancellable>()

    private init() {
        // React to rage detection changes
        RageDetectionService.shared.$isRageDetected
            .sink { [weak self] _ in self?.updateIntent() }
            .store(in: &cancellables)

        // React to image filter count changes
        ImageFilterService.shared.$totalImagesFiltered
            .sink { [weak self] _ in self?.updateIntent() }
            .store(in: &cancellables)
    }

    // MARK: - Update

    /// Recompute the intent vector from all available signal sources.
    func updateIntent() {
        var intent = IntentVector()

        // -- Suggestive content risk (filtered / total ratio) --
        let filterService = ImageFilterService.shared
        let total = filterService.totalImagesAnalyzed
        let filtered = filterService.totalImagesFiltered
        if total > 0 {
            intent.suggestiveContentRisk = min(1.0, Double(filtered) / Double(total))
        }

        // -- Dysregulation probability from rage detection --
        if RageDetectionService.shared.isRageDetected {
            intent.dysregulationProbability = 0.8
        }

        // -- Emotional arousal from recent mood entries --
        let recentMoods = MoodTrackingService.shared.recentEntries
        if let lastMood = recentMoods.last {
            let negativeEmotions: Set<String> = ["sad", "angry", "worried", "scared", "anxious", "frustrated", "upset"]
            if negativeEmotions.contains(lastMood.emotion.lowercased()) {
                intent.emotionalArousal = 0.7
            } else {
                intent.emotionalArousal = 0.3
            }
        }

        // -- Fatigue level from session duration --
        // Estimate from how long ago retentionState.lastActiveDate was set to now
        // (session has been running since the app became active)
        let sessionMinutes = estimateSessionMinutes()
        if sessionMinutes > 60 {
            intent.fatigueLevel = min(1.0, Double(sessionMinutes - 60) / 120.0)
        }

        // -- Compulsive loop score from tab switch frequency --
        let engine = ContextualPromptEngine.shared
        intent.compulsiveLoopScore = engine.recentTabSwitchRate

        intent.lastUpdated = Date()
        currentIntent = intent
    }

    // MARK: - Intervention

    /// Compute the recommended intervention based on current intent + trust.
    func computeIntervention() -> InterventionDecision {
        let trustScore = ContextualPromptEngine.shared.trustScore
        return InterventionDecision.decide(from: currentIntent, trustScore: trustScore)
    }

    // MARK: - Helpers

    /// Record when the app comes to foreground so session duration can be estimated.
    func recordForegroundDate() {
        UserDefaults.standard.set(Date(), forKey: "komal.lastForegroundDate")
    }

    private func estimateSessionMinutes() -> Double {
        guard let foregroundDate = UserDefaults.standard.object(forKey: "komal.lastForegroundDate") as? Date else {
            return 0
        }
        return Date().timeIntervalSince(foregroundDate) / 60.0
    }
}
#endif
