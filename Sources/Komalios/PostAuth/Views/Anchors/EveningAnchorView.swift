#if os(iOS)
import SwiftUI

struct EveningAnchorView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @State private var selectedEmotion: String? = nil
    @State private var selectedEmoji: String = ""
    @State private var emotionIntensity: Double = 5
    @State private var bestPart: String = ""
    @State private var anythingBothering: String = ""
    @State private var showBreathing = false

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
                        } else if currentStep == 1 {
                            reflectionSection
                        } else {
                            windDownSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") { dismiss() }
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

            Text("Good Evening!")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Let's wind down together")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    // MARK: - Emotion Picker

    private var emotionPickerSection: some View {
        VStack(spacing: 20) {
            Text("How are you feeling tonight?")
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
                            Text(emotion.1)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(selectedEmotion == emotion.1 ? .white : .white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedEmotion == emotion.1 ? emotion.2.opacity(0.4) : Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedEmotion == emotion.1 ? emotion.2 : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if selectedEmotion != nil {
                // Intensity slider
                HStack {
                    Text("A little")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                    Slider(value: $emotionIntensity, in: 1...10, step: 1)
                        .tint(KomalColors.lavenderPurple)
                    Text("A lot")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(16)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)

                Button(action: { withAnimation { currentStep = 1 } }) {
                    Text("Next")
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

    // MARK: - Reflection

    private var reflectionSection: some View {
        VStack(spacing: 20) {
            Text("What was the best part of your day?")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            TextField("Tell me about it...", text: $bestPart)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .padding(16)
                .background(Color.white.opacity(0.15))
                .cornerRadius(16)
                .foregroundColor(.white)

            Text("Anything bothering you?")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))

            TextField("It's okay to share...", text: $anythingBothering)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .padding(16)
                .background(Color.white.opacity(0.15))
                .cornerRadius(16)
                .foregroundColor(.white)

            Button(action: { withAnimation { currentStep = 2 } }) {
                Text("Next")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(KomalColors.lavenderPurple)
                    .cornerRadius(14)
            }
        }
    }

    // MARK: - Wind Down

    private var windDownSection: some View {
        VStack(spacing: 24) {
            // Brief breathing exercise
            VStack(spacing: 16) {
                Text("Take 3 deep breaths")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                BreathingCircle(size: 100, color: KomalColors.pearlAqua.opacity(0.6))

                Text("Breathe in... and out...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.vertical, 20)

            Button(action: saveAndDismiss) {
                Text("Good Night!")
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

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayStr = dateFormatter.string(from: Date())

        let reflectionNote = [bestPart, anythingBothering].filter { !$0.isEmpty }.joined(separator: " | ")

        // Save anchor
        let anchor = DailyAnchor(
            date: todayStr,
            anchorType: .evening,
            emotion: emotion,
            emoji: selectedEmoji,
            intensity: Int(emotionIntensity),
            reflectionItem: reflectionNote.isEmpty ? nil : reflectionNote
        )
        GrowthTrackingService.shared.saveAnchor(anchor)
        GrowthTrackingService.shared.recordActivity(type: .eveningAnchor)

        // Save mood entry
        let mood = MoodEntry(
            emotion: emotion,
            emoji: selectedEmoji,
            intensity: Int(emotionIntensity),
            context: .eveningAnchor,
            note: reflectionNote.isEmpty ? nil : reflectionNote
        )
        MoodTrackingService.shared.logMood(mood)

        // Update retention state
        appState.retentionState.lastEveningAnchor = todayStr
        appState.savePreferences()

        dismiss()
    }
}
#endif
