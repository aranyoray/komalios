#if os(iOS)
import SwiftUI

struct EveningAnchorView: View {
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMood: String? = nil
    @State private var showBreathing = false

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.15, green: 0.15, blue: 0.3),
                        Color(red: 0.2, green: 0.18, blue: 0.35)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        characterGreeting

                        // Single-step conversational flow — no emoji grid
                        eveningConversationSection

                        if showBreathing {
                            windDownSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LanguageManager.localized("common.skip")) { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }

    // MARK: - Character Greeting

    private var characterGreeting: some View {
        VStack(spacing: 12) {
            if let uiImage = UIImage(named: "animal5") {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
            }

            Text(LanguageManager.localized("anchor.evening.greeting"))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(LanguageManager.localized("anchor.evening.wind_down"))
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    // MARK: - Evening Conversation (single step, text-based mood)

    private var eveningConversationSection: some View {
        VStack(spacing: 20) {
            Text(LanguageManager.localized("anchor.evening.how_feeling"))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))

            // Quick text-based mood bubbles — no emoji markers
            HStack(spacing: 10) {
                ForEach(["Great", "Good", "Okay", "Tired"], id: \.self) { mood in
                    Button(action: {
                        withAnimation {
                            selectedMood = mood
                            showBreathing = true
                        }
                    }) {
                        Text(mood)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(selectedMood == mood ? .white : .white.opacity(0.8))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().fill(selectedMood == mood ? KomalColors.lavenderPurple : Color.white.opacity(0.15))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Wind Down

    private var windDownSection: some View {
        VStack(spacing: 24) {
            // Brief breathing exercise
            VStack(spacing: 16) {
                Text(LanguageManager.localized("anchor.evening.deep_breaths"))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                BreathingCircle(size: 100, color: KomalColors.pearlAqua.opacity(0.6))

                Text(LanguageManager.localized("anchor.evening.breathe_in_out"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.vertical, 20)

            Button(action: saveAndDismiss) {
                Text(LanguageManager.localized("anchor.evening.good_night"))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .cornerRadius(14)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Save

    private func saveAndDismiss() {
        guard let mood = selectedMood else { dismiss(); return }

        let todayStr = Self.dayFormatter.string(from: Date())

        // Save anchor — using text-based mood instead of emoji
        let anchor = DailyAnchor(
            date: todayStr,
            anchorType: .evening,
            emotion: mood,
            emoji: "",
            intensity: 5
        )
        GrowthTrackingService.shared.saveAnchor(anchor)
        GrowthTrackingService.shared.recordActivity(type: .eveningAnchor)

        // Save mood entry
        let moodEntry = MoodEntry(
            emotion: mood,
            emoji: "",
            intensity: 5,
            context: .eveningAnchor
        )
        MoodTrackingService.shared.logMood(moodEntry)

        // Update retention state
        appState.retentionState.lastEveningAnchor = todayStr
        appState.savePreferences()

        dismiss()
    }
}
#endif
