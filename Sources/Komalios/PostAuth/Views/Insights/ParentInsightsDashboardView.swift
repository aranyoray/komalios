#if os(iOS)
import SwiftUI
import Charts

struct ParentInsightsDashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var moodService = MoodTrackingService.shared
    @ObservedObject private var growthService = GrowthTrackingService.shared

    @State private var conversationStarter: String? = nil
    @State private var dailyInsight: String? = nil
    @State private var isLoadingStarter = false
    @State private var isLoadingInsight = false

    var body: some View {
        NavigationView {
            ZStack {
                KomalColors.warmGray
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Growth Deltas (week-over-week)
                        growthDeltasSection

                        // Conversation Starter
                        conversationStarterSection

                        // Daily Insight
                        dailyInsightSection

                        // Emotional Wellness
                        emotionalWellnessSection

                        // Conversation Insights
                        conversationInsightsSection

                        // Growth Metrics
                        growthMetricsSection

                        // Retention Metrics
                        retentionMetricsSection

                        // Anchor Compliance
                        anchorComplianceSection

                        // Alerts
                        alertsSection

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Child Wellness")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                }
            }
            .onAppear {
                // Track parent view
                appState.retentionState.parentViewCount += 1
                appState.retentionState.lastParentViewDate = Date()
                appState.savePreferences()

                // Load AI-generated content
                loadConversationStarter()
                loadDailyInsight()
            }
        }
    }

    // MARK: - Growth Deltas (Week-over-Week)

    private var growthDeltasSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 16) {
                CardHeader(icon: "arrow.up.arrow.down", title: "This Week vs Last", color: KomalColors.pearlAqua)

                let delta = growthService.getWeekOverWeekDelta()

                HStack(spacing: 12) {
                    DeltaStatView(label: "Chats", delta: delta.chatDelta, color: KomalColors.bubblegumPink)
                    DeltaStatView(label: "Reflections", delta: delta.reflectionDelta, color: KomalColors.lavenderPurple)
                    DeltaStatView(label: "Moods", delta: delta.moodDelta, color: .orange)
                    DeltaStatView(label: "Active Days", delta: delta.activeDaysDelta, color: KomalColors.pearlAqua)
                }
            }
        }
    }

    // MARK: - Conversation Starter

    private var conversationStarterSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(icon: "text.bubble.fill", title: "Tonight's Conversation Starter", color: KomalColors.lavenderPurple)

                if isLoadingStarter {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Generating a conversation starter...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(KomalColors.textSecondary)
                    }
                } else if let starter = conversationStarter {
                    Text(starter)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.textPrimary)
                        .lineSpacing(4)
                } else {
                    Text("Use the app for a few days to get personalized conversation starters.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(KomalColors.textSecondary)
                }
            }
        }
    }

    // MARK: - Daily Insight

    private var dailyInsightSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(icon: "lightbulb.fill", title: "Daily Insight", color: .orange)

                if isLoadingInsight {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Generating insight...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(KomalColors.textSecondary)
                    }
                } else if let insight = dailyInsight {
                    Text(insight)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.textPrimary)
                        .lineSpacing(4)
                } else {
                    Text("Insights will appear as your child uses the app more.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(KomalColors.textSecondary)
                }
            }
        }
    }

    // MARK: - Emotional Wellness

    private var emotionalWellnessSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 16) {
                CardHeader(icon: "heart.circle.fill", title: "Emotional Wellness", color: KomalColors.bubblegumPink)

                // Mood trend (last 7 days)
                let trend = moodService.getMoodTrend(days: 7)
                if !trend.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last 7 Days")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(KomalColors.textSecondary)

                        HStack(spacing: 8) {
                            ForEach(trend, id: \.date) { entry in
                                VStack(spacing: 4) {
                                    Text(entry.emoji)
                                        .font(.system(size: 24))
                                    Text(String(entry.date.suffix(5)))
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(KomalColors.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }

                // Emotion distribution
                let distribution = moodService.getEmotionDistribution(days: 30)
                if !distribution.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("30-Day Emotion Distribution")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(KomalColors.textSecondary)

                        let sorted = distribution.sorted { $0.value > $1.value }
                        ForEach(sorted.prefix(5), id: \.key) { emotion, count in
                            HStack {
                                Text(emotion)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(KomalColors.textPrimary)
                                    .frame(width: 80, alignment: .leading)

                                GeometryReader { geo in
                                    let maxCount = sorted.first?.value ?? 1
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(KomalColors.lavenderPurple.opacity(0.6))
                                        .frame(width: geo.size.width * CGFloat(count) / CGFloat(maxCount))
                                }
                                .frame(height: 16)

                                Text("\(count)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(KomalColors.textSecondary)
                                    .frame(width: 30, alignment: .trailing)
                            }
                        }
                    }
                }

                if trend.isEmpty && distribution.isEmpty {
                    Text("No mood data yet. Mood entries will appear here as your child uses the app.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(KomalColors.textSecondary)
                }
            }
        }
    }

    // MARK: - Conversation Insights

    private var conversationInsightsSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 16) {
                CardHeader(icon: "bubble.left.and.bubble.right.fill", title: "Conversation Insights", color: KomalColors.lavenderPurple)

                let memoryService = ConversationMemoryService.shared
                let totalMessages = memoryService.totalMessageCount()

                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("\(totalMessages)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(KomalColors.lavenderPurple)
                        Text("Messages")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(KomalColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Text("\(memoryService.getUniqueCharacterCount())")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(KomalColors.bubblegumPink)
                        Text("Characters Used")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(KomalColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                // Top topics
                let topics = memoryService.getConversationTopics(days: 30)
                if !topics.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Popular Topics")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(KomalColors.textSecondary)

                        FlowLayout(spacing: 8) {
                            ForEach(topics.sorted(by: { $0.value > $1.value }).prefix(8), id: \.key) { topic, count in
                                Text(topic)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(KomalColors.lavenderPurple)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(KomalColors.lavenderPurple.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Growth Metrics

    private var growthMetricsSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 16) {
                CardHeader(icon: "flame.fill", title: "Growth Metrics", color: .orange)

                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("\(growthService.currentStreak)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                        Text("Current Streak")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(KomalColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Text("\(growthService.getEarnedMilestones().count)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(KomalColors.pearlAqua)
                        Text("Milestones")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(KomalColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Text("\(growthService.getActiveDaysCount())")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(KomalColors.lavenderPurple)
                        Text("Active Days (30d)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(KomalColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                // Activity heatmap (last 30 days simplified as dots)
                let activities = growthService.getDailyActivities(days: 30)
                if !activities.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("30-Day Activity")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(KomalColors.textSecondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                            ForEach(0..<30, id: \.self) { dayOffset in
                                let calendar = Calendar.current
                                let date = calendar.date(byAdding: .day, value: -(29 - dayOffset), to: Date()) ?? Date()
                                let formatter = DateFormatter()
                                let _ = formatter.dateFormat = "yyyy-MM-dd"
                                let dateStr = formatter.string(from: date)
                                let activity = activities.first(where: { $0.date == dateStr })
                                let isActive = activity?.isActive ?? false

                                RoundedRectangle(cornerRadius: 3)
                                    .fill(isActive ? KomalColors.pearlAqua : Color.gray.opacity(0.1))
                                    .frame(height: 16)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Retention Metrics

    private var retentionMetricsSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 16) {
                CardHeader(icon: "chart.line.uptrend.xyaxis", title: "Engagement Quality", color: KomalColors.pearlAqua)

                let state = appState.retentionState

                HStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Text("\(Int(state.voluntaryReturnRate * 100))%")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(KomalColors.pearlAqua)
                        Text("Voluntary Returns")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(KomalColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Text(String(format: "%.1f", state.averageReflectionDepth))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(KomalColors.lavenderPurple)
                        Text("Avg Reflection Depth")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(KomalColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Text("\(state.childInitiatedSessionCount)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(KomalColors.bubblegumPink)
                        Text("Total Sessions")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(KomalColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }

                Text("Higher voluntary return rates indicate genuine engagement rather than notification-driven usage.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(KomalColors.textSecondary)
                    .lineSpacing(2)
            }
        }
    }

    // MARK: - Anchor Compliance

    private var anchorComplianceSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 16) {
                CardHeader(icon: "clock.fill", title: "Daily Check-ins", color: KomalColors.pearlAqua)

                let compliance = growthService.getAnchorComplianceRate()

                HStack(spacing: 24) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.1), lineWidth: 6)
                                .frame(width: 60, height: 60)
                            Circle()
                                .trim(from: 0, to: compliance.morning)
                                .stroke(KomalColors.bubblegumPink, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .frame(width: 60, height: 60)
                                .rotationEffect(.degrees(-90))
                            Text("\(Int(compliance.morning * 100))%")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(KomalColors.textPrimary)
                        }
                        Text("Morning")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(KomalColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.1), lineWidth: 6)
                                .frame(width: 60, height: 60)
                            Circle()
                                .trim(from: 0, to: compliance.evening)
                                .stroke(KomalColors.lavenderPurple, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .frame(width: 60, height: 60)
                                .rotationEffect(.degrees(-90))
                            Text("\(Int(compliance.evening * 100))%")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(KomalColors.textPrimary)
                        }
                        Text("Evening")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(KomalColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Alerts

    private var alertsSection: some View {
        Group {
            if moodService.hasConsecutiveSadEntries() {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        CardHeader(icon: "exclamationmark.triangle.fill", title: "Wellness Alert", color: .orange)

                        Text("Your child has reported feeling sad for 3 or more consecutive check-ins. Consider having a gentle conversation about how they're feeling.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)
                            .lineSpacing(4)
                    }
                }
            }
        }
    }

    // MARK: - AI Content Loading

    private func loadConversationStarter() {
        let topics = ConversationMemoryService.shared.getRecentTopics(days: 7)
        let recentMoods = moodService.recentEntries.prefix(5).map { $0.emotion }

        guard !topics.isEmpty || !recentMoods.isEmpty else { return }

        isLoadingStarter = true
        let ageGroup = appState.activeProfile.ageGroup

        Task {
            do {
                let gemini = GeminiChatService()
                let starter = try await gemini.generateConversationStarter(
                    childTopics: topics,
                    recentMoods: Array(recentMoods),
                    ageGroup: ageGroup
                )
                await MainActor.run {
                    isLoadingStarter = false
                    conversationStarter = starter
                }
            } catch {
                await MainActor.run {
                    isLoadingStarter = false
                }
            }
        }
    }

    private func loadDailyInsight() {
        let delta = growthService.getWeekOverWeekDelta()
        let weeklyData = "Chats: \(delta.chatDelta >= 0 ? "+\(delta.chatDelta)" : "\(delta.chatDelta)"), Reflections: \(delta.reflectionDelta >= 0 ? "+\(delta.reflectionDelta)" : "\(delta.reflectionDelta)"), Active days: \(delta.activeDaysDelta >= 0 ? "+\(delta.activeDaysDelta)" : "\(delta.activeDaysDelta)"), Streak: \(growthService.currentStreak)"

        isLoadingInsight = true

        Task {
            do {
                let gemini = GeminiChatService()
                let insight = try await gemini.generateDailyParentInsight(weeklyData: weeklyData)
                await MainActor.run {
                    isLoadingInsight = false
                    dailyInsight = insight
                }
            } catch {
                await MainActor.run {
                    isLoadingInsight = false
                }
            }
        }
    }
}

// MARK: - Delta Stat View

struct DeltaStatView: View {
    let label: String
    let delta: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                if delta > 0 {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(KomalColors.pearlAqua)
                } else if delta < 0 {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.orange)
                }

                Text(delta >= 0 ? "+\(delta)" : "\(delta)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(delta >= 0 ? KomalColors.pearlAqua : .orange)
            }

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(KomalColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
#endif
