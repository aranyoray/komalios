#if os(iOS)
import SwiftUI

struct EyeTrackingReportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var summaries: [EyeTrackingDailySummary] = []
    @State private var showDeleteConfirmation = false

    private var today: EyeTrackingDailySummary? {
        summaries.last
    }

    private var last7: [EyeTrackingDailySummary] {
        Array(summaries.suffix(7))
    }

    private var trend: EyeTrackingTrend {
        EyeTrackingTrend.compute(from: summaries)
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.94, green: 0.96, blue: 1.0),
                        Color(red: 0.97, green: 0.95, blue: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if summaries.isEmpty {
                    emptyState
                } else {
                    reportContent
                }
            }
            .navigationTitle(LanguageManager.localized("eye.report_title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LanguageManager.localized("common.done")) { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                }
            }
        }
        .onAppear {
            summaries = EyeTrackingService.shared.getSummaries(days: 30)
        }
        .alert(LanguageManager.localized("eye.delete_confirm_title"), isPresented: $showDeleteConfirmation) {
            Button(LanguageManager.localized("common.cancel"), role: .cancel) {}
            Button(LanguageManager.localized("eye.delete_button"), role: .destructive) {
                EyeTrackingService.shared.deleteAllData()
                summaries = []
            }
        } message: {
            Text(LanguageManager.localized("eye.delete_confirm_message"))
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "eye.slash")
                .font(.system(size: 48))
                .foregroundColor(KomalColors.lavenderPurple.opacity(0.5))

            Text(LanguageManager.localized("eye.no_data_title"))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)

            Text(LanguageManager.localized("eye.no_data_message"))
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(KomalColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Report Content

    private var reportContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                privacyBadge

                // Summary metrics grid
                if let today = today {
                    metricsGrid(today)
                }

                // 7-day attention trend
                if last7.count >= 2 {
                    attentionTrendCard
                }

                // 7-day blink rate trend
                if last7.count >= 2 {
                    blinkRateTrendCard
                }

                // Gaze distribution heatmap
                if let today = today {
                    gazeHeatmapCard(today)
                }

                // Interpretation card
                if let today = today {
                    interpretationCard(today)
                }

                // Delete all data button
                deleteDataButton

                Spacer().frame(height: 20)
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Privacy Badge

    private var privacyBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 14))
                .foregroundColor(KomalColors.pearlAqua)
            Text(LanguageManager.localized("eye.privacy_badge"))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(KomalColors.pearlAqua)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(KomalColors.pearlAqua.opacity(0.1))
        .cornerRadius(20)
        .padding(.top, 8)
    }

    // MARK: - Metrics Grid

    private func metricsGrid(_ summary: EyeTrackingDailySummary) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                metricTile(
                    icon: "eye.fill",
                    color: KomalColors.lavenderPurple,
                    value: "\(summary.attentionScore)",
                    unit: "/100",
                    label: LanguageManager.localized("eye.metric_attention")
                )
                metricTile(
                    icon: "timer",
                    color: KomalColors.bubblegumPink,
                    value: String(format: "%.0f", summary.avgFocusDurationSeconds),
                    unit: "s",
                    label: LanguageManager.localized("eye.metric_focus")
                )
            }
            HStack(spacing: 12) {
                metricTile(
                    icon: "eye.slash",
                    color: .orange,
                    value: String(format: "%.1f", summary.blinkRatePerMinute),
                    unit: "/min",
                    label: LanguageManager.localized("eye.metric_blink")
                )
                metricTile(
                    icon: "battery.25percent",
                    color: fatigueColor(summary.screenFatigueIndex),
                    value: "\(summary.screenFatigueIndex)",
                    unit: "/100",
                    label: LanguageManager.localized("eye.metric_fatigue")
                )
            }
        }
    }

    private func metricTile(icon: String, color: Color, value: String, unit: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)
                Text(unit)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(KomalColors.textSecondary)
            }

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(KomalColors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
    }

    // MARK: - Attention Trend Chart

    private var attentionTrendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(LanguageManager.localized("eye.trend_attention"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: trend.icon)
                        .font(.system(size: 12))
                    Text(trend.rawValue.capitalized)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(trendColor)
            }

            EyeTrackingLineChart(
                values: last7.map { Double($0.attentionScore) },
                labels: last7.map { dayLabel($0.date) },
                color: KomalColors.lavenderPurple,
                maxValue: 100
            )
            .frame(height: 120)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
    }

    // MARK: - Blink Rate Trend Chart

    private var blinkRateTrendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LanguageManager.localized("eye.trend_blink"))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)

            EyeTrackingLineChart(
                values: last7.map(\.blinkRatePerMinute),
                labels: last7.map { dayLabel($0.date) },
                color: .orange,
                maxValue: max(40, last7.map(\.blinkRatePerMinute).max() ?? 40)
            )
            .frame(height: 120)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
    }

    // MARK: - Gaze Heatmap

    private func gazeHeatmapCard(_ summary: EyeTrackingDailySummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LanguageManager.localized("eye.gaze_distribution"))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)

            let zones: [[GazeZone]] = [
                [.topLeft, .topCenter, .topRight],
                [.bottomLeft, .bottomCenter, .bottomRight]
            ]

            VStack(spacing: 4) {
                ForEach(0..<zones.count, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(zones[row], id: \.self) { zone in
                            let pct = summary.gazeDistribution[zone.rawValue] ?? 0
                            gazeCell(zone: zone, percentage: pct)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
    }

    private func gazeCell(zone: GazeZone, percentage: Double) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%.0f%%", percentage))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)
            Text(zone.label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(KomalColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(KomalColors.lavenderPurple.opacity(gazeOpacity(percentage)))
        .cornerRadius(10)
    }

    private func gazeOpacity(_ pct: Double) -> Double {
        0.05 + min(0.35, pct / 100.0 * 0.7)
    }

    // MARK: - Interpretation Card

    private func interpretationCard(_ summary: EyeTrackingDailySummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.yellow)
                Text(LanguageManager.localized("eye.interpretation_title"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)
            }

            Text(interpretationText(summary))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(KomalColors.textSecondary)
                .lineSpacing(4)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.08), Color.orange.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }

    private func interpretationText(_ s: EyeTrackingDailySummary) -> String {
        var parts: [String] = []

        if s.attentionScore >= 70 {
            parts.append("Your child showed strong sustained attention today.")
        } else if s.attentionScore >= 40 {
            parts.append("Your child had moderate attention levels today. Short breaks may help.")
        } else {
            parts.append("Your child appeared frequently distracted today. Consider shorter screen sessions.")
        }

        if s.screenFatigueIndex >= 60 {
            parts.append("The fatigue index is elevated — signs of eye strain may be present.")
        } else if s.screenFatigueIndex <= 25 {
            parts.append("Low fatigue indicators suggest comfortable screen usage.")
        }

        if s.blinkRatePerMinute > 25 {
            parts.append("Blink rate is higher than normal, which can indicate tiredness.")
        } else if s.blinkRatePerMinute < 10 {
            parts.append("Low blink rate may indicate intense focus or potential dry eye risk.")
        }

        return parts.joined(separator: " ")
    }

    // MARK: - Delete Button

    private var deleteDataButton: some View {
        Button(action: { showDeleteConfirmation = true }) {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                Text(LanguageManager.localized("eye.delete_button"))
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.red.opacity(0.08))
            .cornerRadius(12)
        }
    }

    // MARK: - Helpers

    private var trendColor: Color {
        switch trend {
        case .improving: return .green
        case .stable: return .gray
        case .worsening: return .red
        }
    }

    private func fatigueColor(_ index: Int) -> Color {
        if index <= 30 { return KomalColors.pearlAqua }
        if index <= 60 { return .orange }
        return .red
    }

    private static let inputDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let dayLabelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "E"
        return f
    }()

    private func dayLabel(_ dateStr: String) -> String {
        guard let date = Self.inputDateFormatter.date(from: dateStr) else { return "" }
        return String(Self.dayLabelFormatter.string(from: date).prefix(1))
    }
}

// MARK: - Canvas Line Chart

struct EyeTrackingLineChart: View {
    let values: [Double]
    let labels: [String]
    let color: Color
    let maxValue: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let px: CGFloat = 16
            let py: CGFloat = 12
            let chartW = w - px * 2
            let chartH = h - py * 2 - 14 // room for labels

            Canvas { context, _ in
                guard values.count >= 2 else { return }
                let xDivisor = CGFloat(values.count - 1)

                // Grid lines
                for v in stride(from: 0.0, through: maxValue, by: maxValue / 4) {
                    let y = py + chartH - (CGFloat(v) / CGFloat(maxValue)) * chartH
                    var gridPath = Path()
                    gridPath.move(to: CGPoint(x: px, y: y))
                    gridPath.addLine(to: CGPoint(x: w - px, y: y))
                    context.stroke(gridPath, with: .color(.gray.opacity(0.1)), lineWidth: 0.5)
                }

                // Line
                var linePath = Path()
                for (i, val) in values.enumerated() {
                    let x = px + (CGFloat(i) / xDivisor) * chartW
                    let y = py + chartH - (CGFloat(val) / CGFloat(maxValue)) * chartH
                    if i == 0 { linePath.move(to: CGPoint(x: x, y: y)) }
                    else { linePath.addLine(to: CGPoint(x: x, y: y)) }
                }
                context.stroke(linePath, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                // Fill
                var fillPath = linePath
                let lastX = px + chartW
                let firstX = px
                fillPath.addLine(to: CGPoint(x: lastX, y: py + chartH))
                fillPath.addLine(to: CGPoint(x: firstX, y: py + chartH))
                fillPath.closeSubpath()
                context.fill(fillPath, with: .color(color.opacity(0.08)))

                // Dots
                for (i, val) in values.enumerated() {
                    let x = px + (CGFloat(i) / xDivisor) * chartW
                    let y = py + chartH - (CGFloat(val) / CGFloat(maxValue)) * chartH
                    let dotRect = CGRect(x: x - 3.5, y: y - 3.5, width: 7, height: 7)
                    context.fill(Path(ellipseIn: dotRect), with: .color(color))
                }

                // Day labels
                for (i, label) in labels.enumerated() {
                    let x = px + (CGFloat(i) / xDivisor) * chartW
                    let text = Text(label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(KomalColors.textSecondary)
                    context.draw(context.resolve(text), at: CGPoint(x: x, y: h - 2), anchor: .bottom)
                }
            }
        }
    }
}
#endif
