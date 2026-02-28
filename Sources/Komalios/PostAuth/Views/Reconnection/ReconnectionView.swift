#if os(iOS)
import SwiftUI

struct ReconnectionView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @State private var selectedMood: String? = nil
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    KomalColors.lavenderPurple.opacity(0.15),
                    KomalColors.bubblegumPink.opacity(0.1),
                    Color.white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button(LanguageManager.localized("common.skip")) { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(KomalColors.textSecondary)
                        .padding(.trailing, 20)
                        .padding(.top, 16)
                }

                ScrollView {
                    VStack(spacing: 28) {
                        if currentStep == 0 {
                            welcomeBackStep
                        } else if currentStep == 1 {
                            quickMoodStep
                        } else {
                            reEngageStep
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    // MARK: - Step 1: Welcome Back

    private var welcomeBackStep: some View {
        VStack(spacing: 20) {
            // Ellie (the elephant who never forgets)
            if let uiImage = UIImage(named: "animal10") {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .accessibilityLabel(LanguageManager.localized("accessibility.ellie_character"))
            }

            Text(LanguageManager.localized("reconnection.welcome_back"))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)

            Text(LanguageManager.localized("reconnection.ellie_greeting"))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(KomalColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            let daysSince = daysSinceLastActive()
            if daysSince > 0 {
                Text(LanguageManager.localized("reconnection.days_since", daysSince))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(KomalColors.textSecondary)
            }

            Button(action: { withAnimation { currentStep = 1 } }) {
                Text(LanguageManager.localized("reconnection.hi_ellie"))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(KomalColors.lavenderPurple)
                    .cornerRadius(14)
            }
        }
    }

    // MARK: - Step 2: Quick Mood

    private var quickMoodStep: some View {
        VStack(spacing: 24) {
            Text(LanguageManager.localized("reconnection.how_have_you_been"))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)

            VStack(spacing: 12) {
                MoodOptionButton(emoji: "😊", label: LanguageManager.localized("reconnection.mood_great"), isSelected: selectedMood == "Great") {
                    selectedMood = "Great"
                }
                MoodOptionButton(emoji: "😐", label: LanguageManager.localized("reconnection.mood_okay"), isSelected: selectedMood == "Okay") {
                    selectedMood = "Okay"
                }
                MoodOptionButton(emoji: "😔", label: LanguageManager.localized("reconnection.mood_not_great"), isSelected: selectedMood == "Not great") {
                    selectedMood = "Not great"
                }
            }

            if selectedMood != nil {
                Button(action: {
                    // Log mood
                    if let mood = selectedMood {
                        let emoji = mood == "Great" ? "😊" : (mood == "Okay" ? "😐" : "😔")
                        let entry = MoodEntry(
                            emotion: mood,
                            emoji: emoji,
                            intensity: mood == "Great" ? 8 : (mood == "Okay" ? 5 : 3),
                            context: .spontaneous
                        )
                        MoodTrackingService.shared.logMood(entry)
                    }
                    withAnimation { currentStep = 2 }
                }) {
                    Text(LanguageManager.localized("common.continue"))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(KomalColors.lavenderPurple)
                        .cornerRadius(14)
                }
            }
        }
    }

    // MARK: - Step 3: Re-engage

    private var reEngageStep: some View {
        VStack(spacing: 24) {
            if let uiImage = UIImage(named: "animal10") {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .accessibilityLabel(LanguageManager.localized("accessibility.ellie_character"))
            }

            let moodMessage: String = {
                switch selectedMood {
                case "Great":
                    return LanguageManager.localized("reconnection.response_great")
                case "Not great":
                    return LanguageManager.localized("reconnection.response_not_great")
                default:
                    return LanguageManager.localized("reconnection.response_okay")
                }
            }()

            Text(moodMessage)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(KomalColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Text(LanguageManager.localized("reconnection.what_to_do"))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)

            VStack(spacing: 12) {
                ReEngageOptionButton(
                    icon: "globe",
                    title: LanguageManager.localized("reconnection.browse_web"),
                    color: KomalColors.pearlAqua
                ) {
                    appState.pendingNavigationTab = .browser
                    finishReconnection()
                }

                ReEngageOptionButton(
                    icon: "bubble.left.fill",
                    title: LanguageManager.localized("reconnection.chat_friend"),
                    color: KomalColors.bubblegumPink
                ) {
                    appState.pendingNavigationTab = .riki
                    finishReconnection()
                }

                ReEngageOptionButton(
                    icon: "sparkles",
                    title: LanguageManager.localized("reconnection.reflection_time"),
                    color: KomalColors.lavenderPurple
                ) {
                    appState.pendingNavigationTab = .reflect
                    finishReconnection()
                }
            }
        }
    }

    // MARK: - Helpers

    private func daysSinceLastActive() -> Int {
        guard let lastActive = appState.retentionState.lastActiveDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: lastActive, to: Date()).day ?? 0
    }

    private func finishReconnection() {
        appState.retentionState.hasSeenReconnectionFlow = true
        appState.retentionState.reconnectionCount += 1
        appState.savePreferences()
        dismiss()
    }
}

// MARK: - Mood Option Button

struct MoodOptionButton: View {
    let emoji: String
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Text(emoji)
                    .font(.system(size: 28))

                Text(label)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(isSelected ? KomalColors.lavenderPurple : KomalColors.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(KomalColors.lavenderPurple)
                }
            }
            .padding(16)
            .background(isSelected ? KomalColors.lavenderPurple.opacity(0.1) : Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? KomalColors.lavenderPurple : Color.gray.opacity(0.1), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Re-engage Option Button

struct ReEngageOptionButton: View {
    let icon: String
    let title: String
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }

                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(KomalColors.textSecondary)
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
}
#endif
