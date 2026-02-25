#if os(iOS)
import SwiftUI

struct SELJourneyView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var records: [SELDailyRecord] = []
    @State private var summary: SELProfileSummary?
    @State private var eyeSummary: EyeTrackingDailySummary?

    private var last7: [SELDailyRecord] {
        Array(records.suffix(7))
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.95, blue: 1.0),
                        Color(red: 0.98, green: 0.96, blue: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if records.isEmpty {
                    emptyState
                } else {
                    reportContent
                }
            }
            .navigationTitle(LanguageManager.shared.localized("sel.growth_report"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LanguageManager.shared.localized("common.done")) { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                }
            }
        }
        .onAppear {
            records = SELAssessmentService.shared.getRecords(days: 30)
            summary = SELAssessmentService.shared.getProfileSummary()
            if appState.parentSettings.eyeTrackingEnabled {
                eyeSummary = EyeTrackingService.shared.getTodaySummary()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(KomalColors.lavenderPurple.opacity(0.5))

            Text(LanguageManager.shared.localized("sel.no_data_yet"))
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(KomalColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Text(LanguageManager.shared.localized("sel.empty_state_hint"))
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(KomalColors.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private var reportContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(LanguageManager.shared.localized("sel.progress_description"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(KomalColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Overall Score Card
                if let summary = summary {
                    overallScoreCard(summary)
                }

                // Radar Chart
                radarChartCard

                // Domain Breakdown
                domainBreakdownSection

                // 7-Day Trend Lines
                trendLinesCard

                // Session History
                sessionHistorySection

                // Eye Tracking Insights bridge
                if let eyeSummary = eyeSummary {
                    eyeInsightsBridgeCard(eyeSummary)
                }

                Spacer().frame(height: 20)
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Overall Score Card

    private func overallScoreCard(_ summary: SELProfileSummary) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 56, height: 56)
                Text("\(summary.overallScore)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(KomalColors.lavenderPurple)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(LanguageManager.shared.localized("sel.overall_score"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(KomalColors.textPrimary)

                    Image(systemName: trendIcon(summary.trend))
                        .font(.system(size: 12))
                        .foregroundColor(trendColor(summary.trend))
                }

                Text(summary.insight)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(KomalColors.textSecondary)
                    .lineLimit(3)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [KomalColors.lavenderPurple.opacity(0.1), KomalColors.pearlAqua.opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
    }

    // MARK: - Radar Chart

    private var radarChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LanguageManager.shared.localized("sel.domain_profile"))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)

            if let latest = records.last {
                SELRadarChart(scores: latest.domainScores)
                    .frame(height: 220)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
    }

    // MARK: - Domain Breakdown

    private var domainBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LanguageManager.shared.localized("sel.domain_breakdown"))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)
                .padding(.leading, 4)

            if let latest = records.last {
                ForEach(SELDomain.allCases, id: \.self) { domain in
                    let score = latest.domainScores[domain] ?? 0
                    let prevScores = last7.dropLast().map { $0.domainScores[domain] ?? 0 }
                    let avgPrev = prevScores.isEmpty ? score : prevScores.reduce(0, +) / prevScores.count
                    let delta = score - avgPrev
                    let isStrength = summary?.strengths.contains(domain) ?? false
                    let isGrowthArea = summary?.growthAreas.contains(domain) ?? false

                    SELDomainCard(domain: domain, score: score, delta: delta, isStrength: isStrength, isGrowthArea: isGrowthArea)
                }
            }
        }
    }

    // MARK: - Trend Lines

    private var trendLinesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LanguageManager.shared.localized("sel.seven_day_trends"))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)

            if last7.count >= 2 {
                SELLineChart(records: last7)
                    .frame(height: 100)
            } else {
                Text(LanguageManager.shared.localized("sel.need_more_sessions"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(KomalColors.textSecondary)
            }

            // Legend
            HStack(spacing: 12) {
                ForEach(SELDomain.allCases, id: \.self) { domain in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(domain.color)
                            .frame(width: 8, height: 8)
                        Text(domain.label.components(separatedBy: " ").first ?? "")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(KomalColors.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
    }

    // MARK: - Session History

    private var sessionHistorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LanguageManager.shared.localized("sel.recent_sessions"))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)
                .padding(.leading, 4)

            ForEach(last7.reversed()) { record in
                let avg = record.domainScores.values.reduce(0, +) / max(record.domainScores.count, 1)
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(KomalColors.lavenderPurple.opacity(0.1))
                            .frame(width: 36, height: 36)
                        Text("\(avg)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(KomalColors.lavenderPurple)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatDate(record.date))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(KomalColors.textPrimary)
                        Text("\(record.checkResults.count) checks completed\(record.mindfulnessCompleted ? " • Mindfulness ✅" : "")")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(KomalColors.textSecondary)
                    }

                    Spacer()

                    SELMiniSparkline(scores: Array(record.domainScores.values))
                        .frame(width: 40, height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.03), radius: 4, y: 1)
            }
        }
    }

    // MARK: - Eye Insights Bridge

    private func eyeInsightsBridgeCard(_ eye: EyeTrackingDailySummary) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(KomalColors.lavenderPurple.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: "eye.fill")
                    .font(.system(size: 18))
                    .foregroundColor(KomalColors.lavenderPurple)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(LanguageManager.shared.localized("eye.sel_bridge_title"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(KomalColors.textPrimary)
                    Text("\(eye.attentionScore)/100")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(KomalColors.lavenderPurple)
                }
                Text(eyeBridgeInterpretation(eye))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(KomalColors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [KomalColors.lavenderPurple.opacity(0.06), Color.blue.opacity(0.04)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(KomalColors.lavenderPurple.opacity(0.15), lineWidth: 1)
        )
    }

    private func eyeBridgeInterpretation(_ eye: EyeTrackingDailySummary) -> String {
        if eye.attentionScore >= 70 {
            return "Strong focus today — this supports deeper social-emotional engagement."
        } else if eye.attentionScore >= 40 {
            return "Moderate attention — SEL activities may benefit from shorter, focused sessions."
        } else {
            return "Low attention today — consider breaks before SEL activities."
        }
    }

    // MARK: - Helpers

    private func trendIcon(_ trend: SELTrend) -> String {
        switch trend {
        case .improving: return "arrow.up.right"
        case .declining: return "arrow.down.right"
        case .stable: return "minus"
        }
    }

    private func trendColor(_ trend: SELTrend) -> Color {
        switch trend {
        case .improving: return .green
        case .declining: return .red
        case .stable: return .gray
        }
    }

    private static let inputDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let displayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    private func formatDate(_ dateStr: String) -> String {
        guard let date = SELJourneyView.inputDateFormatter.date(from: dateStr) else { return dateStr }
        return SELJourneyView.displayDateFormatter.string(from: date)
    }
}

// MARK: - Radar Chart

struct SELRadarChart: View {
    let scores: [SELDomain: Int]

    private let cx: CGFloat = 120
    private let cy: CGFloat = 100
    private let radius: CGFloat = 75
    private let domains = SELDomain.allCases
    private let gridLevels = [25, 50, 75, 100]

    private func point(index: Int, value: CGFloat) -> CGPoint {
        let n = CGFloat(domains.count)
        let angle = (CGFloat.pi * 2 * CGFloat(index)) / n - .pi / 2
        let dist = (value / 100) * radius
        return CGPoint(x: cx + dist * cos(angle), y: cy + dist * sin(angle))
    }

    var body: some View {
        Canvas { context, size in
            let scaleX = size.width / 240
            let scaleY = size.height / 210

            func scaled(_ p: CGPoint) -> CGPoint {
                CGPoint(x: p.x * scaleX, y: p.y * scaleY)
            }

            // Grid
            for level in gridLevels {
                var gridPath = Path()
                for i in 0..<domains.count {
                    let p = scaled(point(index: i, value: CGFloat(level)))
                    if i == 0 { gridPath.move(to: p) } else { gridPath.addLine(to: p) }
                }
                gridPath.closeSubpath()
                context.stroke(gridPath, with: .color(.gray.opacity(0.15)), lineWidth: 0.8)
            }

            // Axes
            let center = scaled(CGPoint(x: cx, y: cy))
            for i in 0..<domains.count {
                let p = scaled(point(index: i, value: 100))
                var axisPath = Path()
                axisPath.move(to: center)
                axisPath.addLine(to: p)
                context.stroke(axisPath, with: .color(.gray.opacity(0.1)), lineWidth: 0.5)
            }

            // Data area
            var dataPath = Path()
            for (i, domain) in domains.enumerated() {
                let p = scaled(point(index: i, value: CGFloat(scores[domain] ?? 0)))
                if i == 0 { dataPath.move(to: p) } else { dataPath.addLine(to: p) }
            }
            dataPath.closeSubpath()
            context.fill(dataPath, with: .color(KomalColors.lavenderPurple.opacity(0.15)))
            context.stroke(dataPath, with: .color(KomalColors.lavenderPurple), lineWidth: 2)

            // Data points
            for (i, domain) in domains.enumerated() {
                let p = scaled(point(index: i, value: CGFloat(scores[domain] ?? 0)))
                let dotRect = CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)
                context.fill(Path(ellipseIn: dotRect), with: .color(KomalColors.lavenderPurple))
            }

            // Labels
            for (i, domain) in domains.enumerated() {
                let p = scaled(point(index: i, value: 115))
                let text = Text("\(domain.emoji) \(scores[domain] ?? 0)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(KomalColors.textSecondary)
                context.draw(context.resolve(text), at: p, anchor: .center)
            }
        }
    }
}

// MARK: - Line Chart

struct SELLineChart: View {
    let records: [SELDailyRecord]

    private let domains = SELDomain.allCases

    private static let inputFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "E"
        return f
    }()

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let px: CGFloat = 20
            let py: CGFloat = 10
            let chartW = w - px * 2
            let chartH = h - py * 2

            Canvas { context, _ in
                // Grid lines
                for v in [0, 25, 50, 75, 100] {
                    let y = py + chartH - (CGFloat(v) / 100) * chartH
                    var path = Path()
                    path.move(to: CGPoint(x: px, y: y))
                    path.addLine(to: CGPoint(x: w - px, y: y))
                    context.stroke(path, with: .color(.gray.opacity(0.1)), lineWidth: 0.5)
                }

                // Domain lines
                let xDivisor = records.count > 1 ? CGFloat(records.count - 1) : 1
                for domain in domains {
                    var path = Path()
                    for (i, record) in records.enumerated() {
                        let x = px + (CGFloat(i) / xDivisor) * chartW
                        let score = CGFloat(record.domainScores[domain] ?? 0)
                        let y = py + chartH - (score / 100) * chartH
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    context.stroke(path, with: .color(domain.color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }

                // Day labels
                for (i, record) in records.enumerated() {
                    let x = px + (CGFloat(i) / xDivisor) * chartW
                    if let date = SELLineChart.inputFormatter.date(from: record.date) {
                        let label = String(SELLineChart.dayFormatter.string(from: date).prefix(1))
                        let text = Text(label)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(KomalColors.textSecondary)
                        context.draw(context.resolve(text), at: CGPoint(x: x, y: h - 2), anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Domain Card

struct SELDomainCard: View {
    let domain: SELDomain
    let score: Int
    let delta: Int
    let isStrength: Bool
    let isGrowthArea: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(domain.emoji)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(domain.label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(KomalColors.textPrimary)

                    if isStrength {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                    }
                    if isGrowthArea {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                }

                // Score bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.1))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(domain.color)
                            .frame(width: geo.size.width * CGFloat(score) / 100)
                    }
                }
                .frame(height: 6)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(score)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)

                Text(delta > 0 ? "+\(delta)" : delta == 0 ? "--" : "\(delta)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(delta > 0 ? .green : delta < 0 ? .red : .gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isGrowthArea ? Color.orange.opacity(0.3) :
                    isStrength ? Color.green.opacity(0.3) :
                    Color.gray.opacity(0.1),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 1)
    }
}

// MARK: - Mini Sparkline

struct SELMiniSparkline: View {
    let scores: [Int]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Canvas { context, _ in
                guard scores.count > 1 else { return }
                var path = Path()
                for (i, score) in scores.enumerated() {
                    let x = (CGFloat(i) / CGFloat(scores.count - 1)) * w
                    let y = h - (CGFloat(score) / 100) * h
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                context.stroke(path, with: .color(KomalColors.lavenderPurple), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }
        }
    }
}
#endif
