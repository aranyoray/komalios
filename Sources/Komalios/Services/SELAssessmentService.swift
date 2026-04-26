#if os(iOS)
import Foundation
import Combine
import FirebaseAuth

@MainActor
final class SELAssessmentService: ObservableObject {
    static let shared = SELAssessmentService()

    private static let iso8601Formatter = ISO8601DateFormatter()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private let fileManager = FileManager.default
    private let fileName = "sel_records.json"

    private init() {}

    // MARK: - File URL

    private var fileURL: URL {
        guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        }
        return docs.appendingPathComponent(fileName)
    }

    // MARK: - Persistence

    private func loadRecords() -> [SELDailyRecord] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([SELDailyRecord].self, from: data)
        } catch {
            #if DEBUG
            print("🧠 Error loading SEL records: \(error)")
            #endif
            return []
        }
    }

    private func saveRecords(_ records: [SELDailyRecord]) {
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            #if DEBUG
            print("🧠 Error saving SEL records: \(error)")
            #endif
        }
    }

    // MARK: - Scenario Pools (localized)

    private func l(_ key: String) -> String { LanguageManager.localized(key) }

    private func buildScenario(id: String, domain: SELDomain, emoji: String, checks: [(id: String, competency: String, emojis: [String], scores: [Int])]) -> SELScenario {
        SELScenario(
            id: id, domain: domain,
            title: l("sel.\(id).title"),
            narrative: l("sel.\(id).narrative"),
            emoji: emoji,
            checks: checks.map { c in
                SELCheck(id: c.id, competency: c.competency,
                    question: l("sel.\(c.id).q"),
                    options: (0..<3).map { i in
                        SELOption(text: l("sel.\(c.id).o\(i + 1)"), emoji: c.emojis[i], score: c.scores[i])
                    })
            })
    }

    private var allScenarios: [SELDomain: [SELScenario]] {
        [
            .socialCommunication: [
                buildScenario(id: "sc1", domain: .socialCommunication, emoji: "🏫", checks: [
                    (id: "sc1-1", competency: "Initiates greetings", emojis: ["👋", "🙂", "🍽"], scores: [3, 2, 1]),
                    (id: "sc1-2", competency: "Starts conversation on a topic of interest", emojis: ["🎨", "👍", "😐"], scores: [3, 2, 1]),
                    (id: "sc1-3", competency: "Responds to invitations of peers", emojis: ["✅", "🤔", "😕"], scores: [3, 2, 1]),
                ]),
                buildScenario(id: "sc2", domain: .socialCommunication, emoji: "📚", checks: [
                    (id: "sc2-1", competency: "Introduces self to new people", emojis: ["🙋", "⏳", "🤐"], scores: [3, 2, 1]),
                    (id: "sc2-2", competency: "Gives compliments or positive statements", emojis: ["🌟", "👍", "🙅"], scores: [3, 2, 1]),
                    (id: "sc2-3", competency: "Offers assistance to others", emojis: ["🤝", "📢", "📝"], scores: [3, 2, 1]),
                ]),
                buildScenario(id: "sc3", domain: .socialCommunication, emoji: "🎮", checks: [
                    (id: "sc3-1", competency: "Takes turns appropriately", emojis: ["🔄", "⏰", "🎮"], scores: [3, 2, 1]),
                    (id: "sc3-2", competency: "Handles disagreements constructively", emojis: ["🤝", "😤", "🚪"], scores: [3, 2, 1]),
                    (id: "sc3-3", competency: "Includes others in activities", emojis: ["👋", "🤷", "🚫"], scores: [3, 2, 1]),
                ]),
            ],
            .emotionalIntelligence: [
                buildScenario(id: "ei1", domain: .emotionalIntelligence, emoji: "🍦", checks: [
                    (id: "ei1-1", competency: "Identifies simple emotions", emojis: ["😢", "😠", "🤷"], scores: [3, 2, 1]),
                    (id: "ei1-2", competency: "Understands reason for feelings", emojis: ["💭", "🍨", "❓"], scores: [3, 2, 1]),
                    (id: "ei1-3", competency: "Comforts someone who is hurt", emojis: ["💛", "🙏", "🤷"], scores: [3, 2, 1]),
                ]),
                buildScenario(id: "ei2", domain: .emotionalIntelligence, emoji: "🎭", checks: [
                    (id: "ei2-1", competency: "Recognizes nonverbal cues", emojis: ["😔", "😠", "😴"], scores: [3, 2, 1]),
                    (id: "ei2-2", competency: "Understanding complex feelings", emojis: ["💡", "🏆", "🥱"], scores: [3, 2, 1]),
                    (id: "ei2-3", competency: "Accepts and supports emotional experiences", emojis: ["💪", "😊", "📖"], scores: [3, 2, 1]),
                ]),
                buildScenario(id: "ei3", domain: .emotionalIntelligence, emoji: "🐕", checks: [
                    (id: "ei3-1", competency: "Identifies mixed emotions", emojis: ["💔", "😢", "🤷"], scores: [3, 2, 1]),
                    (id: "ei3-2", competency: "Expresses feelings constructively", emojis: ["💬", "😤", "🤐"], scores: [3, 2, 1]),
                    (id: "ei3-3", competency: "Self-regulation strategies", emojis: ["🧘", "😭", "😡"], scores: [3, 2, 1]),
                ]),
            ],
            .cognitiveDevelopment: [
                buildScenario(id: "cd1", domain: .cognitiveDevelopment, emoji: "🐱", checks: [
                    (id: "cd1-1", competency: "Identifies when to seek help", emojis: ["🔎", "🏃", "🏠"], scores: [3, 2, 1]),
                    (id: "cd1-2", competency: "Describes steps in sequence", emojis: ["📋", "👀", "🤷"], scores: [3, 2, 1]),
                    (id: "cd1-3", competency: "Problem solving with before/after reasoning", emojis: ["🏚", "🌳", "🐈"], scores: [3, 2, 1]),
                ]),
                buildScenario(id: "cd2", domain: .cognitiveDevelopment, emoji: "🍪", checks: [
                    (id: "cd2-1", competency: "Follows a schedule for activities", emojis: ["📅", "⏰", "👨"], scores: [3, 2, 1]),
                    (id: "cd2-2", competency: "Explains money concepts", emojis: ["💰", "🪙", "🎁"], scores: [3, 2, 1]),
                    (id: "cd2-3", competency: "Identifies morning/afternoon/nighttime appropriately", emojis: ["🧮", "👍", "😟"], scores: [3, 2, 1]),
                ]),
                buildScenario(id: "cd3", domain: .cognitiveDevelopment, emoji: "🧩", checks: [
                    (id: "cd3-1", competency: "Identifies patterns", emojis: ["🔍", "🤔", "🤷"], scores: [3, 2, 1]),
                    (id: "cd3-2", competency: "Considers cause and effect", emojis: ["💡", "👀", "❓"], scores: [3, 2, 1]),
                    (id: "cd3-3", competency: "Makes predictions based on information", emojis: ["🎯", "🤞", "😐"], scores: [3, 2, 1]),
                ]),
            ],
            .lifeSkills: [
                buildScenario(id: "ls1", domain: .lifeSkills, emoji: "🚶", checks: [
                    (id: "ls1-1", competency: "Looks both ways to cross street", emojis: ["🚦", "👁", "🚶"], scores: [3, 2, 1]),
                    (id: "ls1-2", competency: "States dangerous situations", emojis: ["🛑", "🏃", "❓"], scores: [3, 2, 1]),
                    (id: "ls1-3", competency: "Walks to familiar places safely", emojis: ["📱", "🚧", "⚠️"], scores: [3, 2, 1]),
                ]),
                buildScenario(id: "ls2", domain: .lifeSkills, emoji: "☀️", checks: [
                    (id: "ls2-1", competency: "Understands personal hygiene", emojis: ["🪥", "👕", "📺"], scores: [3, 2, 1]),
                    (id: "ls2-2", competency: "Knows appropriate clothes for occasions", emojis: ["🌧", "👕", "🤷"], scores: [3, 2, 1]),
                    (id: "ls2-3", competency: "Understands healthy food", emojis: ["🥪", "🍫", "🍟"], scores: [3, 2, 1]),
                ]),
                buildScenario(id: "ls3", domain: .lifeSkills, emoji: "🏥", checks: [
                    (id: "ls3-1", competency: "Knows when to ask for help", emojis: ["🗣", "🤕", "😶"], scores: [3, 2, 1]),
                    (id: "ls3-2", competency: "Understands basic first aid", emojis: ["🩹", "💧", "🤷"], scores: [3, 2, 1]),
                    (id: "ls3-3", competency: "Knows emergency contacts", emojis: ["📞", "🏃", "😰"], scores: [3, 2, 1]),
                ]),
            ],
            .languageDevelopment: [
                buildScenario(id: "ld1", domain: .languageDevelopment, emoji: "🤖", checks: [
                    (id: "ld1-1", competency: "Labels and describes events or items", emojis: ["🎙", "🤖", "😐"], scores: [3, 2, 1]),
                    (id: "ld1-2", competency: "Answers what/where questions", emojis: ["💬", "🎁", "🤷"], scores: [3, 2, 1]),
                    (id: "ld1-3", competency: "Tells about experiences", emojis: ["😂", "🏠", "🙂"], scores: [3, 2, 1]),
                ]),
                buildScenario(id: "ld2", domain: .languageDevelopment, emoji: "🎂", checks: [
                    (id: "ld2-1", competency: "Describes steps in sequence", emojis: ["🎉", "🍰", "👍"], scores: [3, 2, 1]),
                    (id: "ld2-2", competency: "Labels social interaction behaviour", emojis: ["🎩", "😆", "😔"], scores: [3, 2, 1]),
                    (id: "ld2-3", competency: "Describes people encountered", emojis: ["👫", "😊", "🤷"], scores: [3, 2, 1]),
                ]),
                buildScenario(id: "ld3", domain: .languageDevelopment, emoji: "🎬", checks: [
                    (id: "ld3-1", competency: "Retells a story with details", emojis: ["📖", "🎥", "🤷"], scores: [3, 2, 1]),
                    (id: "ld3-2", competency: "Uses descriptive language", emojis: ["🌈", "👍", "😐"], scores: [3, 2, 1]),
                    (id: "ld3-3", competency: "Asks clarifying questions", emojis: ["❓", "🙂", "😶"], scores: [3, 2, 1]),
                ]),
            ],
        ]
    }

    // MARK: - Session Logic

    func getDailyScenarios() -> [SELScenario] {
        allScenarios.values.compactMap { pool in
            pool.randomElement()
        }
    }

    // MARK: - Record Management

    func saveSessionRecord(results: [SELCheckResult], mindfulnessDone: Bool) -> SELDailyRecord {
        var records = loadRecords()
        let today = todayString()

        let record = SELDailyRecord(
            id: UUID().uuidString,
            date: today,
            completedAt: SELAssessmentService.iso8601Formatter.string(from: Date()),
            domainScores: computeAllDomainScores(results: results),
            checkResults: results,
            mindfulnessCompleted: mindfulnessDone
        )

        if let idx = records.firstIndex(where: { $0.date == today }) {
            records[idx] = record
        } else {
            records.append(record)
        }

        saveRecords(records)

        // Upload to Firestore (fire-and-forget)
        let uploadRecord = record
        if let uid = Auth.auth().currentUser?.uid {
            Task {
                await FirestoreSyncService.shared.uploadSELRecord(uid: uid, record: uploadRecord)
            }
        }

        return record
    }

    /// Save a voice curriculum session record. Local-only — does NOT sync to Firestore.
    /// Each step fans out to one SELCheckResult per domain in targetDomains.
    func saveVoiceSessionRecord(stepResults: [(stepId: String, score: Int, domains: [SELDomain], competency: String)]) {
        var checkResults: [SELCheckResult] = []
        for result in stepResults {
            for domain in result.domains {
                checkResults.append(SELCheckResult(
                    checkId: result.stepId,
                    domain: domain,
                    competency: result.competency,
                    score: result.score
                ))
            }
        }

        var records = loadRecords()
        let today = todayString()
        let record = SELDailyRecord(
            id: UUID().uuidString,
            date: today,
            completedAt: SELAssessmentService.iso8601Formatter.string(from: Date()),
            domainScores: computeAllDomainScores(results: checkResults),
            checkResults: checkResults,
            mindfulnessCompleted: false
        )

        if let idx = records.firstIndex(where: { $0.date == today }) {
            records[idx] = record
        } else {
            records.append(record)
        }

        saveRecords(records)
        // NO Firestore upload — local-only for COPPA compliance
    }

    func getRecords(days: Int = 30) -> [SELDailyRecord] {
        let records = loadRecords()
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let cutoffStr = SELAssessmentService.dateFormatter.string(from: cutoff)
        return records.filter { $0.date >= cutoffStr }.sorted { $0.date < $1.date }
    }

    func getTodayRecord() -> SELDailyRecord? {
        let today = todayString()
        return loadRecords().first { $0.date == today }
    }

    func getProfileSummary() -> SELProfileSummary {
        let records = getRecords(days: 7)

        guard !records.isEmpty else {
            return SELProfileSummary(
                strengths: [],
                growthAreas: [],
                overallScore: 0,
                trend: .stable,
                insight: LanguageManager.localized("sel.insight.no_data")
            )
        }

        let latest = records[records.count - 1]
        let scores = latest.domainScores
        let sortedDomains = scores.sorted { $0.value > $1.value }

        let strengths = sortedDomains.filter { $0.value >= 60 }.map { $0.key }
        let growthAreas = sortedDomains.filter { $0.value < 50 }.map { $0.key }
        let overallScore = scores.values.isEmpty ? 0 : Int(round(Double(scores.values.reduce(0, +)) / Double(scores.values.count)))

        var trend: SELTrend = .stable
        if records.count >= 3 {
            let mid = records.count / 2
            let firstHalf = Array(records.prefix(mid))
            let secondHalf = Array(records.suffix(from: mid))
            let avgFirst = firstHalf.reduce(0.0) { acc, record in
                let vals = record.domainScores.values
                return acc + (vals.isEmpty ? 0.0 : Double(vals.reduce(0, +)) / Double(vals.count))
            } / Double(max(1, firstHalf.count))
            let avgSecond = secondHalf.reduce(0.0) { acc, record in
                let vals = record.domainScores.values
                return acc + (vals.isEmpty ? 0.0 : Double(vals.reduce(0, +)) / Double(vals.count))
            } / Double(max(1, secondHalf.count))
            if avgSecond - avgFirst > 3 { trend = .improving }
            else if avgFirst - avgSecond > 3 { trend = .declining }
        }

        let growthAreaNames = growthAreas.map { $0.label }
        let strengthNames = strengths.map { $0.label }

        let lang = LanguageManager.shared
        let insight: String
        if trend == .improving {
            if strengthNames.isEmpty {
                insight = lang.localized("sel.insight.improving")
            } else {
                insight = lang.localized("sel.insight.improving_with_strengths", strengthNames.prefix(2).joined(separator: ", "))
            }
        } else if !growthAreas.isEmpty {
            insight = lang.localized("sel.insight.growth_areas", growthAreaNames.joined(separator: ", "))
        } else {
            insight = lang.localized("sel.insight.balanced")
        }

        return SELProfileSummary(strengths: strengths, growthAreas: growthAreas, overallScore: overallScore, trend: trend, insight: insight)
    }

    // MARK: - Cloud Sync

    /// Merge SEL records downloaded from Firestore.
    /// Merges by date, preferring higher overall scores.
    func mergeCloudRecords(_ cloudRecords: [SELDailyRecord]) {
        var records = loadRecords()
        let localDates = Dictionary(uniqueKeysWithValues: records.map { ($0.date, $0) })

        var merged = 0
        for cloudRecord in cloudRecords {
            if let local = localDates[cloudRecord.date] {
                // Prefer higher overall score
                let localAvg = local.domainScores.values.isEmpty ? 0 : Int(round(Double(local.domainScores.values.reduce(0, +)) / Double(local.domainScores.values.count)))
                let cloudAvg = cloudRecord.domainScores.values.isEmpty ? 0 : Int(round(Double(cloudRecord.domainScores.values.reduce(0, +)) / Double(cloudRecord.domainScores.values.count)))
                if cloudAvg > localAvg, let idx = records.firstIndex(where: { $0.date == cloudRecord.date }) {
                    records[idx] = cloudRecord
                    merged += 1
                }
            } else {
                records.append(cloudRecord)
                merged += 1
            }
        }

        if merged > 0 {
            saveRecords(records)
            #if DEBUG
            print("🧠 Merged \(merged) SEL records from cloud")
            #endif
        }
    }

    // MARK: - Mock Data

    func seedMockData() {
        let records = loadRecords()
        guard records.isEmpty else { return }

        let today = Date()
        let formatter = SELAssessmentService.dateFormatter
        let isoFormatter = SELAssessmentService.iso8601Formatter

        struct MockDay {
            let offset: Int
            let scores: [SELDomain: Int]
            let checks: [SELCheckResult]
        }

        let mockDays: [MockDay] = [
            MockDay(offset: 6,
                scores: [.socialCommunication: 45, .emotionalIntelligence: 55, .cognitiveDevelopment: 50, .lifeSkills: 60, .languageDevelopment: 65],
                checks: buildMockChecks([(.socialCommunication, [1,2,1]), (.emotionalIntelligence, [2,2,1]), (.cognitiveDevelopment, [1,2,2]), (.lifeSkills, [2,2,2]), (.languageDevelopment, [2,2,2])])),
            MockDay(offset: 5,
                scores: [.socialCommunication: 50, .emotionalIntelligence: 58, .cognitiveDevelopment: 48, .lifeSkills: 62, .languageDevelopment: 67],
                checks: buildMockChecks([(.socialCommunication, [2,1,2]), (.emotionalIntelligence, [2,2,2]), (.cognitiveDevelopment, [1,2,1]), (.lifeSkills, [2,2,2]), (.languageDevelopment, [2,2,2])])),
            MockDay(offset: 4,
                scores: [.socialCommunication: 48, .emotionalIntelligence: 60, .cognitiveDevelopment: 45, .lifeSkills: 58, .languageDevelopment: 70],
                checks: buildMockChecks([(.socialCommunication, [1,2,2]), (.emotionalIntelligence, [2,2,2]), (.cognitiveDevelopment, [1,1,2]), (.lifeSkills, [2,2,1]), (.languageDevelopment, [2,3,2])])),
            MockDay(offset: 3,
                scores: [.socialCommunication: 55, .emotionalIntelligence: 62, .cognitiveDevelopment: 42, .lifeSkills: 65, .languageDevelopment: 72],
                checks: buildMockChecks([(.socialCommunication, [2,2,2]), (.emotionalIntelligence, [2,2,2]), (.cognitiveDevelopment, [1,1,2]), (.lifeSkills, [2,2,2]), (.languageDevelopment, [2,3,2])])),
            MockDay(offset: 2,
                scores: [.socialCommunication: 60, .emotionalIntelligence: 65, .cognitiveDevelopment: 38, .lifeSkills: 68, .languageDevelopment: 75],
                checks: buildMockChecks([(.socialCommunication, [2,2,2]), (.emotionalIntelligence, [2,2,3]), (.cognitiveDevelopment, [1,1,1]), (.lifeSkills, [2,2,3]), (.languageDevelopment, [2,3,2])])),
            MockDay(offset: 1,
                scores: [.socialCommunication: 58, .emotionalIntelligence: 70, .cognitiveDevelopment: 40, .lifeSkills: 70, .languageDevelopment: 78],
                checks: buildMockChecks([(.socialCommunication, [2,2,1]), (.emotionalIntelligence, [2,3,2]), (.cognitiveDevelopment, [1,1,2]), (.lifeSkills, [2,3,2]), (.languageDevelopment, [3,2,3])])),
            MockDay(offset: 0,
                scores: [.socialCommunication: 65, .emotionalIntelligence: 72, .cognitiveDevelopment: 42, .lifeSkills: 72, .languageDevelopment: 80],
                checks: buildMockChecks([(.socialCommunication, [2,2,3]), (.emotionalIntelligence, [3,2,2]), (.cognitiveDevelopment, [1,2,1]), (.lifeSkills, [2,3,2]), (.languageDevelopment, [3,2,3])])),
        ]

        let mockRecords: [SELDailyRecord] = mockDays.compactMap { day in
            guard let d = Calendar.current.date(byAdding: .day, value: -day.offset, to: today) else { return nil }
            let dateStr = formatter.string(from: d)
            return SELDailyRecord(
                id: UUID().uuidString,
                date: dateStr,
                completedAt: isoFormatter.string(from: d),
                domainScores: day.scores,
                checkResults: day.checks,
                mindfulnessCompleted: true
            )
        }

        saveRecords(mockRecords)
    }

    // MARK: - Helpers

    private func todayString() -> String {
        return SELAssessmentService.dateFormatter.string(from: Date())
    }

    private func buildMockChecks(_ items: [(SELDomain, [Int])]) -> [SELCheckResult] {
        var results: [SELCheckResult] = []
        for (domain, scores) in items {
            let competencies = competenciesForDomain(domain)
            for (j, score) in scores.enumerated() {
                results.append(SELCheckResult(
                    checkId: "mock-\(domain.rawValue)-\(j)",
                    domain: domain,
                    competency: competencies.indices.contains(j) ? competencies[j] : l("sel.mock.check_fallback"),
                    score: score
                ))
            }
        }
        return results
    }

    private func competenciesForDomain(_ domain: SELDomain) -> [String] {
        switch domain {
        case .socialCommunication: return [l("sel.competency.sc.1"), l("sel.competency.sc.2"), l("sel.competency.sc.3")]
        case .emotionalIntelligence: return [l("sel.competency.ei.1"), l("sel.competency.ei.2"), l("sel.competency.ei.3")]
        case .cognitiveDevelopment: return [l("sel.competency.cd.1"), l("sel.competency.cd.2"), l("sel.competency.cd.3")]
        case .lifeSkills: return [l("sel.competency.ls.1"), l("sel.competency.ls.2"), l("sel.competency.ls.3")]
        case .languageDevelopment: return [l("sel.competency.ld.1"), l("sel.competency.ld.2"), l("sel.competency.ld.3")]
        }
    }
}
#endif
