#if os(iOS)
import Foundation

// MARK: - Mood Entry

struct MoodEntry: Codable, Identifiable {
    let id: UUID
    let emotion: String
    let emoji: String
    let intensity: Int
    let timestamp: Date
    let context: MoodContext
    var note: String?
    var characterId: Int?

    enum MoodContext: String, Codable {
        case morningAnchor
        case eveningAnchor
        case selSession
        case chatCheckIn
        case blockedContent
        case spontaneous
    }

    init(id: UUID = UUID(), emotion: String, emoji: String, intensity: Int, timestamp: Date = Date(), context: MoodContext, note: String? = nil, characterId: Int? = nil) {
        self.id = id
        self.emotion = emotion
        self.emoji = emoji
        self.intensity = intensity
        self.timestamp = timestamp
        self.context = context
        self.note = note
        self.characterId = characterId
    }
}

// MARK: - Mood Summary

struct MoodSummary: Codable {
    let period: String
    let dominantEmotion: String
    let averageIntensity: Double
    let emotionCounts: [String: Int]
    let totalEntries: Int
}

// MARK: - Mood Entries Container

struct MoodEntriesData: Codable {
    var entries: [MoodEntry]

    init(entries: [MoodEntry] = []) {
        self.entries = entries
    }
}
#endif
