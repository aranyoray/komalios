//
//  InsightsView.swift
//  Komalios
//
//  Browsing insights report with professional charts
//

#if canImport(SwiftUI)
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
                    
                    // Category Breakdown Chart
                    if !viewModel.categoryData.isEmpty {
                        CategoryBreakdownSection(data: viewModel.categoryData)
                    }
                    
                    // Timeline Chart
                    if !viewModel.timelineData.isEmpty {
                        TimelineActivitySection(data: viewModel.timelineData)
                    }
                    
                    // Recent Sessions
                    RecentSessionsSection(sessions: viewModel.recentSessions)
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .background(GradientBackground())
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
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
final class InsightsViewModel: ObservableObject {
    @Published var insights: SessionInsights = .empty
    @Published var categoryData: [CategoryChartData] = []
    @Published var timelineData: [TimelineChartData] = []
    @Published var recentSessions: [BrowsingSession] = []
    
    private let historyService = BrowsingHistoryService.shared
    
    func refresh() {
        insights = historyService.getInsights()
        categoryData = historyService.getCategoryChartData()
        timelineData = historyService.getTimelineData()
        
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
            Text("Overview")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    title: "Sites Visited",
                    value: "\(insights.totalEvents)",
                    icon: "globe",
                    color: KomalColors.pearlAqua
                )
                
                StatCard(
                    title: "Blocked",
                    value: "\(insights.totalBlockedCount)",
                    icon: "xmark.shield.fill",
                    color: Color.red
                )
                
                StatCard(
                    title: "Gated",
                    value: "\(insights.totalGatedCount)",
                    icon: "exclamationmark.triangle.fill",
                    color: Color.orange
                )
                
                StatCard(
                    title: "Sessions",
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
            Text("Content Categories")
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
            Text("Activity Timeline")
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
            Text("Recent Sessions")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)
            
            if sessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(KomalColors.textSecondary.opacity(0.5))
                    
                    Text("No browsing sessions yet")
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
                    
                    ForEach(session.topDomains.prefix(5), id: \.domain) { item in
                        HStack {
                            Text(item.domain)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(KomalColors.textPrimary)
                            Spacer()
                            Text("\(item.count) visits")
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
}

#endif
