#if os(iOS)
import Foundation
import SwiftUI

@MainActor
final class BrowsingHistoryViewModel: ObservableObject {
    @Published var batches: [HistoryBatch] = []
    @Published var isLoading = true
    @Published var error: String?

    // Filter state
    @Published var showBlocked: Bool = true
    @Published var showGated: Bool = true
    @Published var showAllowed: Bool
    @Published var selectedTimeRange: TimeRangeOption

    private let gemini = GeminiChatService()
    private var allLoadedEvents: [LocalHistoryEvent] = []
    private var filterTask: Task<Void, Never>?

    /// - Parameter showAllByDefault: When true (parent context), shows all events including allowed.
    init(showAllByDefault: Bool = false) {
        self.showAllowed = showAllByDefault
        self.selectedTimeRange = showAllByDefault ? .allTime : .twentyFourHours
    }

    // MARK: - Filtered Events

    private var filteredEvents: [LocalHistoryEvent] {
        let now = Date()
        return allLoadedEvents.filter { event in
            // Action filter
            let action = event.action.uppercased()
            let passesAction: Bool
            switch action {
            case "BLOCK", "BLOCKED":
                passesAction = showBlocked
            case "GATE", "GATED":
                passesAction = showGated
            case "ALLOW", "ALLOWED":
                passesAction = showAllowed
            default:
                passesAction = showAllowed
            }
            guard passesAction else { return false }

            // Time filter
            if let interval = selectedTimeRange.timeInterval {
                return event.timestamp >= now.addingTimeInterval(-interval)
            }
            return true
        }
    }

    // MARK: - Load History

    func loadHistory() async {
        isLoading = true
        error = nil

        let service = BrowsingHistoryService.shared
        var allEvents: [LocalHistoryEvent] = []

        for session in service.allSessions {
            allEvents.append(contentsOf: session.events.map { LocalHistoryEvent(from: $0) })
        }
        if let current = service.currentSession {
            allEvents.append(contentsOf: current.events.map { LocalHistoryEvent(from: $0) })
        }

        allEvents.sort { $0.timestamp > $1.timestamp }
        allLoadedEvents = allEvents

        guard !allEvents.isEmpty else {
            isLoading = false
            return
        }

        await applyFiltersAndGroup()
        isLoading = false
    }

    // MARK: - Filter Changed

    func onFilterChanged() {
        guard !allLoadedEvents.isEmpty else { return }
        filterTask?.cancel()
        filterTask = Task {
            isLoading = true
            await applyFiltersAndGroup()
            if !Task.isCancelled {
                isLoading = false
            }
        }
    }

    // MARK: - Apply Filters and Group

    private func applyFiltersAndGroup() async {
        let events = filteredEvents

        guard !events.isEmpty else {
            batches = []
            return
        }

        let rawBatches = Self.groupEventsSemantically(events)

        let initialBatches: [HistoryBatch] = rawBatches.map { group in
            let timeRange = Self.formatTimeRange(events: group)
            let dominant = Self.dominantEmoji(in: group)
            let emojiSeq = Self.buildEmojiSequence(from: group)
            let primaryDom = Self.mostFrequentDomain(in: group)
            return HistoryBatch(
                events: group,
                summaryHeadline: "Loading...",
                analysis: "",
                browsingIntent: nil,
                dominantEmoji: dominant,
                timeRange: timeRange,
                topicLabel: "Loading...",
                leadEmoji: emojiSeq.first,
                emojiSequence: emojiSeq,
                primaryDomain: primaryDom
            )
        }

        batches = initialBatches

        // Generate AI summaries
        let geminiService = gemini
        for (index, batch) in initialBatches.enumerated() {
            guard !Task.isCancelled else { return }
            do {
                let eventData: [[String: String]] = batch.events.map { event in
                    var dict: [String: String] = ["url": event.url, "action": event.action]
                    if let title = event.pageTitle { dict["title"] = title }
                    if let cat = event.category { dict["category"] = cat }
                    if let sub = event.subcategory { dict["subcategory"] = sub }
                    if let emoji = event.emojiResponse { dict["emoji"] = emoji }
                    return dict
                }
                let result = try await geminiService.summarizeHistoryBatch(eventData: eventData)
                guard index < batches.count else { continue }
                batches[index].topicLabel = result.topicLabel
                batches[index].summaryHeadline = result.topicLabel
                batches[index].analysis = result.analysis
                batches[index].browsingIntent = result.intent
                if let emoji = result.suggestedEmoji {
                    batches[index].leadEmoji = emoji
                    // Prepend suggested emoji to sequence if not already there
                    if !batches[index].emojiSequence.contains(emoji) {
                        batches[index].emojiSequence.insert(emoji, at: 0)
                    }
                }
            } catch {
                guard index < batches.count else { continue }
                batches[index].topicLabel = Self.fallbackHeadline(for: batch.events)
                batches[index].summaryHeadline = batches[index].topicLabel
                batches[index].analysis = "Unable to generate analysis."
            }
        }
    }

    // MARK: - Helpers

    /// Build emoji sequence from child emoji responses, falling back to CSVEmojiMappingService
    static func buildEmojiSequence(from events: [LocalHistoryEvent]) -> [String] {
        var emojis: [String] = []
        let mapper = CSVEmojiMappingService.shared

        // Sample roughly one emoji per 5 events
        let stride = max(1, events.count / 5)
        for i in Swift.stride(from: 0, to: events.count, by: stride) {
            let event = events[i]
            if let emoji = event.emojiResponse {
                emojis.append(emoji)
            } else if let sub = event.subcategory, !sub.isEmpty {
                let mapped = mapper.emojisForSubcategory(sub)
                if let first = mapped.first {
                    emojis.append(first)
                }
            } else if let cat = event.category, !cat.isEmpty {
                let mapped = mapper.emojisForSubcategory(cat)
                if let first = mapped.first {
                    emojis.append(first)
                }
            }
        }

        // Deduplicate consecutive emojis
        var deduped: [String] = []
        for emoji in emojis {
            if deduped.last != emoji {
                deduped.append(emoji)
            }
        }

        return deduped.isEmpty ? ["🌐"] : deduped
    }

    /// Returns the most frequently occurring domain in a list of events
    static func mostFrequentDomain(in events: [LocalHistoryEvent]) -> String? {
        var counts: [String: Int] = [:]
        for event in events {
            counts[event.domain, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    /// Group events semantically by category/domain instead of fixed stride
    private static func groupEventsSemantically(_ events: [LocalHistoryEvent]) -> [[LocalHistoryEvent]] {
        var buckets: [String: [LocalHistoryEvent]] = [:]
        var bucketOrder: [String] = []
        for event in events {
            let key = event.groupingKey
            if buckets[key] == nil { bucketOrder.append(key) }
            buckets[key, default: []].append(event)
        }

        var result: [[LocalHistoryEvent]] = []
        var overflow: [LocalHistoryEvent] = []

        for key in bucketOrder {
            guard var bucket = buckets[key] else { continue }
            bucket.sort { $0.timestamp > $1.timestamp }

            if bucket.count >= 7 {
                let numChunks = Int((Double(bucket.count) / 6.0).rounded(.up))
                let baseSize = bucket.count / numChunks
                let remainder = bucket.count % numChunks
                var offset = 0
                for i in 0..<numChunks {
                    let size = baseSize + (i < remainder ? 1 : 0)
                    result.append(Array(bucket[offset..<(offset + size)]))
                    offset += size
                }
            } else if bucket.count >= 3 {
                result.append(bucket)
            } else {
                overflow.append(contentsOf: bucket)
                if overflow.count >= 5 {
                    let chunk = Array(overflow.prefix(6))
                    overflow = Array(overflow.dropFirst(chunk.count))
                    result.append(chunk)
                }
            }
        }

        if !overflow.isEmpty {
            result.append(overflow)
        }

        result = result.map { batch in
            batch.sorted { $0.timestamp > $1.timestamp }
        }

        result.sort { batchA, batchB in
            let aMax = batchA.first?.timestamp ?? .distantPast
            let bMax = batchB.first?.timestamp ?? .distantPast
            return aMax > bMax
        }

        return result
    }

    private static func dominantEmoji(in events: [LocalHistoryEvent]) -> String? {
        let emojis = events.compactMap { $0.emojiResponse }
        guard !emojis.isEmpty else { return nil }
        var counts: [String: Int] = [:]
        for emoji in emojis { counts[emoji, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private static let timeOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    static func formatTimeRange(events: [LocalHistoryEvent]) -> String {
        guard let first = events.last, let last = events.first else { return "" }

        if Calendar.current.isDate(first.timestamp, inSameDayAs: last.timestamp) {
            return "\(dateOnlyFormatter.string(from: first.timestamp)), \(timeOnlyFormatter.string(from: first.timestamp)) - \(timeOnlyFormatter.string(from: last.timestamp))"
        }

        return "\(dateTimeFormatter.string(from: first.timestamp)) - \(dateTimeFormatter.string(from: last.timestamp))"
    }

    private static func fallbackHeadline(for events: [LocalHistoryEvent]) -> String {
        let categories = Set(events.compactMap { $0.category })
        if let first = categories.first {
            return first
        }
        return "Browsing Session"
    }
}
#endif
