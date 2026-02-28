#if os(iOS)
import SwiftUI

struct BlockedEmojiPopup: View {
    let subcategory: String
    let characterName: String
    let showTalkFeature: Bool
    let onDismiss: () -> Void
    let onEmojiSelected: (String) -> Void

    @EnvironmentObject var appState: AppState
    @State private var selectedEmoji: String?
    @State private var countdown = 3
    @State private var isListening = false
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @StateObject private var audioPlayback = AudioPlaybackManager()
    @State private var chatResponse: String?
    @State private var isLoadingChat = false
    @State private var hasSentTranscript = false
    @State private var silenceTimer: Timer?

    private let geminiService = GeminiChatService()

    private var avatarImage: String {
        "animal\(appState.activeProfile.selectedAvatarIndex)"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture {}

            // Per spec section 5: "No mute button" — removed mute toggle

            VStack(spacing: 24) {
                Spacer()

                ZStack(alignment: .bottomTrailing) {
                    if let uiImage = UIImage(named: avatarImage) {
                        Image(uiImage: uiImage)
                            .resizable().aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100).clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 3))
                            .accessibilityLabel(characterName)
                    }
                    if audioPlayback.isPlaying {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 12)).foregroundColor(.white)
                            .padding(4)
                            .background(Circle().fill(KomalColors.lavenderPurple))
                            .offset(x: 4, y: 4)
                    }
                }

                VStack(spacing: 8) {
                    Text(LanguageManager.shared.localized("blocked.not_available"))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(LanguageManager.shared.localized("blocked.keeping_safe"))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }

                if selectedEmoji == nil {
                    EmojiResponseView(subcategory: subcategory) { emoji in
                        selectedEmoji = emoji
                        onEmojiSelected(emoji)
                        startCountdown()
                    }
                    .padding(.horizontal, 24)
                } else {
                    postEmojiContent
                }

                Spacer()
            }
        }
        .onDisappear {
            countdownTimer?.invalidate()
            countdownTimer = nil
            silenceTimer?.invalidate()
            silenceTimer = nil
        }
        .onReceive(speechRecognizer.$transcript) { newValue in
            if isListening && !newValue.isEmpty && !hasSentTranscript {
                silenceTimer?.invalidate()
                silenceTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                    Task { @MainActor in
                        if isListening && !hasSentTranscript {
                            toggleListening()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var postEmojiContent: some View {
        VStack(spacing: 16) {
            Text(selectedEmoji ?? "").font(.system(size: 48))

            if showTalkFeature {
                if let response = chatResponse {
                    Text(response)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.white).multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                if isLoadingChat { ProgressView().tint(.white) }

                // Voice chat mic — only shown every 4th popup
                VStack(spacing: 8) {
                    Button(action: toggleListening) {
                        Image(systemName: isListening ? "waveform" : "mic.fill")
                            .font(.system(size: 24, weight: .semibold)).foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Circle().fill(isListening ? KomalColors.bubblegumPink : KomalColors.lavenderPurple))
                            .scaleEffect(isListening ? 1.15 : 1.0)
                            .animation(KomalAnimations.spring, value: isListening)
                    }

                    Text(isListening ? LanguageManager.shared.localized("riki.listening") : LanguageManager.shared.localized("blocked.tap_talk"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }

                Text(LanguageManager.shared.localized("blocked.countdown", countdown))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    @State private var countdownTimer: Timer?

    private func startCountdown() {
        if showTalkFeature {
            // Full countdown with talk feature
            countdown = 3
            countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                Task { @MainActor in
                    if countdown > 1 { countdown -= 1 }
                    else { timer.invalidate(); onDismiss() }
                }
            }
        } else {
            // Quick dismiss — no talk, just show emoji briefly then go back
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onDismiss()
            }
        }
    }

    private func toggleListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        if audioPlayback.isPlaying { audioPlayback.stop() }

        if isListening {
            speechRecognizer.stopRecording()
            isListening = false
            let transcript = speechRecognizer.transcript
            if !transcript.isEmpty && !hasSentTranscript {
                hasSentTranscript = true
                sendVoiceMessage(transcript)
            }
        } else {
            hasSentTranscript = false
            audioPlayback.interruptForChildSpeech()
            speechRecognizer.startRecording()
            isListening = true
        }
    }

    private func sendVoiceMessage(_ text: String) {
        isLoadingChat = true
        Task {
            // Edge Case D: Network offline fallback
            guard NetworkMonitorService.shared.isConnected else {
                let fallback = NetworkMonitorService.shared.getOfflineResponse()
                await MainActor.run {
                    chatResponse = fallback
                    isLoadingChat = false
                }
                await audioPlayback.speak(text: fallback, characterName: characterName)
                return
            }

            do {
                let response = try await geminiService.sendMessage(
                    userMessage: text, conversationHistory: [], characterName: characterName,
                    characterPersonality: "A caring, gentle companion who helps children process difficult emotions about blocked content."
                )

                // Scan AI response for parasocial manipulation
                let scanResult = ParasocialDetectorService.shared.scan(response)
                let pref = await MainActor.run { appState.contentFilterPreferences.parasocialContent }
                let displayResponse: String
                if scanResult.riskLevel == .high && pref != .allow {
                    displayResponse = LanguageManager.shared.localized("chat.content_redirect")
                } else {
                    displayResponse = response
                }

                await MainActor.run {
                    chatResponse = displayResponse
                    isLoadingChat = false
                }
                // Speak the response via TTS
                await audioPlayback.speak(text: displayResponse, characterName: characterName)
            } catch {
                let fallback = LanguageManager.shared.localized("blocked.fallback_response")
                await MainActor.run {
                    chatResponse = fallback
                    isLoadingChat = false
                }
                await audioPlayback.speak(text: fallback, characterName: characterName)
            }
        }
    }
}
#endif
