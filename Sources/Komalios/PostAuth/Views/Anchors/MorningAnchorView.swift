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
    @State private var lookingForwardTo: String = ""
    @State private var selectedMood: String? = nil

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

                        // Single-step conversational flow — no emoji picker, no sliders
                        morningConversationSection
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

    // MARK: - Morning Conversation (single step, no emoji picker or slider)

    private var morningConversationSection: some View {
        VStack(spacing: 20) {
            // Quick mood bubbles — text-only, no emoji markers
            Text(LanguageManager.shared.localized("anchor.morning.how_feeling"))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(KomalColors.textSecondary)

            HStack(spacing: 10) {
                ForEach(["Great", "Good", "Okay", "Not great"], id: \.self) { mood in
                    Button(action: { withAnimation { selectedMood = mood } }) {
                        Text(mood)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(selectedMood == mood ? .white : KomalColors.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().fill(selectedMood == mood ? KomalColors.lavenderPurple : Color.white)
                            )
                            .overlay(
                                Capsule().stroke(Color.black.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Looking forward prompt
            TextField(LanguageManager.shared.localized("anchor.morning.looking_forward_placeholder"), text: $lookingForwardTo)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .padding(16)
                .background(Color.white)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                )
                .onChange(of: lookingForwardTo) { _, newValue in
                    if newValue.count > 200 { lookingForwardTo = String(newValue.prefix(200)) }
                }

            Button(action: saveAndDismiss) {
                Text(LanguageManager.shared.localized("anchor.morning.start_my_day"))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(selectedMood != nil ? KomalColors.bubblegumPink : KomalColors.bubblegumPink.opacity(0.5))
                    .cornerRadius(14)
            }
            .disabled(selectedMood == nil)
        }
    }

    // MARK: - Save

    private func saveAndDismiss() {
        guard let mood = selectedMood else { return }

        let todayStr = Self.dayFormatter.string(from: Date())

        // Save anchor — using text-based mood instead of emoji
        let anchor = DailyAnchor(
            date: todayStr,
            anchorType: .morning,
            emotion: mood,
            emoji: "",
            intensity: 5,
            gratitudeItem: lookingForwardTo.isEmpty ? nil : lookingForwardTo
        )
        GrowthTrackingService.shared.saveAnchor(anchor)
        GrowthTrackingService.shared.recordActivity(type: .morningAnchor)

        // Save mood entry
        let moodEntry = MoodEntry(
            emotion: mood,
            emoji: "",
            intensity: 5,
            context: .morningAnchor,
            note: lookingForwardTo.isEmpty ? nil : lookingForwardTo
        )
        MoodTrackingService.shared.logMood(moodEntry)

        // Update retention state
        appState.retentionState.lastMorningAnchor = todayStr
        appState.savePreferences()

        dismiss()
    }
}
#endif
