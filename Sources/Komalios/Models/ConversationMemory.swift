import Foundation

// MARK: - Memory Tier

enum MemoryTier: String, Codable {
    case fullText
    case summarized
    case signalsOnly
}

// MARK: - Developmental Signal

struct DevelopmentalSignal: Codable, Identifiable {
    let id: UUID
    let date: Date
    let signalType: SignalType
    let summary: String
    let emotionTag: String?

    enum SignalType: String, Codable {
        case emotionalGrowth
        case socialSkill
        case selfAwareness
        case empathy
        case resilience
        case curiosity
        case conflictResolution
    }

    init(id: UUID = UUID(), date: Date = Date(), signalType: SignalType, summary: String, emotionTag: String? = nil) {
        self.id = id
        self.date = date
        self.signalType = signalType
        self.summary = summary
        self.emotionTag = emotionTag
    }
}

// MARK: - Persisted Chat Message

struct PersistedChatMessage: Codable, Identifiable {
    let id: UUID
    let text: String
    let isFromUser: Bool
    let timestamp: Date
    let characterId: Int
    var emotionTag: String?
    var topicTags: [String]

    init(id: UUID = UUID(), text: String, isFromUser: Bool, timestamp: Date = Date(), characterId: Int, emotionTag: String? = nil, topicTags: [String] = []) {
        self.id = id
        self.text = text
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.characterId = characterId
        self.emotionTag = emotionTag
        self.topicTags = topicTags
    }
}

// MARK: - Conversation Session

struct ConversationSession: Codable, Identifiable {
    let id: UUID
    let characterId: Int
    let characterName: String
    let startTime: Date
    var endTime: Date?
    var messages: [PersistedChatMessage]
    var summary: String?
    var dominantEmotion: String?
    var topicsCovered: [String]
    var memoryTier: MemoryTier
    var developmentalSignals: [DevelopmentalSignal]
    var tierTransitionDate: Date?

    init(id: UUID = UUID(), characterId: Int, characterName: String, startTime: Date = Date(), endTime: Date? = nil, messages: [PersistedChatMessage] = [], summary: String? = nil, dominantEmotion: String? = nil, topicsCovered: [String] = [], memoryTier: MemoryTier = .fullText, developmentalSignals: [DevelopmentalSignal] = [], tierTransitionDate: Date? = nil) {
        self.id = id
        self.characterId = characterId
        self.characterName = characterName
        self.startTime = startTime
        self.endTime = endTime
        self.messages = messages
        self.summary = summary
        self.dominantEmotion = dominantEmotion
        self.topicsCovered = topicsCovered
        self.memoryTier = memoryTier
        self.developmentalSignals = developmentalSignals
        self.tierTransitionDate = tierTransitionDate
    }
}

// MARK: - Conversation Entity

struct ConversationEntity: Codable, Identifiable {
    let id: UUID
    let name: String
    let entityType: EntityType
    var firstMentioned: Date
    var lastMentioned: Date
    var mentionCount: Int

    enum EntityType: String, Codable {
        case person, pet, place, hobby, school, food, game, other
    }

    init(id: UUID = UUID(), name: String, entityType: EntityType, firstMentioned: Date = Date(), lastMentioned: Date = Date(), mentionCount: Int = 1) {
        self.id = id
        self.name = name
        self.entityType = entityType
        self.firstMentioned = firstMentioned
        self.lastMentioned = lastMentioned
        self.mentionCount = mentionCount
    }
}

// MARK: - Conversation Memory Data (top-level persistence container)

struct ConversationMemoryData: Codable {
    var sessions: [ConversationSession]
    var entities: [ConversationEntity]
    var developmentalSignals: [DevelopmentalSignal]

    init(sessions: [ConversationSession] = [], entities: [ConversationEntity] = [], developmentalSignals: [DevelopmentalSignal] = []) {
        self.sessions = sessions
        self.entities = entities
        self.developmentalSignals = developmentalSignals
    }
}
