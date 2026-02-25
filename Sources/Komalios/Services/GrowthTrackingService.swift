#if os(iOS)
import Foundation
import Combine
import FirebaseAuth

final class GrowthTrackingService: ObservableObject {
    static let shared = GrowthTrackingService()

    @Published private(set) var milestones: [Milestone] = []
    @Published private(set) var todayActivity: DailyActivity?

    private let fileManager = FileManager.default
    private let fileName = "growth_data.json"
    private var growthData = GrowthData()

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var todayString: String {
        dateFormatter.string(from: Date())
    }

    private init() {
        loadData()
        milestones = growthData.milestones
        todayActivity = growthData.dailyActivities.first { $0.date == todayString }
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
            growthData = try JSONDecoder().decode(GrowthData.self, from: data)
            pruneOldActivities()
            print("🌱 Loaded growth data: \(growthData.dailyActivities.count) days, \(growthData.milestones.count) milestones")
        } catch {
            print("🌱 Error loading growth data: \(error)")
        }
    }

    private func saveData() {
        do {
            let data = try JSONEncoder().encode(growthData)
            try data.write(to: fileURL)
        } catch {
            print("🌱 Error saving growth data: \(error)")
            return
        }

        // Upload to Firestore (fire-and-forget)
        let currentData = growthData
        if let uid = Auth.auth().currentUser?.uid {
            Task {
                await FirestoreSyncService.shared.uploadGrowthData(uid: uid, data: currentData)
            }
        }
    }

    // MARK: - Activity Recording

    enum ActivityType {
        case chat
        case reflection
        case moodCheckIn
        case morningAnchor
        case eveningAnchor
    }

    /// Record an activity for today
    func recordActivity(type: ActivityType) {
        ensureTodayActivity()

        guard let index = growthData.dailyActivities.firstIndex(where: { $0.date == todayString }) else { return }

        switch type {
        case .chat:
            growthData.dailyActivities[index].chatCount += 1
        case .reflection:
            growthData.dailyActivities[index].reflectionCount += 1
        case .moodCheckIn:
            growthData.dailyActivities[index].moodCheckInCount += 1
        case .morningAnchor:
            growthData.dailyActivities[index].morningAnchorCompleted = true
        case .eveningAnchor:
            growthData.dailyActivities[index].eveningAnchorCompleted = true
        }

        todayActivity = growthData.dailyActivities[index]
        saveData()
        checkAndUpdateMilestones()
    }

    /// Record that a character was used
    func recordCharacterUsed(_ characterId: Int) {
        growthData.uniqueCharactersUsed.insert(characterId)
        saveData()
        checkAndUpdateMilestones()
    }

    // MARK: - App Open

    /// Update state when app opens. Call from KomaliosApp scenePhase .active
    func updateStreakOnAppOpen(retentionState: inout RetentionState) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastActive = retentionState.lastActiveDate {
            let lastDay = calendar.startOfDay(for: lastActive)
            let daysBetween = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

            // Intentionally increments by 1 regardless of gap size.
            // totalDaysActive counts distinct days the user opened the app,
            // not consecutive calendar days (that would be a streak counter).
            if daysBetween > 0 {
                retentionState.totalDaysActive += 1
            }
        } else {
            retentionState.totalDaysActive = 1
        }

        retentionState.lastActiveDate = Date()
        ensureTodayActivity()
        checkAndUpdateMilestones()
    }

    // MARK: - Milestones

    /// Check and update all milestone progress
    func checkAndUpdateMilestones() {
        let memoryService = ConversationMemoryService.shared
        let moodService = MoodTrackingService.shared

        // Chat milestones
        let totalChats = growthData.dailyActivities.reduce(0) { $0 + $1.chatCount }
        updateMilestoneProgress(id: "first_chat", progress: totalChats)
        updateMilestoneProgress(id: "chatty_friend", progress: totalChats)

        // Mood milestones
        let totalMoods = moodService.totalMoodCount()
        updateMilestoneProgress(id: "feeling_explorer", progress: totalMoods)
        updateMilestoneProgress(id: "mood_master", progress: totalMoods)

        // Reflection milestones
        let totalReflections = growthData.dailyActivities.reduce(0) { $0 + $1.reflectionCount }
        updateMilestoneProgress(id: "reflection_star", progress: totalReflections)

        // Character collector
        let uniqueChars = memoryService.getUniqueCharacterCount()
        updateMilestoneProgress(id: "character_collector", progress: uniqueChars)

        milestones = growthData.milestones
        saveData()
    }

    private func updateMilestoneProgress(id: String, progress: Int) {
        guard let index = growthData.milestones.firstIndex(where: { $0.id == id }) else { return }
        growthData.milestones[index].currentProgress = progress
        if progress >= growthData.milestones[index].requirement && growthData.milestones[index].earnedDate == nil {
            growthData.milestones[index].earnedDate = Date()
            print("🌱 Milestone earned: \(growthData.milestones[index].title)")
        }
    }

    /// Get earned milestones
    func getEarnedMilestones() -> [Milestone] {
        growthData.milestones.filter { $0.isEarned }
    }

    // MARK: - Weekly Snapshots

    func getWeeklySnapshots() -> [WeeklySnapshot] {
        growthData.weeklySnapshots.sorted { $0.weekStartDate > $1.weekStartDate }
    }

    // MARK: - Anchors

    func saveAnchor(_ anchor: DailyAnchor) {
        growthData.anchors.append(anchor)
        saveData()
    }

    func getAnchors(days: Int = 30) -> [DailyAnchor] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return growthData.anchors.filter { $0.timestamp >= cutoff }
    }

    /// Get anchor completion rate for last N days
    func getAnchorComplianceRate(days: Int = 30) -> (morning: Double, evening: Double) {
        let activities = growthData.dailyActivities.suffix(days)
        guard !activities.isEmpty else { return (0, 0) }
        let morningCount = activities.filter { $0.morningAnchorCompleted }.count
        let eveningCount = activities.filter { $0.eveningAnchorCompleted }.count
        return (
            morning: Double(morningCount) / Double(activities.count),
            evening: Double(eveningCount) / Double(activities.count)
        )
    }

    // MARK: - Activity Data

    func getDailyActivities(days: Int = 30) -> [DailyActivity] {
        let cutoff = dateFormatter.string(from: Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date())
        return growthData.dailyActivities.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
    }

    func getActiveDaysCount(days: Int = 30) -> Int {
        getDailyActivities(days: days).filter { $0.isActive }.count
    }

    // MARK: - Identity Progression

    /// Evaluate identity progression based on 14-day activity window
    func evaluateIdentityProgression(ageGroup: AgeGroup) {
        let activities = getDailyActivities(days: 14)
        let currentStage = growthData.identityProgression.currentStage

        // Age-differentiated thresholds
        let reflectionThreshold: Int
        let returnThreshold: Int
        let consistencyDays: Int

        switch ageGroup {
        case .under10:
            reflectionThreshold = 3
            returnThreshold = 7
            consistencyDays = 5
        case .tenToThirteen:
            reflectionThreshold = 5
            returnThreshold = 10
            consistencyDays = 7
        default:
            reflectionThreshold = 7
            returnThreshold = 12
            consistencyDays = 10
        }

        let totalReflections = activities.reduce(0) { $0 + $1.reflectionCount }
        let activeDays = activities.filter { $0.isActive }.count
        let totalChats = activities.reduce(0) { $0 + $1.chatCount }

        var newStage = currentStage
        var newTraits: [String] = growthData.identityProgression.observedTraits

        switch currentStage {
        case .explorer:
            // Explorer -> Thinker: reflected enough times in 14 days
            if totalReflections >= reflectionThreshold {
                newStage = .thinker
                if !newTraits.contains("Thoughtful reflector") {
                    newTraits.append("Thoughtful reflector")
                }
            }
        case .thinker:
            // Thinker -> Builder: enough voluntary returns + deeper reflections
            if activeDays >= returnThreshold && totalReflections >= reflectionThreshold * 2 {
                newStage = .builder
                if !newTraits.contains("Consistent grower") {
                    newTraits.append("Consistent grower")
                }
            }
        case .builder:
            // Builder -> Guide: consistent engagement + broad activity
            if activeDays >= consistencyDays && totalChats >= 15 && totalReflections >= reflectionThreshold * 2 {
                newStage = .guide
                if !newTraits.contains("Community contributor") {
                    newTraits.append("Community contributor")
                }
            }
        case .guide:
            // Already at max stage
            break
        }

        if newStage != currentStage {
            let entry = IdentityProgression.StageHistoryEntry(stage: newStage, reachedDate: Date())
            growthData.identityProgression.stageHistory.append(entry)
            growthData.identityProgression.currentStage = newStage
            growthData.identityProgression.stageReachedDate = Date()
            print("🌱 Identity stage advanced: \(currentStage.rawValue) -> \(newStage.rawValue)")
        }

        growthData.identityProgression.observedTraits = newTraits
        saveData()
    }

    /// Get current identity stage
    func getCurrentIdentityStage() -> IdentityStage {
        growthData.identityProgression.currentStage
    }

    /// Get identity narrative
    func getIdentityNarrative() -> String {
        let stage = growthData.identityProgression.currentStage
        return "\(stage.narrativePrefix) — \(stage.description)"
    }

    /// Get identity progression data
    func getIdentityProgression() -> IdentityProgression {
        growthData.identityProgression
    }

    // MARK: - Week-Over-Week Deltas

    /// Get week-over-week comparison (this week vs last week)
    func getWeekOverWeekDelta() -> (chatDelta: Int, reflectionDelta: Int, moodDelta: Int, activeDaysDelta: Int) {
        let thisWeek = getDailyActivities(days: 7)
        let allTwoWeeks = getDailyActivities(days: 14)

        // Last week = allTwoWeeks minus thisWeek
        let thisWeekDates = Set(thisWeek.map { $0.date })
        let lastWeek = allTwoWeeks.filter { !thisWeekDates.contains($0.date) }

        let thisChats = thisWeek.reduce(0) { $0 + $1.chatCount }
        let lastChats = lastWeek.reduce(0) { $0 + $1.chatCount }

        let thisReflections = thisWeek.reduce(0) { $0 + $1.reflectionCount }
        let lastReflections = lastWeek.reduce(0) { $0 + $1.reflectionCount }

        let thisMoods = thisWeek.reduce(0) { $0 + $1.moodCheckInCount }
        let lastMoods = lastWeek.reduce(0) { $0 + $1.moodCheckInCount }

        let thisActive = thisWeek.filter { $0.isActive }.count
        let lastActive = lastWeek.filter { $0.isActive }.count

        return (
            chatDelta: thisChats - lastChats,
            reflectionDelta: thisReflections - lastReflections,
            moodDelta: thisMoods - lastMoods,
            activeDaysDelta: thisActive - lastActive
        )
    }

    // MARK: - Cloud Sync

    /// Merge growth data downloaded from Firestore.
    /// Merges daily activities by date, milestones by ID, takes higher identity stage.
    func mergeCloudData(_ cloudData: GrowthData) {
        // Merge daily activities by date
        let localDates = Set(growthData.dailyActivities.map { $0.date })
        let newActivities = cloudData.dailyActivities.filter { !localDates.contains($0.date) }
        if !newActivities.isEmpty {
            growthData.dailyActivities.append(contentsOf: newActivities)
            growthData.dailyActivities.sort { $0.date < $1.date }
        }

        // Merge milestones by ID (keep higher progress / earlier earned date)
        for cloudMilestone in cloudData.milestones {
            if let idx = growthData.milestones.firstIndex(where: { $0.id == cloudMilestone.id }) {
                if cloudMilestone.currentProgress > growthData.milestones[idx].currentProgress {
                    growthData.milestones[idx].currentProgress = cloudMilestone.currentProgress
                }
                if let cloudEarned = cloudMilestone.earnedDate, growthData.milestones[idx].earnedDate == nil {
                    growthData.milestones[idx].earnedDate = cloudEarned
                }
            }
        }

        // Merge weekly snapshots by weekStartDate
        let localWeeks = Set(growthData.weeklySnapshots.map { $0.weekStartDate })
        let newSnapshots = cloudData.weeklySnapshots.filter { !localWeeks.contains($0.weekStartDate) }
        if !newSnapshots.isEmpty {
            growthData.weeklySnapshots.append(contentsOf: newSnapshots)
        }

        // Merge anchors by ID
        let localAnchorIDs = Set(growthData.anchors.map { $0.id })
        let newAnchors = cloudData.anchors.filter { !localAnchorIDs.contains($0.id) }
        if !newAnchors.isEmpty {
            growthData.anchors.append(contentsOf: newAnchors)
        }

        // Merge unique characters used
        growthData.uniqueCharactersUsed.formUnion(cloudData.uniqueCharactersUsed)

        // Take higher identity stage (compare by allCases index)
        let allStages = IdentityStage.allCases
        let localIndex = allStages.firstIndex(of: growthData.identityProgression.currentStage) ?? 0
        let cloudIndex = allStages.firstIndex(of: cloudData.identityProgression.currentStage) ?? 0
        if cloudIndex > localIndex {
            growthData.identityProgression = cloudData.identityProgression
        }

        milestones = growthData.milestones
        todayActivity = growthData.dailyActivities.first { $0.date == todayString }

        // Save locally without triggering another cloud upload
        do {
            let data = try JSONEncoder().encode(growthData)
            try data.write(to: fileURL)
        } catch {
            print("🌱 Error saving merged growth data: \(error)")
        }
        print("🌱 Merged cloud growth data")
    }

    // MARK: - Helpers

    private func ensureTodayActivity() {
        if !growthData.dailyActivities.contains(where: { $0.date == todayString }) {
            growthData.dailyActivities.append(DailyActivity(date: todayString))
        }
    }

    private func pruneOldActivities() {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -365, to: Date()) ?? Date()
        let cutoffString = dateFormatter.string(from: cutoffDate)
        let before = growthData.dailyActivities.count
        growthData.dailyActivities.removeAll { $0.date < cutoffString }
        if growthData.dailyActivities.count < before {
            saveData()
        }
    }
}
#endif
