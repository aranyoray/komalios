#if os(iOS)
import Foundation

/// Lightweight history event sourced from local BrowsingHistoryService data
struct LocalHistoryEvent: Identifiable {
    let id: UUID
    let url: String
    let action: String
    let category: String?
    let subcategory: String?
    let timestamp: Date
    let pageTitle: String?
    let emojiResponse: String?

    /// Convert from a local BrowsingEvent
    init(from event: BrowsingEvent) {
        self.id = event.id
        self.url = event.url.absoluteString
        self.action = event.action?.rawValue.uppercased() ?? event.eventType.displayName.uppercased()
        // Split "Category:Subcategory" format
        if let cat = event.category, cat.contains(":") {
            let parts = cat.split(separator: ":", maxSplits: 1)
            self.category = String(parts[0])
            self.subcategory = parts.count > 1 ? String(parts[1]) : nil
        } else {
            self.category = event.category
            self.subcategory = nil
        }
        self.timestamp = event.timestamp
        self.pageTitle = event.pageTitle
        self.emojiResponse = nil
    }

    /// Extract host from URL, stripping "www." prefix
    var domain: String {
        guard let url = URL(string: url), let host = url.host else { return url }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// Returns category if present, otherwise falls back to domain
    var groupingKey: String {
        if let cat = category, !cat.isEmpty { return cat }
        return domain
    }
}

enum TimeRangeOption: String, CaseIterable, Identifiable {
    case oneHour = "1 Hour"
    case threeHours = "3 Hours"
    case sixHours = "6 Hours"
    case twelveHours = "12 Hours"
    case twentyFourHours = "24 Hours"
    case allTime = "All Time"

    var id: String { rawValue }

    var timeInterval: TimeInterval? {
        switch self {
        case .oneHour: return 3600
        case .threeHours: return 10800
        case .sixHours: return 21600
        case .twelveHours: return 43200
        case .twentyFourHours: return 86400
        case .allTime: return nil
        }
    }
}

struct HistoryBatch: Identifiable {
    let id = UUID()
    let events: [LocalHistoryEvent]
    var summaryHeadline: String
    var analysis: String
    var browsingIntent: String?
    var dominantEmoji: String?
    var timeRange: String
    var topicLabel: String
    var leadEmoji: String?
    var emojiSequence: [String]
    var primaryDomain: String?
}
#endif
