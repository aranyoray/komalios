#if os(iOS)
import Foundation
import Combine
import FirebaseAuth

final class ConversationMemoryService: ObservableObject {
    static let shared = ConversationMemoryService()

    @Published private(set) var currentSession: ConversationSession?

    private let fileManager = FileManager.default
    private let fileName = "conversation_memory.json"
    private var memoryData = ConversationMemoryData()
    private let maxMessagesPerCharacter = 500
    private var isMaintenanceRunning = false

    private init() {
        loadData()
    }

    // MARK: - File URL

    private var fileURL: URL {
        guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        }
        return docs.appendingPathComponent(fileName)
    }

    // MARK: - Load / Save

    private func loadData() {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            memoryData = try JSONDecoder().decode(ConversationMemoryData.self, from: data)
            print("💬 Loaded conversation memory: \(memoryData.sessions.count) sessions")
        } catch {
            print("💬 Error loading conversation memory: \(error)")
        }
    }

    private func saveData() {
        do {
            let data = try JSONEncoder().encode(memoryData)
            try data.write(to: fileURL)
        } catch {
            print("💬 Error saving conversation memory: \(error)")
        }
    }

    // MARK: - Public Methods

    /// Load recent conversation history for a character (last 20 messages)
    func loadConversationHistory(characterId: Int) -> [PersistedChatMessage] {
        let allMessages = memoryData.sessions
            .filter { $0.characterId == characterId && $0.memoryTier == .fullText }
            .flatMap { $0.messages }
            .sorted { $0.timestamp < $1.timestamp }

        return Array(allMessages.suffix(20))
    }

    /// Save a single message to the current session
    func saveMessage(_ message: PersistedChatMessage) {
        if currentSession == nil {
            return
        }
        currentSession?.messages.append(message)
        saveData()
    }

    /// Start a new conversation session
    func startSession(characterId: Int, characterName: String) {
        let session = ConversationSession(
            characterId: characterId,
            characterName: characterName
        )
        currentSession = session
        print("💬 Started session with \(characterName)")
    }

    /// End the current session and persist it
    func endCurrentSession(characterId: Int) {
        guard var session = currentSession, session.characterId == characterId else { return }
        session.endTime = Date()
        memoryData.sessions.append(session)
        pruneMessages(characterId: characterId)
        saveData()

        // Upload to Firestore (fire-and-forget)
        let completedSession = session
        let entities = memoryData.entities
        let signals = memoryData.developmentalSignals
        if let uid = Auth.auth().currentUser?.uid {
            Task {
                await FirestoreSyncService.shared.uploadConversationSession(uid: uid, session: completedSession)
                await FirestoreSyncService.shared.uploadConversationMeta(uid: uid, entities: entities, signals: signals)
            }
        }

        currentSession = nil
        print("💬 Ended session with \(session.characterName), \(session.messages.count) messages")
    }

    /// Build a context summary for Gemini system prompt (tier-aware, ~2000 token budget)
    func buildContextSummary(characterId: Int) -> String? {
        let sessions = memoryData.sessions
            .filter { $0.characterId == characterId }
            .sorted { $0.startTime > $1.startTime }

        guard !sessions.isEmpty else { return nil }

        var contextParts: [String] = []
        var estimatedTokens = 0
        let tokenBudget = 2000

        // Priority 1: fullText sessions (most recent)
        let fullTextSessions = sessions.filter { $0.memoryTier == .fullText }.prefix(3)
        for session in fullTextSessions {
            guard estimatedTokens < tokenBudget else { break }
            if let summary = session.summary {
                contextParts.append(summary)
                estimatedTokens += summary.count / 4
            } else {
                let userMessages = session.messages.filter { $0.isFromUser }.map { $0.text }
                if !userMessages.isEmpty {
                    let topics = userMessages.prefix(3).joined(separator: ", ")
                    let part = "Recently talked about: \(topics)"
                    contextParts.append(part)
                    estimatedTokens += part.count / 4
                }
            }
        }

        // Priority 2: summarized sessions
        let summarizedSessions = sessions.filter { $0.memoryTier == .summarized }.prefix(3)
        for session in summarizedSessions {
            guard estimatedTokens < tokenBudget else { break }
            if let summary = session.summary {
                contextParts.append("Earlier: \(summary)")
                estimatedTokens += summary.count / 4
            }
        }

        // Priority 3: signals-only sessions (aggregate developmental signals)
        let signalSessions = sessions.filter { $0.memoryTier == .signalsOnly }
        let allSignals = signalSessions.flatMap { $0.developmentalSignals }
        if !allSignals.isEmpty && estimatedTokens < tokenBudget {
            let signalSummaries = allSignals.prefix(5).map { $0.summary }
            let signalPart = "Growth patterns observed: " + signalSummaries.joined(separator: "; ")
            contextParts.append(signalPart)
            estimatedTokens += signalPart.count / 4
        }

        // Add top-level developmental signals
        if !memoryData.developmentalSignals.isEmpty && estimatedTokens < tokenBudget {
            let recentSignals = memoryData.developmentalSignals.suffix(3).map { $0.summary }
            let part = "Key developmental moments: " + recentSignals.joined(separator: "; ")
            contextParts.append(part)
        }

        // Add entity context
        let relevantEntities = memoryData.entities
            .filter { $0.mentionCount >= 2 }
            .sorted { $0.mentionCount > $1.mentionCount }
            .prefix(5)

        if !relevantEntities.isEmpty {
            let entityList = relevantEntities.map { "\($0.name) (\($0.entityType.rawValue))" }.joined(separator: ", ")
            contextParts.append("Important things to this child: \(entityList)")
        }

        guard !contextParts.isEmpty else { return nil }

        return "CONVERSATION MEMORY: You have chatted with this child before. " + contextParts.joined(separator: ". ") + "."
    }

    /// Build a personalized greeting referencing past conversations
    func buildContextGreeting(characterId: Int, characterName: String, defaultGreeting: String) -> String {
        let sessions = memoryData.sessions.filter { $0.characterId == characterId }
        guard let lastSession = sessions.sorted(by: { $0.startTime > $1.startTime }).first else {
            return defaultGreeting
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let timeAgo = formatter.localizedString(for: lastSession.startTime, relativeTo: Date())

        // Find a topic from the last session
        let lastUserMessages = lastSession.messages.filter { $0.isFromUser }
        if let lastTopic = lastUserMessages.last?.text, lastTopic.count < 100 {
            return "Hey, welcome back! We last chatted \(timeAgo). I remember you said: \"\(lastTopic)\". How have you been?"
        }

        return "Hey, great to see you again! We last hung out \(timeAgo). What's new with you?"
    }

    /// Get the last conversation time for a character
    func lastConversationTime(characterId: Int) -> Date? {
        memoryData.sessions
            .filter { $0.characterId == characterId }
            .sorted { $0.startTime > $1.startTime }
            .first?.startTime
    }

    /// Record that a character was used (for growth tracking)
    func getUniqueCharacterCount() -> Int {
        Set(memoryData.sessions.map { $0.characterId }).count
    }

    /// Get total session count for a character
    func sessionCount(characterId: Int) -> Int {
        memoryData.sessions.filter { $0.characterId == characterId }.count
    }

    /// Get total messages across all characters
    func totalMessageCount() -> Int {
        memoryData.sessions.reduce(0) { $0 + $1.messages.count }
    }

    /// Get most-used character ID
    func preferredCharacterId() -> Int? {
        let counts = Dictionary(grouping: memoryData.sessions, by: { $0.characterId })
            .mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    /// Get conversation topics for parent dashboard
    func getConversationTopics(days: Int = 30) -> [String: Int] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        var topicCounts: [String: Int] = [:]
        for session in memoryData.sessions where session.startTime >= cutoff {
            for topic in session.topicsCovered {
                topicCounts[topic, default: 0] += 1
            }
        }
        return topicCounts
    }

    /// Get recent topics from conversations (for parent conversation starters)
    func getRecentTopics(days: Int = 7) -> [String] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        var topics: [String] = []
        for session in memoryData.sessions where session.startTime >= cutoff {
            topics.append(contentsOf: session.topicsCovered)
            // Also extract from user messages
            let userTexts = session.messages.filter { $0.isFromUser }.prefix(3).map { $0.text }
            topics.append(contentsOf: userTexts)
        }
        return Array(Set(topics)).prefix(10).map { $0 }
    }

    // MARK: - Cloud Sync

    /// Merge conversation data downloaded from Firestore.
    /// Adds sessions not found locally by ID, deduplicates entities by name.
    func mergeCloudData(
        sessions: [ConversationSession],
        entities: [ConversationEntity],
        signals: [DevelopmentalSignal]
    ) {
        // Merge sessions by ID
        let localSessionIDs = Set(memoryData.sessions.map { $0.id })
        let newSessions = sessions.filter { !localSessionIDs.contains($0.id) }
        if !newSessions.isEmpty {
            memoryData.sessions.append(contentsOf: newSessions)
            memoryData.sessions.sort { $0.startTime > $1.startTime }
        }

        // Merge entities by name (deduplicate, keep higher mention count)
        let localEntityNames = Dictionary(uniqueKeysWithValues: memoryData.entities.map { ($0.name, $0) })
        for cloudEntity in entities {
            if let local = localEntityNames[cloudEntity.name] {
                // Keep whichever has higher mention count
                if cloudEntity.mentionCount > local.mentionCount,
                   let idx = memoryData.entities.firstIndex(where: { $0.name == cloudEntity.name }) {
                    memoryData.entities[idx] = cloudEntity
                }
            } else {
                memoryData.entities.append(cloudEntity)
            }
        }

        // Merge developmental signals by ID
        let localSignalIDs = Set(memoryData.developmentalSignals.map { $0.id })
        let newSignals = signals.filter { !localSignalIDs.contains($0.id) }
        if !newSignals.isEmpty {
            memoryData.developmentalSignals.append(contentsOf: newSignals)
        }

        if !newSessions.isEmpty || !newSignals.isEmpty {
            saveData()
            print("💬 Merged \(newSessions.count) sessions, \(newSignals.count) signals from cloud")
        }
    }

    // MARK: - Tiered Memory Maintenance

    /// Perform tiered maintenance: summarize old sessions, extract signals from older ones
    /// Rate-limited to max 5 summarizations per cycle
    func performTieredMaintenanceAsync() {
        Task {
            await performTieredMaintenance()
        }
    }

    @MainActor
    private func performTieredMaintenance() async {
        // Guard against concurrent mutation with pruneMessages
        guard !isMaintenanceRunning else { return }
        isMaintenanceRunning = true
        defer { isMaintenanceRunning = false }

        let now = Date()
        var summarizationsThisCycle = 0
        let maxSummarizations = 5

        let sessionCount = memoryData.sessions.count
        for i in 0..<sessionCount {
            guard i < memoryData.sessions.count else { break }
            let session = memoryData.sessions[i]
            guard let endTime = session.endTime else { continue }
            let hoursOld = now.timeIntervalSince(endTime) / 3600.0

            // 48h - 7d: summarize and delete raw messages
            if hoursOld >= 48 && hoursOld < 168 && session.memoryTier == .fullText {
                guard summarizationsThisCycle < maxSummarizations else { continue }

                if let summary = await summarizeSessionAsync(session) {
                    guard i < memoryData.sessions.count else { break }
                    memoryData.sessions[i].summary = summary
                    memoryData.sessions[i].messages = [] // Delete raw messages
                    memoryData.sessions[i].memoryTier = .summarized
                    memoryData.sessions[i].tierTransitionDate = now
                    summarizationsThisCycle += 1
                    print("💬 Tier transition: session \(session.id) -> summarized")
                }
            }

            // >7d: extract developmental signals, delete summary
            if hoursOld >= 168 && session.memoryTier == .summarized {
                guard summarizationsThisCycle < maxSummarizations else { continue }

                let signals = await extractDevelopmentalSignals(from: session)
                guard i < memoryData.sessions.count else { break }
                memoryData.sessions[i].developmentalSignals = signals
                memoryData.sessions[i].summary = nil
                memoryData.sessions[i].memoryTier = .signalsOnly
                memoryData.sessions[i].tierTransitionDate = now

                // Also store signals at the top-level
                memoryData.developmentalSignals.append(contentsOf: signals)

                summarizationsThisCycle += 1
                print("💬 Tier transition: session \(session.id) -> signalsOnly")
            }
        }

        if summarizationsThisCycle > 0 {
            saveData()
        }
    }

    /// Summarize a session using Gemini
    private func summarizeSessionAsync(_ session: ConversationSession) async -> String? {
        guard !session.messages.isEmpty else { return session.summary }

        let gemini = GeminiChatService()
        do {
            let summary = try await gemini.summarizeSession(session.messages, characterName: session.characterName)
            return summary
        } catch {
            print("💬 Failed to summarize session: \(error)")
            // Fallback: create a basic summary from topics
            if !session.topicsCovered.isEmpty {
                return "Discussed: \(session.topicsCovered.joined(separator: ", "))"
            }
            return nil
        }
    }

    /// Extract developmental signals from a summarized session
    private func extractDevelopmentalSignals(from session: ConversationSession) async -> [DevelopmentalSignal] {
        guard let summary = session.summary else { return [] }

        let gemini = GeminiChatService()
        let prompt = """
        Analyze this conversation summary and extract developmental signals.
        Summary: \(summary)
        Character: \(session.characterName)
        Dominant emotion: \(session.dominantEmotion ?? "unknown")

        Return ONLY a JSON array of objects with: "signalType" (one of: emotionalGrowth, socialSkill, selfAwareness, empathy, resilience, curiosity, conflictResolution), "summary" (1 sentence), "emotionTag" (optional emotion word).
        If no clear signals, return [].
        """

        do {
            let response = try await gemini.sendSimplePrompt(prompt, systemPrompt: "You are a child development analyst. Return only valid JSON array, no markdown.")
            let cleaned = response.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)

            guard let data = cleaned.data(using: .utf8),
                  let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return []
            }

            return jsonArray.compactMap { item -> DevelopmentalSignal? in
                guard let typeStr = item["signalType"] as? String,
                      let type = DevelopmentalSignal.SignalType(rawValue: typeStr),
                      let summary = item["summary"] as? String else { return nil }
                return DevelopmentalSignal(
                    date: session.startTime,
                    signalType: type,
                    summary: summary,
                    emotionTag: item["emotionTag"] as? String
                )
            }
        } catch {
            print("💬 Failed to extract developmental signals: \(error)")
            return []
        }
    }

    // MARK: - Pruning

    private func pruneMessages(characterId: Int) {
        // Skip pruning if tiered maintenance is actively mutating memoryData
        guard !isMaintenanceRunning else { return }

        var allMessages = memoryData.sessions
            .filter { $0.characterId == characterId && $0.memoryTier == .fullText }
            .flatMap { $0.messages }

        if allMessages.count > maxMessagesPerCharacter {
            allMessages.sort { $0.timestamp < $1.timestamp }
            let excess = allMessages.count - maxMessagesPerCharacter
            let oldestIdsToRemove = Set(allMessages.prefix(excess).map { $0.id })

            for i in 0..<memoryData.sessions.count {
                if memoryData.sessions[i].characterId == characterId && memoryData.sessions[i].memoryTier == .fullText {
                    memoryData.sessions[i].messages.removeAll { oldestIdsToRemove.contains($0.id) }
                }
            }
            // Remove empty fullText sessions
            memoryData.sessions.removeAll { $0.characterId == characterId && $0.memoryTier == .fullText && $0.messages.isEmpty }
            print("💬 Pruned \(excess) messages for character \(characterId)")
        }
    }
}
#endif
