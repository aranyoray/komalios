#if os(iOS)
import Foundation

// MARK: - Contextual Prompt Models

enum ContextualPromptTrigger {
    case appOpen
    case tabSwitch
    case afterBrowsing
    case streakMilestone
    case moodChange
    case newMilestone
    case emotionalSpike
    case reflectionComplete
    case returnFromAbsence
}

enum ContextualPromptAction {
    case navigateToTab(NavigationTab)
    case startMoodCheckIn
    case showMilestone
    case showGrowthJourney
    case dismiss
}

struct ContextualPrompt: Identifiable {
    let id = UUID()
    let message: String
    let characterId: Int
    let characterName: String
    let characterImage: String
    let action: ContextualPromptAction?
    let actionLabel: String?
}

// MARK: - Prompt Template

enum PromptMoodFilter {
    case positive
    case negative
    case neutral
    case any
}

struct PromptTemplate {
    let id: String
    let message: String
    let characterId: Int
    let characterName: String
    let characterImage: String
    let ageGroups: Set<AgeGroup>
    let moodFilter: PromptMoodFilter
    let cooldownMinutes: Int
    let action: ContextualPromptAction?
    let actionLabel: String?
    let triggers: Set<ContextualPromptTrigger>
}

// Allow ContextualPromptTrigger to be used in a Set
extension ContextualPromptTrigger: Hashable {}

// MARK: - Engine

final class ContextualPromptEngine {
    static let shared = ContextualPromptEngine()
    private let maxPromptsPerSession = 5
    private let lastShownKey = "komal.contextualPrompt.lastShown"

    /// Cooldown tracking: templateId -> last shown date
    private var lastShown: [String: Date] = [:] {
        didSet {
            if let data = try? JSONEncoder().encode(lastShown) {
                UserDefaults.standard.set(data, forKey: lastShownKey)
            }
        }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: lastShownKey),
           let decoded = try? JSONDecoder().decode([String: Date].self, from: data) {
            lastShown = decoded
        }
    }

    // MARK: - Prompt Templates (20+)

    private var templates: [PromptTemplate] {
        let lm = LanguageManager.shared
        return [
        // --- Curiosity prompts ---
        PromptTemplate(
            id: "curiosity_noticed",
            message: lm.localized("prompt.curiosity_noticed"),
            characterId: 1, characterName: "Momo", characterImage: "animal1",
            ageGroups: [.under10, .tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .any, cooldownMinutes: 120,
            action: .navigateToTab(.riki), actionLabel: lm.localized("prompt.action.tell_me"),
            triggers: [.appOpen, .tabSwitch]
        ),
        PromptTemplate(
            id: "curiosity_learned",
            message: lm.localized("prompt.curiosity_learned"),
            characterId: 10, characterName: "Ellie", characterImage: "animal10",
            ageGroups: [.tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .any, cooldownMinutes: 180,
            action: .showGrowthJourney, actionLabel: lm.localized("prompt.action.show_me"),
            triggers: [.appOpen, .returnFromAbsence]
        ),
        PromptTemplate(
            id: "curiosity_question_young",
            message: lm.localized("prompt.curiosity_question_young"),
            characterId: 1, characterName: "Momo", characterImage: "animal1",
            ageGroups: [.under10],
            moodFilter: .any, cooldownMinutes: 90,
            action: .navigateToTab(.riki), actionLabel: lm.localized("prompt.action.lets_play"),
            triggers: [.afterBrowsing, .tabSwitch]
        ),
        // --- Growth prompts ---
        PromptTemplate(
            id: "growth_calm",
            message: lm.localized("prompt.growth_calm"),
            characterId: 4, characterName: "Leo", characterImage: "animal4",
            ageGroups: [.tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .positive, cooldownMinutes: 240,
            action: .navigateToTab(.reflect), actionLabel: lm.localized("prompt.action.let_me_think"),
            triggers: [.reflectionComplete, .moodChange]
        ),
        PromptTemplate(
            id: "growth_evolved",
            message: lm.localized("prompt.growth_evolved"),
            characterId: 10, characterName: "Ellie", characterImage: "animal10",
            ageGroups: [.thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .any, cooldownMinutes: 360,
            action: .showGrowthJourney, actionLabel: lm.localized("prompt.action.show_my_growth"),
            triggers: [.streakMilestone, .newMilestone]
        ),
        PromptTemplate(
            id: "growth_proud_young",
            message: lm.localized("prompt.growth_proud_young"),
            characterId: 5, characterName: "Bunny", characterImage: "animal5",
            ageGroups: [.under10],
            moodFilter: .any, cooldownMinutes: 120,
            action: nil, actionLabel: nil,
            triggers: [.streakMilestone, .newMilestone]
        ),
        PromptTemplate(
            id: "growth_streak_celebrate",
            message: lm.localized("prompt.growth_streak_celebrate"),
            characterId: 4, characterName: "Leo", characterImage: "animal4",
            ageGroups: [.under10, .tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .any, cooldownMinutes: 1440,
            action: .showGrowthJourney, actionLabel: lm.localized("prompt.action.see_my_journey"),
            triggers: [.streakMilestone]
        ),
        // --- Brave prompts ---
        PromptTemplate(
            id: "brave_question",
            message: lm.localized("prompt.brave_question"),
            characterId: 4, characterName: "Leo", characterImage: "animal4",
            ageGroups: [.tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .any, cooldownMinutes: 360,
            action: .navigateToTab(.riki), actionLabel: lm.localized("prompt.action.go_ahead"),
            triggers: [.appOpen, .tabSwitch]
        ),
        PromptTemplate(
            id: "brave_future",
            message: lm.localized("prompt.brave_future"),
            characterId: 10, characterName: "Ellie", characterImage: "animal10",
            ageGroups: [.thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .any, cooldownMinutes: 480,
            action: .navigateToTab(.reflect), actionLabel: lm.localized("prompt.action.lets_explore"),
            triggers: [.appOpen, .reflectionComplete]
        ),
        PromptTemplate(
            id: "brave_try_young",
            message: lm.localized("prompt.brave_try_young"),
            characterId: 5, characterName: "Bunny", characterImage: "animal5",
            ageGroups: [.under10],
            moodFilter: .any, cooldownMinutes: 180,
            action: .navigateToTab(.reflect), actionLabel: lm.localized("prompt.action.lets_try"),
            triggers: [.appOpen, .tabSwitch]
        ),
        // --- Transition prompts ---
        PromptTemplate(
            id: "transition_reflect",
            message: lm.localized("prompt.transition_reflect"),
            characterId: 5, characterName: "Bunny", characterImage: "animal5",
            ageGroups: [.under10, .tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .any, cooldownMinutes: 120,
            action: .navigateToTab(.reflect), actionLabel: lm.localized("prompt.action.sure"),
            triggers: [.tabSwitch, .afterBrowsing]
        ),
        PromptTemplate(
            id: "transition_progress",
            message: lm.localized("prompt.transition_progress"),
            characterId: 4, characterName: "Leo", characterImage: "animal4",
            ageGroups: [.under10, .tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .any, cooldownMinutes: 240,
            action: .showGrowthJourney, actionLabel: lm.localized("prompt.action.show_me_excited"),
            triggers: [.tabSwitch, .afterBrowsing]
        ),
        // --- Return prompts ---
        PromptTemplate(
            id: "return_changed",
            message: lm.localized("prompt.return_changed"),
            characterId: 10, characterName: "Ellie", characterImage: "animal10",
            ageGroups: [.under10, .tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .any, cooldownMinutes: 720,
            action: .showGrowthJourney, actionLabel: lm.localized("prompt.action.what_changed"),
            triggers: [.returnFromAbsence]
        ),
        PromptTemplate(
            id: "return_secret",
            message: lm.localized("prompt.return_secret"),
            characterId: 1, characterName: "Momo", characterImage: "animal1",
            ageGroups: [.tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .any, cooldownMinutes: 720,
            action: .showGrowthJourney, actionLabel: lm.localized("prompt.action.show_me_excited"),
            triggers: [.returnFromAbsence]
        ),
        PromptTemplate(
            id: "return_missed_young",
            message: lm.localized("prompt.return_missed_young"),
            characterId: 1, characterName: "Momo", characterImage: "animal1",
            ageGroups: [.under10],
            moodFilter: .any, cooldownMinutes: 720,
            action: .navigateToTab(.riki), actionLabel: lm.localized("prompt.action.lets_play"),
            triggers: [.returnFromAbsence]
        ),
        // --- Emotional spike prompts ---
        PromptTemplate(
            id: "emotional_check_negative",
            message: lm.localized("prompt.emotional_check_negative"),
            characterId: 5, characterName: "Bunny", characterImage: "animal5",
            ageGroups: [.under10, .tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .negative, cooldownMinutes: 240,
            action: .startMoodCheckIn, actionLabel: lm.localized("prompt.action.talk_about_it"),
            triggers: [.emotionalSpike, .moodChange]
        ),
        PromptTemplate(
            id: "emotional_celebrate_positive",
            message: lm.localized("prompt.emotional_celebrate_positive"),
            characterId: 1, characterName: "Momo", characterImage: "animal1",
            ageGroups: [.under10, .tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .positive, cooldownMinutes: 240,
            action: nil, actionLabel: nil,
            triggers: [.emotionalSpike, .moodChange]
        ),
        // --- Browsing prompts ---
        PromptTemplate(
            id: "browsing_learned",
            message: lm.localized("prompt.browsing_learned"),
            characterId: 10, characterName: "Ellie", characterImage: "animal10",
            ageGroups: [.under10, .tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .any, cooldownMinutes: 180,
            action: .navigateToTab(.riki), actionLabel: lm.localized("prompt.action.lets_chat"),
            triggers: [.afterBrowsing]
        ),
        PromptTemplate(
            id: "browsing_break",
            message: lm.localized("prompt.browsing_break"),
            characterId: 5, characterName: "Bunny", characterImage: "animal5",
            ageGroups: [.under10, .tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .any, cooldownMinutes: 120,
            action: .startMoodCheckIn, actionLabel: lm.localized("prompt.action.check_in"),
            triggers: [.afterBrowsing]
        ),
        PromptTemplate(
            id: "browsing_riddle_young",
            message: lm.localized("prompt.browsing_riddle_young"),
            characterId: 1, characterName: "Momo", characterImage: "animal1",
            ageGroups: [.under10, .tenToThirteen],
            moodFilter: .any, cooldownMinutes: 180,
            action: .navigateToTab(.riki), actionLabel: lm.localized("prompt.action.tell_me"),
            triggers: [.afterBrowsing]
        ),
        // --- Reflection complete prompts ---
        PromptTemplate(
            id: "reflect_done_great",
            message: lm.localized("prompt.reflect_done_great"),
            characterId: 10, characterName: "Ellie", characterImage: "animal10",
            ageGroups: [.under10, .tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .any, cooldownMinutes: 60,
            action: nil, actionLabel: nil,
            triggers: [.reflectionComplete]
        ),
        PromptTemplate(
            id: "reflect_deeper_teen",
            message: lm.localized("prompt.reflect_deeper_teen"),
            characterId: 4, characterName: "Leo", characterImage: "animal4",
            ageGroups: [.thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .any, cooldownMinutes: 120,
            action: .navigateToTab(.reflect), actionLabel: lm.localized("prompt.action.go_deeper"),
            triggers: [.reflectionComplete]
        ),
    ]
    }

    // MARK: - Public Methods

    /// Evaluate a trigger and optionally return a contextual prompt
    func evaluateTrigger(
        _ trigger: ContextualPromptTrigger,
        retentionState: RetentionState,
        currentTab: NavigationTab? = nil,
        ageGroup: AgeGroup? = nil,
        recentMood: String? = nil
    ) -> ContextualPrompt? {
        // Respect max prompts per session
        guard retentionState.promptsShownThisSession < maxPromptsPerSession else { return nil }

        // Determine mood filter from recent mood
        let currentMoodFilter = moodFilter(from: recentMood)

        // Get eligible templates
        let eligible = templates.filter { template in
            // Must match trigger
            guard template.triggers.contains(trigger) else { return false }

            // Must match age group if provided
            if let age = ageGroup, !template.ageGroups.contains(age) { return false }

            // Must match mood filter
            if template.moodFilter != .any && template.moodFilter != currentMoodFilter { return false }

            // Must respect cooldown
            if let lastDate = lastShown[template.id] {
                let elapsed = Date().timeIntervalSince(lastDate) / 60.0
                if elapsed < Double(template.cooldownMinutes) { return false }
            }

            return true
        }

        guard !eligible.isEmpty else { return nil }

        // For tab switches, only show 1 in 3 times
        if trigger == .tabSwitch {
            guard Int.random(in: 0..<3) == 0 else { return nil }
        }

        // For after browsing, only show 1 in 4 times
        if trigger == .afterBrowsing {
            guard Int.random(in: 0..<4) == 0 else { return nil }
        }

        // Pick a random eligible template
        guard let selected = eligible.randomElement() else { return nil }

        // Record cooldown
        lastShown[selected.id] = Date()

        return ContextualPrompt(
            message: selected.message,
            characterId: selected.characterId,
            characterName: selected.characterName,
            characterImage: selected.characterImage,
            action: selected.action,
            actionLabel: selected.actionLabel
        )
    }


    // MARK: - Private Helpers

    private func moodFilter(from mood: String?) -> PromptMoodFilter {
        guard let mood = mood?.lowercased() else { return .neutral }
        let positiveEmotions = ["happy", "excited", "grateful", "proud", "joyful"]
        let negativeEmotions = ["sad", "angry", "worried", "scared", "tired", "anxious", "frustrated"]
        if positiveEmotions.contains(mood) { return .positive }
        if negativeEmotions.contains(mood) { return .negative }
        return .neutral
    }
}
#endif
