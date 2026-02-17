#if os(iOS)
import SwiftUI

struct WeeklySnapshotView: View {
    @Environment(\.dismiss) private var dismiss
    let snapshot: WeeklySnapshot

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        KomalColors.bubblegumPink.opacity(0.1),
                        KomalColors.lavenderPurple.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Celebration header
                        VStack(spacing: 12) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 48))
                                .foregroundColor(KomalColors.bubblegumPink)

                            Text("Your Week in Review")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(KomalColors.textPrimary)

                            Text("\(snapshot.weekStartDate) - \(snapshot.weekEndDate)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(KomalColors.textSecondary)
                        }
                        .padding(.top, 20)

                        // Stats cards
                        HStack(spacing: 12) {
                            SnapshotStatCard(
                                icon: "calendar",
                                value: "\(snapshot.activeDays)",
                                label: "Active Days",
                                color: KomalColors.pearlAqua
                            )
                            SnapshotStatCard(
                                icon: "bubble.left.fill",
                                value: "\(snapshot.totalChats)",
                                label: "Chats",
                                color: KomalColors.bubblegumPink
                            )
                        }
                        .padding(.horizontal, 16)

                        HStack(spacing: 12) {
                            SnapshotStatCard(
                                icon: "sparkles",
                                value: "\(snapshot.totalReflections)",
                                label: "Reflections",
                                color: KomalColors.lavenderPurple
                            )
                            SnapshotStatCard(
                                icon: "heart.fill",
                                value: "\(snapshot.totalMoodCheckIns)",
                                label: "Mood Check-ins",
                                color: .orange
                            )
                        }
                        .padding(.horizontal, 16)

                        // Dominant emotion
                        if let emotion = snapshot.dominantEmotion {
                            SettingsCard {
                                VStack(spacing: 8) {
                                    Text("Most Common Mood")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(KomalColors.textSecondary)
                                    Text(emotion)
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(KomalColors.textPrimary)
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // Top character
                        if let characterName = snapshot.topCharacterName {
                            SettingsCard {
                                VStack(spacing: 8) {
                                    Text("Favorite Friend")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(KomalColors.textSecondary)
                                    Text(characterName)
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(KomalColors.bubblegumPink)
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // AI Growth Insight
                        if let insight = snapshot.aiGrowthInsight {
                            SettingsCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    CardHeader(icon: "lightbulb.fill", title: "Growth Insight", color: KomalColors.pearlAqua)

                                    Text(insight)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(KomalColors.textPrimary)
                                        .lineSpacing(4)
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        Button(action: { dismiss() }) {
                            Text("Keep Going!")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(KomalColors.bubblegumPink)
                                .cornerRadius(14)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Snapshot Stat Card

struct SnapshotStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(KomalColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}
#endif
