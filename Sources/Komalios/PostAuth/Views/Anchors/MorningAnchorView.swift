#if os(iOS)
import SwiftUI

struct MorningAnchorView: View {
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
    @State private var emotionIntensity: Double = 5
    @State private var lookingForwardTo: String = ""

    private let emotions = [
        ("😊", "Happy", KomalColors.pearlAqua),
        ("😢", "Sad", Color.blue),
        ("😠", "Angry", Color.red),
        ("😰", "Worried", Color.orange),
        ("😴", "Tired", Color.gray),
        ("🤩", "Excited", KomalColors.bubblegumPink),
        ("😐", "Okay", Color.gray),
        ("🤔", "Confused", KomalColors.lavenderPurple)
    ]

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.97, blue: 0.9),
                        Color(red: 0.95, green: 0.95, blue: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Character greeting
                        characterGreeting

                        if currentStep == 0 {
                            emotionPickerSection
                        } else if currentStep == 1 {
                            intensitySection
                        } else {
                            lookingForwardSection
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
                        .foregroundColor(KomalColors.textSecondary)
                }
            }
        }
    }

    // MARK: - Character Greeting

    private var characterGreeting: some View {
        VStack(spacing: 12) {
            if let uiImage = UIImage(named: "animal1") {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
            }

            Text(LanguageManager.shared.localized("anchor.morning.greeting"))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)

            Text(LanguageManager.shared.localized("anchor.morning.how_feeling"))
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(KomalColors.textSecondary)
        }
    }

    // MARK: - Emotion Picker

    private var emotionPickerSection: some View {
        VStack(spacing: 20) {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(emotions, id: \.1) { emotion in
                    EmotionButton(
                        emoji: emotion.0,
                        label: emotion.1,
                        color: emotion.2,
                        isSelected: selectedEmotion == emotion.1
                    ) {
                        withAnimation {
                            selectedEmotion = emotion.1
                            selectedEmoji = emotion.0
                        }
                    }
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

    // MARK: - Intensity

    private var intensitySection: some View {
        VStack(spacing: 20) {
            Text(LanguageManager.shared.localized("anchor.morning.how_strong"))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)

            Text(selectedEmoji)
                .font(.system(size: 48))

            HStack {
                Text(LanguageManager.shared.localized("common.a_little"))
                    .font(.system(size: 12))
                    .foregroundColor(KomalColors.textSecondary)
                Slider(value: $emotionIntensity, in: 1...10, step: 1)
                    .tint(KomalColors.lavenderPurple)
                Text(LanguageManager.shared.localized("common.a_lot"))
                    .font(.system(size: 12))
                    .foregroundColor(KomalColors.textSecondary)
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(16)

            Button(action: { withAnimation { currentStep = 2 } }) {
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

    // MARK: - Looking Forward To

    private var lookingForwardSection: some View {
        VStack(spacing: 20) {
            Text(LanguageManager.shared.localized("anchor.morning.looking_forward"))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)
                .multilineTextAlignment(.center)

            TextField(LanguageManager.shared.localized("anchor.morning.looking_forward_placeholder"), text: $lookingForwardTo)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .padding(16)
                .background(Color.white)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                )

            Button(action: saveAndDismiss) {
                Text(LanguageManager.shared.localized("anchor.morning.start_my_day"))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(KomalColors.bubblegumPink)
                    .cornerRadius(14)
            }
        }
    }

    // MARK: - Save

    private func saveAndDismiss() {
        guard let emotion = selectedEmotion else { return }

        let todayStr = Self.dayFormatter.string(from: Date())

        // Save anchor
        let anchor = DailyAnchor(
            date: todayStr,
            anchorType: .morning,
            emotion: emotion,
            emoji: selectedEmoji,
            intensity: Int(emotionIntensity),
            gratitudeItem: lookingForwardTo.isEmpty ? nil : lookingForwardTo
        )
        GrowthTrackingService.shared.saveAnchor(anchor)
        GrowthTrackingService.shared.recordActivity(type: .morningAnchor)

        // Save mood entry
        let mood = MoodEntry(
            emotion: emotion,
            emoji: selectedEmoji,
            intensity: Int(emotionIntensity),
            context: .morningAnchor,
            note: lookingForwardTo.isEmpty ? nil : lookingForwardTo
        )
        MoodTrackingService.shared.logMood(mood)

        // Update retention state
        appState.retentionState.lastMorningAnchor = todayStr
        appState.savePreferences()

        dismiss()
    }
}
#endif
