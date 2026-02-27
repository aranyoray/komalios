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
    @State private var currentStep = 0
    @State private var selectedEmotion: String? = nil
    @State private var selectedEmoji: String = ""
    @State private var showBreathing = false

    // (emoji, storageKey, localizedLabel, color)
    private var emotions: [(String, String, String, Color)] {
        let lang = LanguageManager.shared
        return [
            ("😊", "Happy", lang.localized("reflect.emotion.happy"), KomalColors.pearlAqua),
            ("😢", "Sad", lang.localized("reflect.emotion.sad"), Color.blue),
            ("😠", "Angry", lang.localized("reflect.emotion.angry"), Color.red),
            ("😰", "Worried", lang.localized("reflect.emotion.worried"), Color.orange),
            ("😴", "Tired", lang.localized("reflect.emotion.tired"), Color.gray),
            ("🤩", "Excited", lang.localized("reflect.emotion.excited"), KomalColors.bubblegumPink),
            ("😐", "Okay", lang.localized("reflect.emotion.okay"), Color.gray),
            ("🤔", "Confused", lang.localized("reflect.emotion.confused"), KomalColors.lavenderPurple)
        ]
    }

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

                        if currentStep == 0 {
                            emotionPickerSection
                        } else {
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
                    Button(LanguageManager.shared.localized("common.skip")) { dismiss() }
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

            Text(LanguageManager.shared.localized("anchor.evening.greeting"))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(LanguageManager.shared.localized("anchor.evening.wind_down"))
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    // MARK: - Emotion Picker

    private var emotionPickerSection: some View {
        VStack(spacing: 20) {
            Text(LanguageManager.shared.localized("anchor.evening.how_feeling"))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(emotions, id: \.1) { emotion in
                    Button(action: {
                        withAnimation {
                            selectedEmotion = emotion.1
                            selectedEmoji = emotion.0
                        }
                    }) {
                        VStack(spacing: 6) {
                            Text(emotion.0)
                                .font(.system(size: 32))
                            Text(emotion.2)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(selectedEmotion == emotion.1 ? .white : .white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedEmotion == emotion.1 ? emotion.3.opacity(0.4) : Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedEmotion == emotion.1 ? emotion.3 : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if selectedEmotion != nil {
                Button(action: { withAnimation { currentStep = 1 } }) {
                    Text(LanguageManager.shared.localized("common.next"))
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

    // MARK: - Wind Down

    private var windDownSection: some View {
        VStack(spacing: 24) {
            // Brief breathing exercise
            VStack(spacing: 16) {
                Text(LanguageManager.shared.localized("anchor.evening.deep_breaths"))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                BreathingCircle(size: 100, color: KomalColors.pearlAqua.opacity(0.6))

                Text(LanguageManager.shared.localized("anchor.evening.breathe_in_out"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.vertical, 20)

            Button(action: saveAndDismiss) {
                Text(LanguageManager.shared.localized("anchor.evening.good_night"))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .cornerRadius(14)
            }
        }
    }

    // MARK: - Save

    private func saveAndDismiss() {
        guard let emotion = selectedEmotion else { dismiss(); return }

        let todayStr = Self.dayFormatter.string(from: Date())

        // Save anchor
        let anchor = DailyAnchor(
            date: todayStr,
            anchorType: .evening,
            emotion: emotion,
            emoji: selectedEmoji,
            intensity: 5
        )
        GrowthTrackingService.shared.saveAnchor(anchor)
        GrowthTrackingService.shared.recordActivity(type: .eveningAnchor)

        // Save mood entry
        let mood = MoodEntry(
            emotion: emotion,
            emoji: selectedEmoji,
            intensity: 5,
            context: .eveningAnchor
        )
        MoodTrackingService.shared.logMood(mood)

        // Update retention state
        appState.retentionState.lastEveningAnchor = todayStr
        appState.savePreferences()

        dismiss()
    }
}
#endif
