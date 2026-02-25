#if os(iOS)
import Foundation

@MainActor
final class DigitalJourneyViewModel: ObservableObject {
    @Published var flaggedGroups: [TopicGroup] = []
    @Published var topicGroups: [TopicGroup] = []
    @Published var isLoading = false
    @Published var selectedFilter: ActionFilter = .all
    @Published var allItems: [HistoryItem] = []

    enum ActionFilter: String, CaseIterable {
        case all = "All", blocked = "Blocked", gated = "Gated", allowed = "Allowed"

        /// Maps display label to actual Firestore action value
        var actionKey: String {
            switch self {
            case .all: return ""
            case .blocked: return "BLOCK"
            case .gated: return "GATE"
            case .allowed: return "ALLOW"
            }
        }
    }

    private let appHistoryService = AppHistoryService.shared
    private let historyService = BrowsingHistoryService.shared
    private let geminiService = GeminiChatService()

    var filteredFlaggedGroups: [TopicGroup] { filterGroups(flaggedGroups) }
    var filteredTopicGroups: [TopicGroup] { filterGroups(topicGroups) }

    private func filterGroups(_ groups: [TopicGroup]) -> [TopicGroup] {
        guard selectedFilter != .all else { return groups }
        let key = selectedFilter.actionKey
        return groups.compactMap { group in
            let filtered = group.items.filter { $0.action == key }
            guard !filtered.isEmpty else { return nil }
            return TopicGroup(topicName: group.topicName, intentDescription: group.intentDescription, emojiSummary: group.emojiSummary, items: filtered, isFlagged: group.isFlagged)
        }
    }

    func loadHistory() {
        isLoading = true
        Task {
            // Try Firestore first, fall back to local BrowsingHistoryService
            let firestoreEvents = await appHistoryService.fetchHistory(limit: 200)
            let items: [HistoryItem]
            if !firestoreEvents.isEmpty {
                items = firestoreEvents.map { HistoryItem(from: $0) }
            } else {
                items = buildItemsFromLocalHistory()
            }
            self.allItems = items

            guard !items.isEmpty else { isLoading = false; return }

            let urlData = items.prefix(100).map { item -> [String: String] in
                var data: [String: String] = ["url": item.url, "action": item.action]
                if let cat = item.category { data["category"] = cat }
                if let sub = item.subcategory { data["subcategory"] = sub }
                if let emoji = item.emojiResponse { data["emoji"] = emoji }
                if let title = item.pageTitle { data["title"] = title }
                return data
            }

            do {
                let summary = try await geminiService.summarizeBrowsingHistory(urlData: urlData)
                parseGeminiSummary(summary, items: items)
            } catch {
                buildFallbackGroups(items: items)
            }
            isLoading = false
        }
    }

    /// Build HistoryItems from local BrowsingHistoryService when Firestore is empty
    private func buildItemsFromLocalHistory() -> [HistoryItem] {
        var allEvents: [BrowsingEvent] = []
        for session in historyService.allSessions {
            allEvents.append(contentsOf: session.events)
        }
        if let current = historyService.currentSession {
            allEvents.append(contentsOf: current.events)
        }
        allEvents.sort { $0.timestamp > $1.timestamp }
        return Array(allEvents.prefix(200)).map { HistoryItem(fromLocal: $0) }
    }

    private func parseGeminiSummary(_ json: String, items: [HistoryItem]) {
        struct GeminiTopicGroup: Decodable {
            let topicName: String
            let intentDescription: String
            let emojiSummary: String?
            let urls: [String]
        }

        var jsonString = json
        if let start = json.range(of: "["), let end = json.range(of: "]", options: .backwards) {
            jsonString = String(json[start.lowerBound...end.upperBound])
        }

        guard let jsonData = jsonString.data(using: .utf8),
              let groups = try? JSONDecoder().decode([GeminiTopicGroup].self, from: jsonData) else {
            buildFallbackGroups(items: items)
            return
        }

        var flagged: [TopicGroup] = []
        var normal: [TopicGroup] = []
        var assignedIds = Set<String>()

        for group in groups {
            let matched = items.filter { item in
                group.urls.contains { item.url.contains($0) || $0.contains(item.url) }
            }
            matched.forEach { assignedIds.insert($0.id) }
            let hasFlagged = matched.contains { $0.action == "BLOCK" || $0.action == "GATE" }
            let tg = TopicGroup(topicName: group.topicName, intentDescription: group.intentDescription, emojiSummary: group.emojiSummary ?? "", items: matched, isFlagged: hasFlagged)
            hasFlagged ? flagged.append(tg) : normal.append(tg)
        }

        let unassigned = items.filter { !assignedIds.contains($0.id) }
        if !unassigned.isEmpty {
            let hasFlag = unassigned.contains { $0.action == "BLOCK" || $0.action == "GATE" }
            let tg = TopicGroup(topicName: "Other Browsing", intentDescription: "Additional browsing activity", emojiSummary: "", items: unassigned, isFlagged: hasFlag)
            hasFlag ? flagged.append(tg) : normal.append(tg)
        }

        self.flaggedGroups = flagged
        self.topicGroups = normal
    }

    private func buildFallbackGroups(items: [HistoryItem]) {
        var grouped: [String: [HistoryItem]] = [:]
        for item in items { grouped[item.category ?? "General", default: []].append(item) }

        var flagged: [TopicGroup] = []
        var normal: [TopicGroup] = []
        for (cat, groupItems) in grouped {
            let hasFlagged = groupItems.contains { $0.action == "BLOCK" || $0.action == "GATE" }
            let tg = TopicGroup(topicName: cat, intentDescription: "Browsing activity in \(cat.lowercased())", emojiSummary: "", items: groupItems, isFlagged: hasFlagged)
            hasFlagged ? flagged.append(tg) : normal.append(tg)
        }
        self.flaggedGroups = flagged
        self.topicGroups = normal
    }

    func changeAction(for itemId: String, to newAction: String) {
        guard ["BLOCK", "GATE", "ALLOW"].contains(newAction) else { return }
        for i in flaggedGroups.indices {
            if let j = flaggedGroups[i].items.firstIndex(where: { $0.id == itemId }) {
                flaggedGroups[i].items[j].action = newAction
            }
        }
        for i in topicGroups.indices {
            if let j = topicGroups[i].items.firstIndex(where: { $0.id == itemId }) {
                topicGroups[i].items[j].action = newAction
            }
        }
        Task { await appHistoryService.updateAction(documentId: itemId, newAction: newAction) }
    }
}
#endif
