//
//  InsightsView.swift
//  Komalios
//
//  Browsing insights report with professional charts
//

#if os(iOS)
import SwiftUI
import Charts

struct InsightsView: View {
    @StateObject private var viewModel = InsightsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Summary Stats Cards
                    SummaryStatsSection(insights: viewModel.insights)
                    
                    // Digital Guardian Enhancement: Protection Stats
                    ProtectionStatsSection(
                        imagesFiltered: viewModel.imagesFiltered,
                        imagesScanned: viewModel.imagesScanned,
                        sitesBlocked: viewModel.insights.totalBlockedCount
                    )
                    
                    // Digital Guardian Enhancement: Content Viewed
                    ContentViewedSection(
                        contentInsights: viewModel.contentInsights,
                        recentPages: viewModel.recentPageSummaries
                    )
                    
                    // Digital Guardian Enhancement: Engagement Overview
                    EngagementOverviewSection(
                        avgDwellTime: viewModel.engagementInsights.averageDwellTimeSeconds,
                        avgScrollDepth: viewModel.engagementInsights.averageScrollDepthPercent,
                        meaningfulRate: viewModel.engagementInsights.meaningfulEngagementRate
                    )
                    
                    // Digital Guardian Enhancement: Top Engaged Sites
                    if !viewModel.topEngagedDomains.isEmpty {
                        TopEngagedSitesSection(sites: viewModel.topEngagedDomains)
                    }
                    
                    // Category Breakdown Chart
                    if !viewModel.categoryData.isEmpty {
                        CategoryBreakdownSection(data: viewModel.categoryData)
                    }
                    
                    // Timeline Chart
                    if !viewModel.timelineData.isEmpty {
                        TimelineActivitySection(data: viewModel.timelineData)
                    }
                    
                    // Digital Guardian Enhancement: Navigation Patterns
                    NavigationPatternsSection(patterns: viewModel.navigationPatterns)
                    
                    // Recent Sessions
                    RecentSessionsSection(sessions: viewModel.recentSessions)
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .background(GradientBackground())
            .navigationTitle(LanguageManager.shared.localized("insights.view.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LanguageManager.shared.localized("common.done")) {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(KomalColors.bubblegumPink)
                }
            }
        }
        .onAppear {
            viewModel.refresh()
        }
    }
}

// MARK: - ViewModel
@MainActor
final class InsightsViewModel: ObservableObject {
    @Published var insights: SessionInsights = .empty
    @Published var categoryData: [CategoryChartData] = []
    @Published var timelineData: [TimelineChartData] = []
    @Published var recentSessions: [BrowsingSession] = []
    
    // Digital Guardian Enhancement
    @Published var engagementInsights: EngagementInsights = .empty
    @Published var topEngagedDomains: [DomainEngagement] = []
    @Published var navigationPatterns: NavigationPatterns = .empty
    @Published var imagesFiltered: Int = 0
    @Published var imagesScanned: Int = 0
    
    // Content Viewing Insights
    @Published var contentInsights: ContentViewingInsights = .empty
    @Published var recentPageSummaries: [PageContentSummary] = []
    
    private let historyService = BrowsingHistoryService.shared
    private let contentAnalyzer = ContentAnalyzerService.shared
    
    func refresh() {
        insights = historyService.getInsights()
        categoryData = historyService.getCategoryChartData()
        timelineData = historyService.getTimelineData()
        
        // Digital Guardian Enhancement: Load engagement data
        engagementInsights = historyService.getEngagementInsights()
        topEngagedDomains = historyService.getTopEngagedDomains(limit: 5)
        navigationPatterns = historyService.getNavigationPatterns()
        imagesFiltered = historyService.totalImagesFiltered
        imagesScanned = historyService.totalImagesScanned
        
        // Content Viewing Insights
        contentInsights = contentAnalyzer.getContentInsights()
        recentPageSummaries = Array(contentAnalyzer.getAllPageSummaries().prefix(5))
        
        // Include current session in recent sessions if it has events
        var sessions: [BrowsingSession] = []
        if let current = historyService.currentSession, !current.events.isEmpty {
            sessions.append(current)
        }
        sessions.append(contentsOf: historyService.allSessions)
        recentSessions = Array(sessions.prefix(5))
    }
}

// MARK: - Summary Stats Section
struct SummaryStatsSection: View {
    let insights: SessionInsights
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LanguageManager.shared.localized("insights.overview"))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    title: LanguageManager.shared.localized("insights.sites_visited"),
                    value: "\(insights.totalEvents)",
                    icon: "globe",
                    color: KomalColors.pearlAqua
                )

                StatCard(
                    title: LanguageManager.shared.localized("insights.blocked"),
                    value: "\(insights.totalBlockedCount)",
                    icon: "xmark.shield.fill",
                    color: Color.red
                )

                StatCard(
                    title: LanguageManager.shared.localized("insights.gated"),
                    value: "\(insights.totalGatedCount)",
                    icon: "exclamationmark.triangle.fill",
                    color: Color.orange
                )

                StatCard(
                    title: LanguageManager.shared.localized("insights.sessions"),
                    value: "\(insights.totalSessions)",
                    icon: "clock.fill",
                    color: KomalColors.bubblegumPink
                )
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(KomalColors.textPrimary)
                    
                    Text(title)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.textSecondary)
                }
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: color.opacity(0.15), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Category Breakdown Section
struct CategoryBreakdownSection: View {
    let data: [CategoryChartData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LanguageManager.shared.localized("insights.content_categories"))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)
            
            VStack(spacing: 0) {
                Chart(data) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Category", item.category)
                    )
                    .foregroundStyle(categoryColor(for: item.color))
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(position: .bottom)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel()
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                }
                .frame(height: CGFloat(data.count * 44 + 40))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
        }
    }
    
    private func categoryColor(for name: String) -> Color {
        switch name {
        case "red": return .red
        case "pink": return .pink
        case "orange": return .orange
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        default: return .gray
        }
    }
}

// MARK: - Timeline Activity Section
struct TimelineActivitySection: View {
    let data: [TimelineChartData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LanguageManager.shared.localized("insights.activity_timeline"))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)
            
            VStack(spacing: 0) {
                Chart(data) { item in
                    LineMark(
                        x: .value("Time", item.hour),
                        y: .value("Events", item.total)
                    )
                    .foregroundStyle(KomalColors.pearlAqua)
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Time", item.hour),
                        y: .value("Events", item.total)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [KomalColors.pearlAqua.opacity(0.3), KomalColors.pearlAqua.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                        AxisValueLabel(format: .dateTime.hour())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 200)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
        }
    }
}

// MARK: - Recent Sessions Section
struct RecentSessionsSection: View {
    let sessions: [BrowsingSession]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LanguageManager.shared.localized("insights.recent_sessions"))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)
            
            if sessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(KomalColors.textSecondary.opacity(0.5))
                    
                    Text(LanguageManager.shared.localized("insights.no_sessions"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(sessions) { session in
                        SessionRow(session: session)
                    }
                }
            }
        }
    }
}

struct SessionRow: View {
    let session: BrowsingSession
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [KomalColors.pearlAqua.opacity(0.3), KomalColors.bubblegumPink.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "globe")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(KomalColors.pearlAqua)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.dateFormatted)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)
                        
                        HStack(spacing: 8) {
                            Label("\(session.events.count)", systemImage: "globe")
                            Label("\(session.blockedCount)", systemImage: "xmark.shield")
                                .foregroundColor(.red)
                            if session.imagesProtected > 0 {
                                Label("\(session.imagesProtected)", systemImage: "photo.badge.checkmark")
                                    .foregroundColor(KomalColors.bubblegumPink)
                            }
                            Text(session.durationFormatted)
                        }
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(KomalColors.textSecondary.opacity(0.5))
                }
                .padding(14)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    // Show engagement stats if available
                    if session.averageDwellTime > 0 {
                        HStack {
                            Label(LanguageManager.shared.localized("insights.avg_time_per_page"), systemImage: "clock")
                            Spacer()
                            Text(formatDwellTime(session.averageDwellTime))
                        }
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.textSecondary)
                        .padding(.horizontal, 14)
                    }
                    
                    ForEach(session.topDomains.prefix(5), id: \.domain) { item in
                        HStack {
                            Text(item.domain)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(KomalColors.textPrimary)
                            Spacer()
                            Text(LanguageManager.shared.localized("insights.visits", item.count))
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundColor(KomalColors.textSecondary)
                        }
                        .padding(.horizontal, 14)
                    }
                }
                .padding(.bottom, 14)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    private func formatDwellTime(_ seconds: TimeInterval) -> String {
        let intSeconds = Int(seconds)
        if intSeconds < 60 {
            return "\(intSeconds)s"
        }
        return "\(intSeconds / 60)m \(intSeconds % 60)s"
    }
}

// MARK: - Digital Guardian Enhancement: Protection Stats Section
struct ProtectionStatsSection: View {
    let imagesFiltered: Int
    let imagesScanned: Int
    let sitesBlocked: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(KomalColors.bubblegumPink)
                Text(LanguageManager.shared.localized("insights.protection_summary"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)
            }
            
            HStack(spacing: 12) {
                ProtectionStatCard(
                    title: LanguageManager.shared.localized("insights.images_protected"),
                    value: "\(imagesFiltered)",
                    subtitle: LanguageManager.shared.localized("insights.of_scanned", imagesScanned),
                    icon: "photo.badge.checkmark.fill",
                    color: KomalColors.bubblegumPink
                )

                ProtectionStatCard(
                    title: LanguageManager.shared.localized("insights.sites_blocked"),
                    value: "\(sitesBlocked)",
                    subtitle: LanguageManager.shared.localized("insights.harmful_content"),
                    icon: "xmark.shield.fill",
                    color: .red
                )
            }
        }
    }
}

struct ProtectionStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)
            
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)
            
            Text(subtitle)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(KomalColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: color.opacity(0.15), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Digital Guardian Enhancement: Engagement Overview Section
struct EngagementOverviewSection: View {
    let avgDwellTime: TimeInterval
    let avgScrollDepth: Int
    let meaningfulRate: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(KomalColors.pearlAqua)
                Text(LanguageManager.shared.localized("insights.engagement"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)
            }
            
            VStack(spacing: 16) {
                // Dwell Time
                EngagementMetricRow(
                    title: LanguageManager.shared.localized("insights.avg_time_page"),
                    value: formatDwellTime(avgDwellTime),
                    icon: "clock.fill",
                    color: KomalColors.pearlAqua
                )
                
                // Scroll Depth
                EngagementMetricRow(
                    title: LanguageManager.shared.localized("insights.avg_scroll_depth"),
                    value: "\(avgScrollDepth)%",
                    icon: "arrow.down.doc.fill",
                    color: KomalColors.bubblegumPink,
                    progress: Double(avgScrollDepth) / 100.0
                )
                
                // Meaningful Engagement
                EngagementMetricRow(
                    title: LanguageManager.shared.localized("insights.meaningful_engagement"),
                    value: "\(Int(meaningfulRate * 100))%",
                    icon: "hand.thumbsup.fill",
                    color: .green,
                    progress: meaningfulRate
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
        }
    }
    
    private func formatDwellTime(_ seconds: TimeInterval) -> String {
        let intSeconds = Int(seconds)
        if intSeconds < 60 {
            return "\(intSeconds)s"
        }
        return "\(intSeconds / 60)m \(intSeconds % 60)s"
    }
}

struct EngagementMetricRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var progress: Double? = nil
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(KomalColors.textSecondary)
                
                Spacer()
                
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)
            }
            
            if let progress = progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color.opacity(0.2))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: geo.size.width * min(progress, 1.0), height: 8)
                    }
                }
                .frame(height: 8)
            }
        }
    }
}

// MARK: - Digital Guardian Enhancement: Top Engaged Sites Section
struct TopEngagedSitesSection: View {
    let sites: [DomainEngagement]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.orange)
                Text(LanguageManager.shared.localized("insights.most_engaged"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)
            }
            
            VStack(spacing: 12) {
                ForEach(sites) { site in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(KomalColors.pearlAqua.opacity(0.2))
                                .frame(width: 40, height: 40)
                            
                            Text(String(site.domain.prefix(1)).uppercased())
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(KomalColors.pearlAqua)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(site.domain)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(KomalColors.textPrimary)
                                .lineLimit(1)
                            
                            Text(LanguageManager.shared.localized("insights.visits", site.visitCount))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(KomalColors.textSecondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(site.avgDwellTimeFormatted)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(KomalColors.textPrimary)
                            
                            Text(LanguageManager.shared.localized("insights.avg_time"))
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(KomalColors.textSecondary)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                    )
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(KomalColors.pearlAqua.opacity(0.1))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
        }
    }
}

// MARK: - Digital Guardian Enhancement: Navigation Patterns Section
struct NavigationPatternsSection: View {
    let patterns: NavigationPatterns
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.purple)
                Text(LanguageManager.shared.localized("insights.browsing_patterns"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)
            }
            
            VStack(spacing: 12) {
                NavigationPatternRow(
                    title: LanguageManager.shared.localized("insights.session_depth"),
                    value: LanguageManager.shared.localized("insights.pages", patterns.averageSessionDepth),
                    icon: "arrow.down.right",
                    description: LanguageManager.shared.localized("insights.how_deep")
                )

                NavigationPatternRow(
                    title: LanguageManager.shared.localized("insights.back_navigation"),
                    value: "\(Int(patterns.backNavigationRate * 100))%",
                    icon: "arrow.uturn.backward",
                    description: LanguageManager.shared.localized("insights.returning_pages")
                )

                if patterns.rapidSwitchingCount > 0 {
                    NavigationPatternRow(
                        title: LanguageManager.shared.localized("insights.quick_visits"),
                        value: "\(patterns.rapidSwitchingCount)",
                        icon: "bolt.fill",
                        description: LanguageManager.shared.localized("insights.pages_under_10s"),
                        isWarning: patterns.rapidSwitchingCount > 10
                    )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
        }
    }
}

struct NavigationPatternRow: View {
    let title: String
    let value: String
    let icon: String
    let description: String
    var isWarning: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isWarning ? Color.orange.opacity(0.2) : Color.purple.opacity(0.2))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isWarning ? .orange : .purple)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)
                
                Text(description)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(KomalColors.textSecondary)
            }
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(isWarning ? .orange : KomalColors.textPrimary)
        }
    }
}

// MARK: - Digital Guardian Enhancement: Content Viewed Section
struct ContentViewedSection: View {
    let contentInsights: ContentViewingInsights
    let recentPages: [PageContentSummary]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "eye.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.cyan)
                Text(LanguageManager.shared.localized("insights.content_viewed"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)
            }
            
            // Reading Stats
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    ContentStatBubble(
                        value: "\(contentInsights.estimatedWordsRead)",
                        label: LanguageManager.shared.localized("insights.words_read"),
                        icon: "text.alignleft",
                        color: .blue
                    )

                    ContentStatBubble(
                        value: "\(contentInsights.totalImagesViewed)",
                        label: LanguageManager.shared.localized("insights.images"),
                        icon: "photo.fill",
                        color: .green
                    )

                    ContentStatBubble(
                        value: "\(contentInsights.totalVideosViewed)",
                        label: LanguageManager.shared.localized("insights.videos"),
                        icon: "play.rectangle.fill",
                        color: .red
                    )
                }

                HStack(spacing: 16) {
                    ContentStatBubble(
                        value: "\(contentInsights.uniqueHeadingsViewed)",
                        label: LanguageManager.shared.localized("insights.topics"),
                        icon: "list.bullet",
                        color: .purple
                    )

                    ContentStatBubble(
                        value: contentInsights.avgReadingTimeFormatted,
                        label: LanguageManager.shared.localized("insights.avg_time_short"),
                        icon: "clock.fill",
                        color: .orange
                    )

                    ContentStatBubble(
                        value: contentInsights.estimatedReadingLevel,
                        label: LanguageManager.shared.localized("insights.reading"),
                        icon: "book.fill",
                        color: .cyan
                    )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
            
            // Flagged Content Alert
            if contentInsights.flaggedContentCount > 0 {
                FlaggedContentAlert(
                    count: contentInsights.flaggedContentCount,
                    keywords: contentInsights.topFlaggedKeywords,
                    pagesAffected: contentInsights.pagesWithConcerns
                )
            }
            
            // Recent Pages Summary
            if !recentPages.isEmpty {
                RecentPagesSection(pages: recentPages)
            }
        }
    }
}

struct ContentStatBubble: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(KomalColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct FlaggedContentAlert: View {
    let count: Int
    let keywords: [String]
    let pagesAffected: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.orange)
                
                Text(LanguageManager.shared.localized("insights.concerning_content"))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)
                
                Spacer()
                
                Text("\(count)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
            }
            
            if !keywords.isEmpty {
                Text(LanguageManager.shared.localized("insights.keywords", keywords.prefix(5).joined(separator: ", ")))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(KomalColors.textSecondary)
                    .lineLimit(2)
            }
            
            Text(LanguageManager.shared.localized("insights.found_on_pages", pagesAffected))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(KomalColors.textSecondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct RecentPagesSection: View {
    let pages: [PageContentSummary]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LanguageManager.shared.localized("insights.recent_pages"))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(KomalColors.textSecondary)
            
            ForEach(pages, id: \.id) { page in
                PageSummaryRow(page: page)
            }
        }
    }
}

struct PageSummaryRow: View {
    let page: PageContentSummary
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack(spacing: 12) {
                    // Risk indicator
                    Circle()
                        .fill(riskColor(page.riskLevel))
                        .frame(width: 10, height: 10)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(page.pageDomain)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)
                            .lineLimit(1)
                        
                        HStack(spacing: 8) {
                            Label("\(page.estimatedWordsRead)", systemImage: "text.alignleft")
                            Label("\(page.imagesViewed)", systemImage: "photo")
                            if page.videosViewed > 0 {
                                Label("\(page.videosViewed)", systemImage: "play.rectangle")
                            }
                        }
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Text(formatTime(page.totalViewTime))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.textSecondary)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(KomalColors.textSecondary.opacity(0.5))
                }
                .padding(12)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    if let title = page.pageTitle {
                        Text(title)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)
                            .lineLimit(2)
                            .padding(.horizontal, 12)
                    }
                    
                    if !page.headingsViewed.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LanguageManager.shared.localized("insights.topics_viewed"))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(KomalColors.textSecondary)
                            
                            ForEach(page.headingsViewed.prefix(5), id: \.self) { heading in
                                Text("• \(heading)")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(KomalColors.textPrimary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    
                    if !page.flaggedContent.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                            Text(LanguageManager.shared.localized("insights.flagged", page.flaggedContent.joined(separator: ", ")))
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 12)
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
        )
    }
    
    private func riskColor(_ level: ContentRiskLevel) -> Color {
        switch level {
        case .safe: return .green
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        case .blocked: return .black
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let intSeconds = Int(seconds)
        if intSeconds < 60 {
            return "\(intSeconds)s"
        }
        return "\(intSeconds / 60)m \(intSeconds % 60)s"
    }
}

#endif
