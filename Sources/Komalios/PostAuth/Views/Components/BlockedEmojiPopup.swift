#if os(iOS)
import SwiftUI

struct BlockedEmojiPopup: View {
    let subcategory: String
    let characterName: String
    let onDismiss: () -> Void
    let onEmojiSelected: (String) -> Void

    @State private var selectedEmoji: String?
    @State private var countdown = 3
    @State private var showVoiceChat = false
    @State private var isListening = false
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @StateObject private var audioPlayback = AudioPlaybackManager()
    @State private var chatResponse: String?
    @State private var isLoadingChat = false
    @State private var avatarImage = "animal1"
    @State private var hasSentTranscript = false
    @State private var silenceTimer: Timer?

    private let geminiService = GeminiChatService()
    private let avatarNames = (1...11).map { "animal\($0)" }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture {}

            VStack(spacing: 24) {
                Spacer()

                ZStack(alignment: .bottomTrailing) {
                    if let uiImage = UIImage(named: avatarImage) {
                        Image(uiImage: uiImage)
                            .resizable().aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100).clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 3))
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
                    Text("This content isn't available")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Komal is keeping you safe!")
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
        .onAppear { avatarImage = avatarNames.randomElement() ?? "animal1" }
        .onDisappear {
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

            if showVoiceChat {
                if let response = chatResponse {
                    Text(response)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.white).multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                if isLoadingChat { ProgressView().tint(.white) }

                Button(action: toggleListening) {
                    Image(systemName: isListening ? "waveform" : "mic.fill")
                        .font(.system(size: 24, weight: .semibold)).foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(isListening ? KomalColors.bubblegumPink : KomalColors.lavenderPurple))
                        .scaleEffect(isListening ? 1.15 : 1.0)
                        .animation(KomalAnimations.spring, value: isListening)
                }
            } else {
                Button(action: { showVoiceChat = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "mic.fill").font(.system(size: 16))
                        Text("Talk to me about it").font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(Capsule().fill(KomalColors.lavenderPurple))
                }
            }

            Text("Going back in \(countdown)...")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private func startCountdown() {
        countdown = 3
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if countdown > 1 { countdown -= 1 }
            else { timer.invalidate(); onDismiss() }
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
            do {
                let response = try await geminiService.sendMessage(
                    userMessage: text, conversationHistory: [], characterName: characterName,
                    characterPersonality: "A caring, gentle companion who helps children process difficult emotions about blocked content."
                )
                await MainActor.run {
                    chatResponse = response
                    isLoadingChat = false
                }
                // Speak the response via TTS
                await audioPlayback.speak(text: response, characterName: characterName)
            } catch {
                await MainActor.run {
                    chatResponse = "I'm here for you. Let's go explore something fun together!"
                    isLoadingChat = false
                }
            }
        }
    }
}
#endif
