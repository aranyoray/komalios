#if os(iOS)
import SwiftUI

/// Compact horizontal 7-day mood strip showing dominant emotion emoji per day
struct MoodHistoryMiniView: View {
    @ObservedObject private var moodService = MoodTrackingService.shared
    private let trend: [(date: String, emotion: String, emoji: String)]

    init() {
        trend = MoodTrackingService.shared.getMoodTrend(days: 7)
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<7, id: \.self) { dayOffset in
                let calendar = Calendar.current
                let date = calendar.date(byAdding: .day, value: -(6 - dayOffset), to: Date()) ?? Date()
                let formatter = DateFormatter()
                let _ = formatter.dateFormat = "yyyy-MM-dd"
                let dateStr = formatter.string(from: date)

                let dayTrend = trend.first(where: { $0.date == dateStr })

                VStack(spacing: 4) {
                    // Day label
                    Text(dayLabel(for: date))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(KomalColors.textSecondary)

                    // Emoji circle
                    ZStack {
                        Circle()
                            .fill(dayTrend != nil ? KomalColors.lavenderPurple.opacity(0.15) : Color.gray.opacity(0.08))
                            .frame(width: 36, height: 36)

                        if let entry = dayTrend {
                            Text(entry.emoji)
                                .font(.system(size: 18))
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.8))
        .cornerRadius(16)
    }

    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return String(formatter.string(from: date).prefix(2))
    }
}
#endif
