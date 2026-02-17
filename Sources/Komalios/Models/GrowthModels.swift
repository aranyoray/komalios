#if os(iOS)
import Foundation

// MARK: - Daily Activity

struct DailyActivity: Codable, Identifiable {
    let id: UUID
    let date: String // "yyyy-MM-dd"
    var chatCount: Int
    var reflectionCount: Int
    var moodCheckInCount: Int
    var browsingMinutes: Int
    var morningAnchorCompleted: Bool
    var eveningAnchorCompleted: Bool

    var isActive: Bool {
        chatCount > 0 || reflectionCount > 0 || moodCheckInCount > 0
    }

    init(id: UUID = UUID(), date: String, chatCount: Int = 0, reflectionCount: Int = 0, moodCheckInCount: Int = 0, browsingMinutes: Int = 0, morningAnchorCompleted: Bool = false, eveningAnchorCompleted: Bool = false) {
        self.id = id
        self.date = date
        self.chatCount = chatCount
        self.reflectionCount = reflectionCount
        self.moodCheckInCount = moodCheckInCount
        self.browsingMinutes = browsingMinutes
        self.morningAnchorCompleted = morningAnchorCompleted
        self.eveningAnchorCompleted = eveningAnchorCompleted
    }
}

// MARK: - Weekly Snapshot

struct WeeklySnapshot: Codable, Identifiable {
    let id: UUID
    let weekStartDate: String // "yyyy-MM-dd"
    let weekEndDate: String
    var totalChats: Int
    var totalReflections: Int
    var totalMoodCheckIns: Int
    var activeDays: Int
    var dominantEmotion: String?
    var aiGrowthInsight: String?
    var topCharacterName: String?

    init(id: UUID = UUID(), weekStartDate: String, weekEndDate: String, totalChats: Int = 0, totalReflections: Int = 0, totalMoodCheckIns: Int = 0, activeDays: Int = 0, dominantEmotion: String? = nil, aiGrowthInsight: String? = nil, topCharacterName: String? = nil) {
        self.id = id
        self.weekStartDate = weekStartDate
        self.weekEndDate = weekEndDate
        self.totalChats = totalChats
        self.totalReflections = totalReflections
        self.totalMoodCheckIns = totalMoodCheckIns
        self.activeDays = activeDays
        self.dominantEmotion = dominantEmotion
        self.aiGrowthInsight = aiGrowthInsight
        self.topCharacterName = topCharacterName
    }
}

// MARK: - Milestone

struct Milestone: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let category: MilestoneCategory
    let requirement: Int
    var currentProgress: Int
    var earnedDate: Date?

    var isEarned: Bool { earnedDate != nil }
    var progress: Double { min(Double(currentProgress) / Double(requirement), 1.0) }

    enum MilestoneCategory: String, Codable {
        case streak, chat, reflection, mood, exploration
    }

    static let allMilestones: [Milestone] = [
        Milestone(id: "first_chat", title: "First Chat", description: "Had your first conversation with a friend", icon: "bubble.left.fill", category: .chat, requirement: 1, currentProgress: 0),
        Milestone(id: "chatty_friend", title: "Chatty Friend", description: "Had 10 conversations", icon: "bubble.left.and.bubble.right.fill", category: .chat, requirement: 10, currentProgress: 0),
        Milestone(id: "feeling_explorer", title: "Feeling Explorer", description: "Checked in with your feelings 5 times", icon: "heart.circle.fill", category: .mood, requirement: 5, currentProgress: 0),
        Milestone(id: "week_warrior", title: "Week Warrior", description: "Used Komal for 7 days in a row", icon: "flame.fill", category: .streak, requirement: 7, currentProgress: 0),
        Milestone(id: "reflection_star", title: "Reflection Star", description: "Completed 10 reflection sessions", icon: "sparkles", category: .reflection, requirement: 10, currentProgress: 0),
        Milestone(id: "character_collector", title: "Character Collector", description: "Chatted with 5 different friends", icon: "person.3.fill", category: .exploration, requirement: 5, currentProgress: 0),
        Milestone(id: "mood_master", title: "Mood Master", description: "Logged 30 mood check-ins", icon: "face.smiling.fill", category: .mood, requirement: 30, currentProgress: 0),
        Milestone(id: "month_champion", title: "Month Champion", description: "Used Komal for 30 days in a row", icon: "trophy.fill", category: .streak, requirement: 30, currentProgress: 0)
    ]
}

// MARK: - Daily Anchor

struct DailyAnchor: Codable, Identifiable {
    let id: UUID
    let date: String // "yyyy-MM-dd"
    let anchorType: AnchorType
    let timestamp: Date
    let emotion: String
    let emoji: String
    let intensity: Int
    var gratitudeItem: String?
    var reflectionItem: String?

    enum AnchorType: String, Codable {
        case morning, evening
    }

    init(id: UUID = UUID(), date: String, anchorType: AnchorType, timestamp: Date = Date(), emotion: String, emoji: String, intensity: Int, gratitudeItem: String? = nil, reflectionItem: String? = nil) {
        self.id = id
        self.date = date
        self.anchorType = anchorType
        self.timestamp = timestamp
        self.emotion = emotion
        self.emoji = emoji
        self.intensity = intensity
        self.gratitudeItem = gratitudeItem
        self.reflectionItem = reflectionItem
    }
}

// MARK: - Identity Stage

enum IdentityStage: String, Codable, CaseIterable {
    case explorer
    case thinker
    case builder
    case guide

    var description: String {
        switch self {
        case .explorer: return "Someone who's curious about the world"
        case .thinker: return "Someone who pauses and reflects"
        case .builder: return "Someone who grows through challenges"
        case .guide: return "Someone who helps others grow too"
        }
    }

    var icon: String {
        switch self {
        case .explorer: return "binoculars.fill"
        case .thinker: return "brain.head.profile"
        case .builder: return "hammer.fill"
        case .guide: return "star.fill"
        }
    }

    var narrativePrefix: String {
        switch self {
        case .explorer: return "You're an Explorer"
        case .thinker: return "You're a Thinker"
        case .builder: return "You're a Builder"
        case .guide: return "You're a Guide"
        }
    }

    var stageIndex: Int {
        switch self {
        case .explorer: return 0
        case .thinker: return 1
        case .builder: return 2
        case .guide: return 3
        }
    }
}

// MARK: - Identity Progression

struct IdentityProgression: Codable {
    var currentStage: IdentityStage
    var stageReachedDate: Date
    var observedTraits: [String]
    var stageHistory: [StageHistoryEntry]

    struct StageHistoryEntry: Codable {
        let stage: IdentityStage
        let reachedDate: Date
    }

    init(currentStage: IdentityStage = .explorer, stageReachedDate: Date = Date(), observedTraits: [String] = [], stageHistory: [StageHistoryEntry] = []) {
        self.currentStage = currentStage
        self.stageReachedDate = stageReachedDate
        self.observedTraits = observedTraits
        self.stageHistory = stageHistory
    }
}

// MARK: - Growth Data Container

struct GrowthData: Codable {
    var dailyActivities: [DailyActivity]
    var weeklySnapshots: [WeeklySnapshot]
    var milestones: [Milestone]
    var anchors: [DailyAnchor]
    var uniqueCharactersUsed: Set<Int>
    var identityProgression: IdentityProgression

    init(dailyActivities: [DailyActivity] = [], weeklySnapshots: [WeeklySnapshot] = [], milestones: [Milestone] = Milestone.allMilestones, anchors: [DailyAnchor] = [], uniqueCharactersUsed: Set<Int> = [], identityProgression: IdentityProgression = IdentityProgression()) {
        self.dailyActivities = dailyActivities
        self.weeklySnapshots = weeklySnapshots
        self.milestones = milestones
        self.anchors = anchors
        self.uniqueCharactersUsed = uniqueCharactersUsed
        self.identityProgression = identityProgression
    }
}
#endif
