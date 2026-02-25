#if os(iOS)
import SwiftUI

struct GrowthJourneyView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var growthService = GrowthTrackingService.shared

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

                ScrollView {
                    VStack(spacing: 24) {
                        // Identity Section
                        identitySection

                        // Milestones Section
                        milestonesSection

                        // Weekly Activity
                        weeklyActivitySection

                        Spacer().frame(height: 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationTitle(LanguageManager.shared.localized("growth.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LanguageManager.shared.localized("common.done")) { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                }
            }
        }
    }

    // MARK: - Identity Section

    private var identitySection: some View {
        SettingsCard {
            VStack(spacing: 20) {
                // Current stage with icon + narrative
                let progression = growthService.getIdentityProgression()
                let stage = progression.currentStage

                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(stageColor(stage).opacity(0.15))
                            .frame(width: 56, height: 56)
                        Image(systemName: stage.icon)
                            .font(.system(size: 26))
                            .foregroundColor(stageColor(stage))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(stage.narrativePrefix)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)
                        Text(stage.description)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(KomalColors.textSecondary)
                    }

                    Spacer()
                }

                // Journey path visualization
                HStack(spacing: 0) {
                    ForEach(IdentityStage.allCases, id: \.rawValue) { s in
                        let isReached = s.stageIndex <= stage.stageIndex
                        let isCurrent = s == stage

                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(isReached ? stageColor(s) : Color.gray.opacity(0.15))
                                    .frame(width: isCurrent ? 36 : 28, height: isCurrent ? 36 : 28)

                                Image(systemName: s.icon)
                                    .font(.system(size: isCurrent ? 16 : 12))
                                    .foregroundColor(isReached ? .white : Color.gray.opacity(0.4))
                            }

                            Text(s.rawValue.capitalized)
                                .font(.system(size: 10, weight: isCurrent ? .bold : .medium))
                                .foregroundColor(isReached ? stageColor(s) : KomalColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)

                        if s.stageIndex < IdentityStage.allCases.count - 1 {
                            Rectangle()
                                .fill(s.stageIndex < stage.stageIndex ? stageColor(s) : Color.gray.opacity(0.15))
                                .frame(height: 3)
                                .frame(maxWidth: 30)
                                .padding(.bottom, 20)
                        }
                    }
                }

                // Observed traits
                if !progression.observedTraits.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LanguageManager.shared.localized("growth.noticed_about_you"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(KomalColors.textSecondary)

                        ForEach(progression.observedTraits, id: \.self) { trait in
                            HStack(spacing: 8) {
                                Image(systemName: "sparkle")
                                    .font(.system(size: 12))
                                    .foregroundColor(KomalColors.bubblegumPink)
                                Text(trait)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(KomalColors.textPrimary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Milestones Section

    private var milestonesSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 16) {
                CardHeader(icon: "trophy.fill", title: LanguageManager.shared.localized("growth.milestones"), color: KomalColors.bubblegumPink)

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(growthService.milestones) { milestone in
                        MilestoneCard(milestone: milestone)
                    }
                }
            }
        }
    }

    // MARK: - Weekly Activity

    private var weeklyActivitySection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 16) {
                CardHeader(icon: "chart.bar.fill", title: LanguageManager.shared.localized("growth.this_week"), color: KomalColors.pearlAqua)

                let activities = growthService.getDailyActivities(days: 7)
                let totalChats = activities.reduce(0) { $0 + $1.chatCount }
                let totalReflections = activities.reduce(0) { $0 + $1.reflectionCount }
                let totalMoods = activities.reduce(0) { $0 + $1.moodCheckInCount }
                let activeDays = activities.filter { $0.isActive }.count

                HStack(spacing: 16) {
                    WeekStatBubble(value: "\(activeDays)", label: LanguageManager.shared.localized("growth.active_days"), color: KomalColors.pearlAqua)
                    WeekStatBubble(value: "\(totalChats)", label: LanguageManager.shared.localized("growth.chats"), color: KomalColors.bubblegumPink)
                    WeekStatBubble(value: "\(totalReflections)", label: LanguageManager.shared.localized("growth.reflections"), color: KomalColors.lavenderPurple)
                    WeekStatBubble(value: "\(totalMoods)", label: LanguageManager.shared.localized("growth.moods"), color: .orange)
                }
            }
        }
    }

    // MARK: - Helpers

    private func stageColor(_ stage: IdentityStage) -> Color {
        switch stage {
        case .explorer: return KomalColors.pearlAqua
        case .thinker: return KomalColors.lavenderPurple
        case .builder: return KomalColors.bubblegumPink
        case .guide: return .orange
        }
    }
}

// MARK: - Milestone Card

struct MilestoneCard: View {
    let milestone: Milestone

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(milestone.isEarned ? KomalColors.bubblegumPink.opacity(0.15) : Color.gray.opacity(0.08))
                    .frame(width: 48, height: 48)

                Image(systemName: milestone.icon)
                    .font(.system(size: 22))
                    .foregroundColor(milestone.isEarned ? KomalColors.bubblegumPink : Color.gray.opacity(0.3))
            }

            Text(milestone.title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(milestone.isEarned ? KomalColors.textPrimary : KomalColors.textSecondary)
                .multilineTextAlignment(.center)

            if !milestone.isEarned {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.1))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(KomalColors.lavenderPurple.opacity(0.5))
                            .frame(width: geo.size.width * milestone.progress)
                    }
                }
                .frame(height: 4)

                Text("\(milestone.currentProgress)/\(milestone.requirement)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(KomalColors.textSecondary)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(KomalColors.pearlAqua)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(milestone.isEarned ? Color.white : Color.gray.opacity(0.04))
                .shadow(color: milestone.isEarned ? KomalColors.bubblegumPink.opacity(0.1) : .clear, radius: 8)
        )
    }
}

// MARK: - Week Stat Bubble

struct WeekStatBubble: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(KomalColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
#endif
