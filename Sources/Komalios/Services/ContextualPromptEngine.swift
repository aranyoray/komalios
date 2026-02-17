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

    /// Cooldown tracking: templateId -> last shown date
    private var lastShown: [String: Date] = [:]

    private init() {}

    // MARK: - Prompt Templates (20+)

    private let templates: [PromptTemplate] = [
        // --- Curiosity prompts ---
        PromptTemplate(
            id: "curiosity_noticed",
            message: "I noticed something interesting today... Want to hear about it?",
            characterId: 1, characterName: "Momo", characterImage: "animal1",
            ageGroups: [.under10, .tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .any, cooldownMinutes: 120,
            action: .navigateToTab(.riki), actionLabel: "Tell me!",
            triggers: [.appOpen, .tabSwitch]
        ),
        PromptTemplate(
            id: "curiosity_learned",
            message: "Curious about what I learned from you? You might be surprised!",
            characterId: 10, characterName: "Ellie", characterImage: "animal10",
            ageGroups: [.tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .any, cooldownMinutes: 180,
            action: .showGrowthJourney, actionLabel: "Show me",
            triggers: [.appOpen, .returnFromAbsence]
        ),
        PromptTemplate(
            id: "curiosity_question_young",
            message: "I have a super fun question for you! Want to play?",
            characterId: 1, characterName: "Momo", characterImage: "animal1",
            ageGroups: [.under10],
            moodFilter: .any, cooldownMinutes: 90,
            action: .navigateToTab(.riki), actionLabel: "Let's play!",
            triggers: [.afterBrowsing, .tabSwitch]
        ),
        // --- Growth prompts ---
        PromptTemplate(
            id: "growth_calm",
            message: "You handled that calmly. How did you do that?",
            characterId: 4, characterName: "Leo", characterImage: "animal4",
            ageGroups: [.tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .positive, cooldownMinutes: 240,
            action: .navigateToTab(.reflect), actionLabel: "Let me think...",
            triggers: [.reflectionComplete, .moodChange]
        ),
        PromptTemplate(
            id: "growth_evolved",
            message: "Your thinking has really evolved. Want to see how far you've come?",
            characterId: 10, characterName: "Ellie", characterImage: "animal10",
            ageGroups: [.thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .any, cooldownMinutes: 360,
            action: .showGrowthJourney, actionLabel: "Show my growth",
            triggers: [.streakMilestone, .newMilestone]
        ),
        PromptTemplate(
            id: "growth_proud_young",
            message: "Wow, you're getting so good at this! I'm really proud of you!",
            characterId: 5, characterName: "Bunny", characterImage: "animal5",
            ageGroups: [.under10],
            moodFilter: .any, cooldownMinutes: 120,
            action: nil, actionLabel: nil,
            triggers: [.streakMilestone, .newMilestone]
        ),
        PromptTemplate(
            id: "growth_streak_celebrate",
            message: "Look at that streak! You're building something amazing, one day at a time.",
            characterId: 4, characterName: "Leo", characterImage: "animal4",
            ageGroups: [.under10, .tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .any, cooldownMinutes: 1440,
            action: .showGrowthJourney, actionLabel: "See my journey",
            triggers: [.streakMilestone]
        ),
        // --- Brave prompts ---
        PromptTemplate(
            id: "brave_question",
            message: "Can I ask you something brave? It might surprise you.",
            characterId: 4, characterName: "Leo", characterImage: "animal4",
            ageGroups: [.tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .any, cooldownMinutes: 360,
            action: .navigateToTab(.riki), actionLabel: "Go ahead",
            triggers: [.appOpen, .tabSwitch]
        ),
        PromptTemplate(
            id: "brave_future",
            message: "What would future-you say about today? Let's find out.",
            characterId: 10, characterName: "Ellie", characterImage: "animal10",
            ageGroups: [.thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .any, cooldownMinutes: 480,
            action: .navigateToTab(.reflect), actionLabel: "Let's explore",
            triggers: [.appOpen, .reflectionComplete]
        ),
        PromptTemplate(
            id: "brave_try_young",
            message: "Want to try something new together? I believe in you!",
            characterId: 5, characterName: "Bunny", characterImage: "animal5",
            ageGroups: [.under10],
            moodFilter: .any, cooldownMinutes: 180,
            action: .navigateToTab(.reflect), actionLabel: "Let's try!",
            triggers: [.appOpen, .tabSwitch]
        ),
        // --- Transition prompts ---
        PromptTemplate(
            id: "transition_reflect",
            message: "Quick reflection before you go? Just 2 minutes.",
            characterId: 5, characterName: "Bunny", characterImage: "animal5",
            ageGroups: [.under10, .tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .any, cooldownMinutes: 120,
            action: .navigateToTab(.reflect), actionLabel: "Sure!",
            triggers: [.tabSwitch, .afterBrowsing]
        ),
        PromptTemplate(
            id: "transition_progress",
            message: "Want to see your progress map? You've been busy!",
            characterId: 4, characterName: "Leo", characterImage: "animal4",
            ageGroups: [.under10, .tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .any, cooldownMinutes: 240,
            action: .showGrowthJourney, actionLabel: "Show me!",
            triggers: [.tabSwitch, .afterBrowsing]
        ),
        // --- Return prompts ---
        PromptTemplate(
            id: "return_changed",
            message: "Something small changed while you were away. Want to see?",
            characterId: 10, characterName: "Ellie", characterImage: "animal10",
            ageGroups: [.under10, .tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .any, cooldownMinutes: 720,
            action: .showGrowthJourney, actionLabel: "What changed?",
            triggers: [.returnFromAbsence]
        ),
        PromptTemplate(
            id: "return_secret",
            message: "Want to see a secret insight about yourself? I saved it for you.",
            characterId: 1, characterName: "Momo", characterImage: "animal1",
            ageGroups: [.tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .any, cooldownMinutes: 720,
            action: .showGrowthJourney, actionLabel: "Show me!",
            triggers: [.returnFromAbsence]
        ),
        PromptTemplate(
            id: "return_missed_young",
            message: "Yay, you're back! I missed you! Want to play together?",
            characterId: 1, characterName: "Momo", characterImage: "animal1",
            ageGroups: [.under10],
            moodFilter: .any, cooldownMinutes: 720,
            action: .navigateToTab(.riki), actionLabel: "Let's play!",
            triggers: [.returnFromAbsence]
        ),
        // --- Emotional spike prompts ---
        PromptTemplate(
            id: "emotional_check_negative",
            message: "Hey, I noticed you might be having a tough time. I'm here for you.",
            characterId: 5, characterName: "Bunny", characterImage: "animal5",
            ageGroups: [.under10, .tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .negative, cooldownMinutes: 240,
            action: .startMoodCheckIn, actionLabel: "Talk about it",
            triggers: [.emotionalSpike, .moodChange]
        ),
        PromptTemplate(
            id: "emotional_celebrate_positive",
            message: "You seem to be in a great mood! That's wonderful to see.",
            characterId: 1, characterName: "Momo", characterImage: "animal1",
            ageGroups: [.under10, .tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .positive, cooldownMinutes: 240,
            action: nil, actionLabel: nil,
            triggers: [.emotionalSpike, .moodChange]
        ),
        // --- Browsing prompts ---
        PromptTemplate(
            id: "browsing_learned",
            message: "Learned something cool while browsing? I'd love to hear about it!",
            characterId: 10, characterName: "Ellie", characterImage: "animal10",
            ageGroups: [.under10, .tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .any, cooldownMinutes: 180,
            action: .navigateToTab(.riki), actionLabel: "Let's chat",
            triggers: [.afterBrowsing]
        ),
        PromptTemplate(
            id: "browsing_break",
            message: "How are you feeling right now? Want to do a quick check-in?",
            characterId: 5, characterName: "Bunny", characterImage: "animal5",
            ageGroups: [.under10, .tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .any, cooldownMinutes: 120,
            action: .startMoodCheckIn, actionLabel: "Check in",
            triggers: [.afterBrowsing]
        ),
        PromptTemplate(
            id: "browsing_riddle_young",
            message: "Want to take a fun break? I've got a riddle for you!",
            characterId: 1, characterName: "Momo", characterImage: "animal1",
            ageGroups: [.under10, .tenToThirteen],
            moodFilter: .any, cooldownMinutes: 180,
            action: .navigateToTab(.riki), actionLabel: "Tell me!",
            triggers: [.afterBrowsing]
        ),
        // --- Reflection complete prompts ---
        PromptTemplate(
            id: "reflect_done_great",
            message: "That was a really thoughtful reflection. You should be proud of yourself.",
            characterId: 10, characterName: "Ellie", characterImage: "animal10",
            ageGroups: [.under10, .tenToThirteen, .thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .any, cooldownMinutes: 60,
            action: nil, actionLabel: nil,
            triggers: [.reflectionComplete]
        ),
        PromptTemplate(
            id: "reflect_deeper_teen",
            message: "Nice reflection. Want to go a little deeper? Sometimes the best insights come next.",
            characterId: 4, characterName: "Leo", characterImage: "animal4",
            ageGroups: [.thirteenToSixteen, .sixteenToEighteen],
            moodFilter: .any, cooldownMinutes: 120,
            action: .navigateToTab(.reflect), actionLabel: "Go deeper",
            triggers: [.reflectionComplete]
        ),
    ]

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

    /// Reset session-level tracking (called when app goes to background)
    func resetSession() {
        // lastShown persists across sessions for cooldown; only session prompts count resets in RetentionState
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
