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
        case chatCheckIn
        case blockedContent
        case spontaneous

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            self = MoodContext(rawValue: raw) ?? .spontaneous
        }
    }

    init(id: UUID = UUID(), emotion: String, emoji: String = "", intensity: Int = 0, timestamp: Date = Date(), context: MoodContext, note: String? = nil, characterId: Int? = nil) {
        self.id = id
        self.emotion = emotion
        self.emoji = emoji
        self.intensity = intensity
        self.timestamp = timestamp
        self.context = context
        self.note = note
        self.characterId = characterId
    }

    private enum CodingKeys: String, CodingKey {
        case id, emotion, emoji, intensity, timestamp, context, note, characterId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        emotion = try container.decode(String.self, forKey: .emotion)
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji) ?? ""
        intensity = try container.decodeIfPresent(Int.self, forKey: .intensity) ?? 0
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        context = try container.decode(MoodContext.self, forKey: .context)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        characterId = try container.decodeIfPresent(Int.self, forKey: .characterId)
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
