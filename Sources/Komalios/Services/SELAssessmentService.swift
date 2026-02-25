#if os(iOS)
import Foundation
import Combine
import FirebaseAuth

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
            print("🧠 Error loading SEL records: \(error)")
            return []
        }
    }

    private func saveRecords(_ records: [SELDailyRecord]) {
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: fileURL)
        } catch {
            print("🧠 Error saving SEL records: \(error)")
        }
    }

    // MARK: - Scenario Pools

    private let socialCommunicationScenarios: [SELScenario] = [
        SELScenario(
            id: "sc1", domain: .socialCommunication,
            title: "New Friend at School",
            narrative: "A new kid joins your class and sits alone at lunch. Nobody has talked to them yet.",
            emoji: "🏫",
            checks: [
                SELCheck(id: "sc1-1", competency: "Initiates greetings",
                    question: "What would you do when you see them sitting alone?",
                    options: [
                        SELOption(text: "Walk over and say hi, introduce myself", emoji: "👋", score: 3),
                        SELOption(text: "Smile at them from my table", emoji: "🙂", score: 2),
                        SELOption(text: "Keep eating with my friends", emoji: "🍽", score: 1),
                    ]),
                SELCheck(id: "sc1-2", competency: "Starts conversation on a topic of interest",
                    question: "They tell you they like drawing. What would you say?",
                    options: [
                        SELOption(text: "Cool! I like drawing too! What do you draw?", emoji: "🎨", score: 3),
                        SELOption(text: "That's nice", emoji: "👍", score: 2),
                        SELOption(text: "Oh, okay", emoji: "😐", score: 1),
                    ]),
                SELCheck(id: "sc1-3", competency: "Responds to invitations of peers",
                    question: "They ask if you want to draw together after school.",
                    options: [
                        SELOption(text: "Yes! Let me ask my parents first", emoji: "✅", score: 3),
                        SELOption(text: "Maybe another time", emoji: "🤔", score: 2),
                        SELOption(text: "I don't know...", emoji: "😕", score: 1),
                    ]),
            ]),
        SELScenario(
            id: "sc2", domain: .socialCommunication,
            title: "The Group Project",
            narrative: "Your teacher puts you in a group with kids you don't usually play with for a project.",
            emoji: "📚",
            checks: [
                SELCheck(id: "sc2-1", competency: "Introduces self to new people",
                    question: "How would you start working with the new group?",
                    options: [
                        SELOption(text: "Hi everyone! I'm excited to work together. What should we do first?", emoji: "🙋", score: 3),
                        SELOption(text: "Wait for someone else to start talking", emoji: "⏳", score: 2),
                        SELOption(text: "Stay quiet and hope they tell me what to do", emoji: "🤐", score: 1),
                    ]),
                SELCheck(id: "sc2-2", competency: "Gives compliments or positive statements",
                    question: "One of the kids shares a really good idea for the project.",
                    options: [
                        SELOption(text: "That's a great idea! I think we should use it", emoji: "🌟", score: 3),
                        SELOption(text: "Nod and say nothing", emoji: "👍", score: 2),
                        SELOption(text: "I think my idea is better", emoji: "🙅", score: 1),
                    ]),
                SELCheck(id: "sc2-3", competency: "Offers assistance to others",
                    question: "You notice someone in the group is struggling with their part.",
                    options: [
                        SELOption(text: "Do you want me to help you with that?", emoji: "🤝", score: 3),
                        SELOption(text: "Tell the teacher they need help", emoji: "📢", score: 2),
                        SELOption(text: "Focus on my own work", emoji: "📝", score: 1),
                    ]),
            ]),
    ]

    private let emotionalIntelligenceScenarios: [SELScenario] = [
        SELScenario(
            id: "ei1", domain: .emotionalIntelligence,
            title: "The Ice Cream Incident",
            narrative: "Your friend just dropped their ice cream cone on the ground. It was their favorite flavor and they'd been waiting all day for it.",
            emoji: "🍦",
            checks: [
                SELCheck(id: "ei1-1", competency: "Identifies simple emotions",
                    question: "How do you think your friend is feeling right now?",
                    options: [
                        SELOption(text: "Sad and disappointed", emoji: "😢", score: 3),
                        SELOption(text: "Angry", emoji: "😠", score: 2),
                        SELOption(text: "I'm not sure", emoji: "🤷", score: 1),
                    ]),
                SELCheck(id: "ei1-2", competency: "Understands reason for feelings",
                    question: "Why do you think they feel that way?",
                    options: [
                        SELOption(text: "They were excited about it and now it's gone", emoji: "💭", score: 3),
                        SELOption(text: "Because ice cream is yummy", emoji: "🍨", score: 2),
                        SELOption(text: "I don't know why", emoji: "❓", score: 1),
                    ]),
                SELCheck(id: "ei1-3", competency: "Comforts someone who is hurt",
                    question: "What would you do to help your friend feel better?",
                    options: [
                        SELOption(text: "Offer to share mine or help get a new one", emoji: "💛", score: 3),
                        SELOption(text: "Tell them it's okay, don't worry", emoji: "🙏", score: 2),
                        SELOption(text: "It's just ice cream, no big deal", emoji: "🤷", score: 1),
                    ]),
            ]),
        SELScenario(
            id: "ei2", domain: .emotionalIntelligence,
            title: "The Talent Show",
            narrative: "Your friend practiced really hard for the talent show but forgot their lines on stage and had to stop. They come backstage looking upset.",
            emoji: "🎭",
            checks: [
                SELCheck(id: "ei2-1", competency: "Recognizes nonverbal cues",
                    question: "Your friend is looking at the ground with clenched fists. What does their body language tell you?",
                    options: [
                        SELOption(text: "They're feeling embarrassed and frustrated", emoji: "😔", score: 3),
                        SELOption(text: "They're angry at the audience", emoji: "😠", score: 2),
                        SELOption(text: "They're tired", emoji: "😴", score: 1),
                    ]),
                SELCheck(id: "ei2-2", competency: "Understanding complex feelings",
                    question: "Why might they feel more than just sad?",
                    options: [
                        SELOption(text: "They feel embarrassed because everyone was watching, and disappointed because they practiced so hard", emoji: "💡", score: 3),
                        SELOption(text: "Because they didn't win", emoji: "🏆", score: 2),
                        SELOption(text: "Because the show was boring", emoji: "🥱", score: 1),
                    ]),
                SELCheck(id: "ei2-3", competency: "Accepts and supports emotional experiences",
                    question: "What would you say to your friend?",
                    options: [
                        SELOption(text: "That took real courage. I'm proud of you for trying!", emoji: "💪", score: 3),
                        SELOption(text: "Don't worry, everyone forgets sometimes", emoji: "😊", score: 2),
                        SELOption(text: "You should have practiced more", emoji: "📖", score: 1),
                    ]),
            ]),
    ]

    private let cognitiveDevelopmentScenarios: [SELScenario] = [
        SELScenario(
            id: "cd1", domain: .cognitiveDevelopment,
            title: "The Lost Pet",
            narrative: "Your neighbor's cat went missing. They're looking everywhere but can't find it.",
            emoji: "🐱",
            checks: [
                SELCheck(id: "cd1-1", competency: "Identifies when to seek help",
                    question: "What is the first thing you should do to help?",
                    options: [
                        SELOption(text: "Ask the neighbor where the cat was last seen and make a plan", emoji: "🔎", score: 3),
                        SELOption(text: "Start looking around randomly", emoji: "🏃", score: 2),
                        SELOption(text: "Wait and hope the cat comes home", emoji: "🏠", score: 1),
                    ]),
                SELCheck(id: "cd1-2", competency: "Describes steps in sequence",
                    question: "How would you organize a search plan?",
                    options: [
                        SELOption(text: "First check the house, then the yard, then ask neighbors, and put up posters", emoji: "📋", score: 3),
                        SELOption(text: "Look in the nearest spots", emoji: "👀", score: 2),
                        SELOption(text: "I wouldn't know where to start", emoji: "🤷", score: 1),
                    ]),
                SELCheck(id: "cd1-3", competency: "Problem solving with before/after reasoning",
                    question: "It rained last night. Where might the cat have gone to stay dry?",
                    options: [
                        SELOption(text: "Under a porch, in a garage, or somewhere sheltered — cats don't like getting wet", emoji: "🏚", score: 3),
                        SELOption(text: "Maybe in a tree?", emoji: "🌳", score: 2),
                        SELOption(text: "I don't know, cats go anywhere", emoji: "🐈", score: 1),
                    ]),
            ]),
        SELScenario(
            id: "cd2", domain: .cognitiveDevelopment,
            title: "The Bake Sale",
            narrative: "Your class is having a bake sale to raise money. You want to help by making cookies.",
            emoji: "🍪",
            checks: [
                SELCheck(id: "cd2-1", competency: "Follows a schedule for activities",
                    question: "The bake sale is on Friday. It's Tuesday. When should you start baking?",
                    options: [
                        SELOption(text: "Thursday evening, so they're fresh. I need to get ingredients on Wednesday", emoji: "📅", score: 3),
                        SELOption(text: "Friday morning before school", emoji: "⏰", score: 2),
                        SELOption(text: "Whenever my parent tells me to", emoji: "👨", score: 1),
                    ]),
                SELCheck(id: "cd2-2", competency: "Explains money concepts",
                    question: "Each cookie costs 50 cents to make. How much should you sell them for?",
                    options: [
                        SELOption(text: "More than 50 cents, like $1, so we make money for the school", emoji: "💰", score: 3),
                        SELOption(text: "50 cents each", emoji: "🪙", score: 2),
                        SELOption(text: "Give them away for free", emoji: "🎁", score: 1),
                    ]),
                SELCheck(id: "cd2-3", competency: "Identifies morning/afternoon/nighttime appropriately",
                    question: "You made 24 cookies. By noon you sold 18. How many are left?",
                    options: [
                        SELOption(text: "6 cookies. I should lower the price to sell them before school ends", emoji: "🧮", score: 3),
                        SELOption(text: "Some are left, I'll keep trying", emoji: "👍", score: 2),
                        SELOption(text: "I'm not sure, math is hard", emoji: "😟", score: 1),
                    ]),
            ]),
    ]

    private let lifeSkillsScenarios: [SELScenario] = [
        SELScenario(
            id: "ls1", domain: .lifeSkills,
            title: "Walking Home",
            narrative: "You're walking to the park with your friend. It's a route you know well, but today the usual path is blocked by construction.",
            emoji: "🚶",
            checks: [
                SELCheck(id: "ls1-1", competency: "Looks both ways to cross street",
                    question: "You need to cross the street. What's the safest way?",
                    options: [
                        SELOption(text: "Stop at the crosswalk, look left, right, and left again, then cross when clear", emoji: "🚦", score: 3),
                        SELOption(text: "Look both ways quickly and cross", emoji: "👁", score: 2),
                        SELOption(text: "Cross wherever, cars will stop", emoji: "🚶", score: 1),
                    ]),
                SELCheck(id: "ls1-2", competency: "States dangerous situations",
                    question: "A stranger in a car pulls over and asks if you need a ride. What do you do?",
                    options: [
                        SELOption(text: "Say no thank you, keep walking, and tell a trusted adult right away", emoji: "🛑", score: 3),
                        SELOption(text: "Ignore them and walk faster", emoji: "🏃", score: 2),
                        SELOption(text: "Ask where they're going", emoji: "❓", score: 1),
                    ]),
                SELCheck(id: "ls1-3", competency: "Walks to familiar places safely",
                    question: "The usual path is blocked. What's the best choice?",
                    options: [
                        SELOption(text: "Take the other route I know, or call my parents for help", emoji: "📱", score: 3),
                        SELOption(text: "Try to go around the construction", emoji: "🚧", score: 2),
                        SELOption(text: "Go through the construction site, it's faster", emoji: "⚠️", score: 1),
                    ]),
            ]),
        SELScenario(
            id: "ls2", domain: .lifeSkills,
            title: "Getting Ready for School",
            narrative: "It's morning and you need to get ready for school. Your parent is busy with your younger sibling.",
            emoji: "☀️",
            checks: [
                SELCheck(id: "ls2-1", competency: "Understands personal hygiene",
                    question: "What should you do first when you wake up?",
                    options: [
                        SELOption(text: "Brush my teeth, wash my face, and get dressed", emoji: "🪥", score: 3),
                        SELOption(text: "Get dressed", emoji: "👕", score: 2),
                        SELOption(text: "Watch TV until someone tells me what to do", emoji: "📺", score: 1),
                    ]),
                SELCheck(id: "ls2-2", competency: "Knows appropriate clothes for occasions",
                    question: "It's raining today and you have PE class. What should you wear?",
                    options: [
                        SELOption(text: "Rain jacket, sneakers for PE, and bring extra socks", emoji: "🌧", score: 3),
                        SELOption(text: "My regular clothes", emoji: "👕", score: 2),
                        SELOption(text: "Whatever is on my floor", emoji: "🤷", score: 1),
                    ]),
                SELCheck(id: "ls2-3", competency: "Understands healthy food",
                    question: "You need to pack your own lunch today. What would you choose?",
                    options: [
                        SELOption(text: "Sandwich, fruit, water bottle, and a small snack", emoji: "🥪", score: 3),
                        SELOption(text: "Whatever snacks I can find", emoji: "🍫", score: 2),
                        SELOption(text: "I'll just buy chips at school", emoji: "🍟", score: 1),
                    ]),
            ]),
    ]

    private let languageDevelopmentScenarios: [SELScenario] = [
        SELScenario(
            id: "ld1", domain: .languageDevelopment,
            title: "Show and Tell",
            narrative: "It's Show and Tell day. You brought your favorite toy robot to share with the class.",
            emoji: "🤖",
            checks: [
                SELCheck(id: "ld1-1", competency: "Labels and describes events or items",
                    question: "How would you describe your robot to the class?",
                    options: [
                        SELOption(text: "This is Robo. It's a red robot with blue lights. It can walk and make sounds when you press the button on its back", emoji: "🎙", score: 3),
                        SELOption(text: "This is my robot. It's cool and it moves", emoji: "🤖", score: 2),
                        SELOption(text: "It's a robot", emoji: "😐", score: 1),
                    ]),
                SELCheck(id: "ld1-2", competency: "Answers what/where questions",
                    question: "Your classmate asks \"Where did you get it and what does it do?\"",
                    options: [
                        SELOption(text: "My grandma gave it to me for my birthday. It walks forward when you turn it on and its eyes light up!", emoji: "💬", score: 3),
                        SELOption(text: "I got it as a present. It walks.", emoji: "🎁", score: 2),
                        SELOption(text: "I don't remember", emoji: "🤷", score: 1),
                    ]),
                SELCheck(id: "ld1-3", competency: "Tells about experiences",
                    question: "Your teacher asks you to share a fun memory with your robot.",
                    options: [
                        SELOption(text: "One time I brought it to the park and my dog thought it was real! She kept barking and running around it. It was so funny!", emoji: "😂", score: 3),
                        SELOption(text: "I play with it a lot at home", emoji: "🏠", score: 2),
                        SELOption(text: "It's fun", emoji: "🙂", score: 1),
                    ]),
            ]),
        SELScenario(
            id: "ld2", domain: .languageDevelopment,
            title: "The Birthday Party",
            narrative: "You went to an amazing birthday party over the weekend. Your friend wants to hear all about it!",
            emoji: "🎂",
            checks: [
                SELCheck(id: "ld2-1", competency: "Describes steps in sequence",
                    question: "Tell your friend what happened at the party from start to finish.",
                    options: [
                        SELOption(text: "First we played games, then we had pizza, after that we had cake, and at the end we got party bags to take home!", emoji: "🎉", score: 3),
                        SELOption(text: "We played games and had cake", emoji: "🍰", score: 2),
                        SELOption(text: "It was fun", emoji: "👍", score: 1),
                    ]),
                SELCheck(id: "ld2-2", competency: "Labels social interaction behaviour",
                    question: "What was happening when everyone started laughing at the party?",
                    options: [
                        SELOption(text: "The birthday kid opened a present and it was a silly hat — everyone was laughing and being playful together", emoji: "🎩", score: 3),
                        SELOption(text: "Someone told a joke", emoji: "😆", score: 2),
                        SELOption(text: "I forget", emoji: "😔", score: 1),
                    ]),
                SELCheck(id: "ld2-3", competency: "Describes people encountered",
                    question: "You met your friend's cousin at the party. Tell me about them.",
                    options: [
                        SELOption(text: "Her name is Maya. She's really tall and has curly hair. She was really funny and taught us a new game!", emoji: "👫", score: 3),
                        SELOption(text: "She was nice", emoji: "😊", score: 2),
                        SELOption(text: "I don't remember much", emoji: "🤷", score: 1),
                    ]),
            ]),
    ]

    private var allScenarios: [SELDomain: [SELScenario]] {
        [
            .socialCommunication: socialCommunicationScenarios,
            .emotionalIntelligence: emotionalIntelligenceScenarios,
            .cognitiveDevelopment: cognitiveDevelopmentScenarios,
            .lifeSkills: lifeSkillsScenarios,
            .languageDevelopment: languageDevelopmentScenarios,
        ]
    }

    // MARK: - Session Logic

    func getDailyScenarios() -> [SELScenario] {
        allScenarios.values.map { pool in
            pool[Int.random(in: 0..<pool.count)]
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
                insight: "Complete your first SEL session to start tracking growth."
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
            } / Double(firstHalf.count)
            let avgSecond = secondHalf.reduce(0.0) { acc, record in
                let vals = record.domainScores.values
                return acc + (vals.isEmpty ? 0.0 : Double(vals.reduce(0, +)) / Double(vals.count))
            } / Double(secondHalf.count)
            if avgSecond - avgFirst > 3 { trend = .improving }
            else if avgFirst - avgSecond > 3 { trend = .declining }
        }

        let growthAreaNames = growthAreas.map { $0.label }
        let strengthNames = strengths.map { $0.label }

        let insight: String
        if trend == .improving {
            insight = "Great progress! \(strengthNames.isEmpty ? "" : "Strong in \(strengthNames.prefix(2).joined(separator: " and ")).")"
        } else if !growthAreas.isEmpty {
            insight = "\(growthAreaNames.joined(separator: " and ")) \(growthAreas.count == 1 ? "needs" : "need") more support. Consider more practice in \(growthAreas.count == 1 ? "this area" : "these areas")."
        } else {
            insight = "Well-balanced development across all domains. Keep it up!"
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
                let localAvg = local.domainScores.values.isEmpty ? 0 : local.domainScores.values.reduce(0, +) / local.domainScores.values.count
                let cloudAvg = cloudRecord.domainScores.values.isEmpty ? 0 : cloudRecord.domainScores.values.reduce(0, +) / cloudRecord.domainScores.values.count
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
            print("🧠 Merged \(merged) SEL records from cloud")
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

        let mockRecords: [SELDailyRecord] = mockDays.map { day in
            let d = Calendar.current.date(byAdding: .day, value: -day.offset, to: today)!
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
                    competency: competencies.indices.contains(j) ? competencies[j] : "Check \(j + 1)",
                    score: score
                ))
            }
        }
        return results
    }

    private func competenciesForDomain(_ domain: SELDomain) -> [String] {
        switch domain {
        case .socialCommunication: return ["Initiates greetings", "Starts conversations", "Responds to invitations"]
        case .emotionalIntelligence: return ["Identifies emotions", "Understands feelings", "Shows empathy"]
        case .cognitiveDevelopment: return ["Problem solving", "Sequential thinking", "Logical reasoning"]
        case .lifeSkills: return ["Safety awareness", "Self-care routines", "Healthy choices"]
        case .languageDevelopment: return ["Describes events", "Answers questions", "Shares experiences"]
        }
    }
}
#endif
