#if os(iOS)
import Foundation
import Combine

final class MoodTrackingService: ObservableObject {
    static let shared = MoodTrackingService()

    @Published private(set) var recentEntries: [MoodEntry] = []

    private let fileManager = FileManager.default
    private let fileName = "mood_entries.json"
    private var moodData = MoodEntriesData()
    private let maxDays = 90

    private init() {
        loadData()
        recentEntries = Array(moodData.entries.suffix(7))
    }

    // MARK: - File URL

    private var fileURL: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(fileName)
    }

    // MARK: - Load / Save

    private func loadData() {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            moodData = try JSONDecoder().decode(MoodEntriesData.self, from: data)
            pruneOldEntries()
            print("🎭 Loaded \(moodData.entries.count) mood entries")
        } catch {
            print("🎭 Error loading mood data: \(error)")
        }
    }

    private func saveData() {
        do {
            let data = try JSONEncoder().encode(moodData)
            try data.write(to: fileURL)
        } catch {
            print("🎭 Error saving mood data: \(error)")
        }
    }

    // MARK: - Public Methods

    /// Log a new mood entry
    func logMood(_ entry: MoodEntry) {
        moodData.entries.append(entry)
        recentEntries = Array(moodData.entries.suffix(7))
        saveData()
        print("🎭 Logged mood: \(entry.emotion) (\(entry.context.rawValue))")
    }

    /// Get mood entries within a date range
    func getMoodEntries(from startDate: Date, to endDate: Date) -> [MoodEntry] {
        moodData.entries.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
    }

    /// Get mood entries for the last N days
    func getMoodEntries(days: Int) -> [MoodEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return moodData.entries.filter { $0.timestamp >= cutoff }
    }

    /// Get the dominant mood for each of the last N days
    func getMoodTrend(days: Int) -> [(date: String, emotion: String, emoji: String)] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var trend: [(date: String, emotion: String, emoji: String)] = []
        let entries = getMoodEntries(days: days)

        // Group by day
        let grouped = Dictionary(grouping: entries) { entry -> String in
            formatter.string(from: entry.timestamp)
        }

        for dayOffset in stride(from: days - 1, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let dateStr = formatter.string(from: date)
            if let dayEntries = grouped[dateStr] {
                // Find dominant emotion (most frequent)
                let counts = Dictionary(grouping: dayEntries, by: { $0.emotion }).mapValues { $0.count }
                if let dominant = counts.max(by: { $0.value < $1.value }) {
                    let emoji = dayEntries.first(where: { $0.emotion == dominant.key })?.emoji ?? ""
                    trend.append((date: dateStr, emotion: dominant.key, emoji: emoji))
                }
            }
        }

        return trend
    }

    /// Get emotion distribution over N days
    func getEmotionDistribution(days: Int) -> [String: Int] {
        let entries = getMoodEntries(days: days)
        return Dictionary(grouping: entries, by: { $0.emotion }).mapValues { $0.count }
    }

    /// Build a mood summary for the given period
    func getMoodSummary(days: Int) -> MoodSummary? {
        let entries = getMoodEntries(days: days)
        guard !entries.isEmpty else { return nil }

        let emotionCounts = Dictionary(grouping: entries, by: { $0.emotion }).mapValues { $0.count }
        let dominant = emotionCounts.max(by: { $0.value < $1.value })?.key ?? "Unknown"
        let avgIntensity = Double(entries.reduce(0) { $0 + $1.intensity }) / Double(entries.count)

        return MoodSummary(
            period: "\(days) days",
            dominantEmotion: dominant,
            averageIntensity: avgIntensity,
            emotionCounts: emotionCounts,
            totalEntries: entries.count
        )
    }

    /// Total mood check-in count (for milestones)
    func totalMoodCount() -> Int {
        moodData.entries.count
    }

    /// Check for concerning patterns (3+ consecutive sad entries)
    func hasConsecutiveSadEntries(count: Int = 3) -> Bool {
        let recent = moodData.entries.sorted { $0.timestamp > $1.timestamp }.prefix(count)
        guard recent.count >= count else { return false }
        return recent.allSatisfy { $0.emotion == "Sad" }
    }

    // MARK: - Pruning

    private func pruneOldEntries() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -maxDays, to: Date()) ?? Date()
        let before = moodData.entries.count
        moodData.entries.removeAll { $0.timestamp < cutoff }
        let removed = before - moodData.entries.count
        if removed > 0 {
            saveData()
            print("🎭 Pruned \(removed) old mood entries")
        }
    }
}
#endif
