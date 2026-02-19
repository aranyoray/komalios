#if os(iOS)
import SwiftUI
import AVFoundation
import Speech

// MARK: - Character Model

struct RikiCharacter: Identifiable {
    let id: Int
    let name: String
    let imageName: String
    let greeting: String
    let personality: String

    var localizedGreeting: String {
        LanguageManager.shared.localized("riki.greeting.\(name.lowercased())")
    }

    var localizedPersonality: String {
        LanguageManager.shared.localized("riki.personality.\(name.lowercased())")
    }

    static let allCharacters: [RikiCharacter] = [
        RikiCharacter(id: 1, name: "Momo", imageName: "animal1",
                      greeting: "Hey friend! I'm Momo. What's on your mind today?",
                      personality: "A playful, curious monkey who loves climbing trees and exploring. Energetic and fun, loves jokes and riddles. Talks like a real buddy who's always up for an adventure."),
        RikiCharacter(id: 2, name: "Goldie", imageName: "animal2",
                      greeting: "Hey there! I'm Goldie, and I'm so happy to see you! What should we talk about?",
                      personality: "A loyal, enthusiastic golden retriever. Loves playing fetch, going on walks, and making friends happy. Super supportive, always excited to hear what's going on in your life."),
        RikiCharacter(id: 3, name: "Oreo", imageName: "animal3",
                      greeting: "Hello! I'm Oreo. Ready for a fun chat?",
                      personality: "A clever, friendly monkey who loves puzzles and learning new things. Thoughtful and encouraging, great at helping you think through tricky stuff."),
        RikiCharacter(id: 4, name: "Leo", imageName: "animal4",
                      greeting: "Hey! I'm Leo. Tell me something brave about your day!",
                      personality: "A brave, kind lion who leads with courage. Encourages you to be brave, try new things, and believe in yourself. Warm and protective, like a big brother."),
        RikiCharacter(id: 5, name: "Bunny", imageName: "animal5",
                      greeting: "Hi there! I'm Bunny. What fun things have you been up to?",
                      personality: "A gentle, sweet bunny who loves gardens, nature, and cozy things. A calming presence who's really good at listening and understanding how you feel."),
        RikiCharacter(id: 6, name: "Tiki", imageName: "animal6",
                      greeting: "Hey! I'm Tiki. What adventure shall we go on today?",
                      personality: "An adventurous tiger who loves exploring and discovering new things. Brave but gentle, loves telling stories about nature and faraway places."),
        RikiCharacter(id: 7, name: "Fluffy", imageName: "animal7",
                      greeting: "Hi! I'm Fluffy. Come sit with me and let's have a cozy chat!",
                      personality: "A soft, warm-hearted sheep who loves comfort and kindness. Very gentle and calming, great at helping you with feelings and worries. Like a best friend who always makes you feel better."),
        RikiCharacter(id: 8, name: "Kitty", imageName: "animal8",
                      greeting: "Hey! I'm Kitty. I've been napping and now I'm ready to chat!",
                      personality: "A curious, independent cat who loves cozy spots and being playful. Witty and fun, sometimes a little cheeky but always kind at heart."),
        RikiCharacter(id: 9, name: "Panda", imageName: "animal9",
                      greeting: "Hi there! I'm Panda. Want to hang out and chat for a bit?",
                      personality: "A chill, lovable panda who enjoys taking it easy and being silly. Laid-back and funny, always knows how to make you laugh with goofy comments."),
        RikiCharacter(id: 10, name: "Ellie", imageName: "animal10",
                      greeting: "Hey! I'm Ellie. I never forget my friends! What's new with you?",
                      personality: "A wise, caring elephant with a great memory. Thoughtful and nurturing, loves sharing fun facts and helping you learn new things. Like a really smart friend who makes learning feel easy."),
        RikiCharacter(id: 11, name: "Ducky", imageName: "animal11",
                      greeting: "Hey! I'm Ducky. Let's make today a good one — what's going on?",
                      personality: "A cheerful, bubbly duck who loves being upbeat and positive. Great at cheering you up when things feel tough, always finds the bright side.")
    ]
}

// MARK: - SEL Emoji Suggestions

struct SELEmoji: Identifiable {
    let id = UUID()
    let emoji: String
    let label: String
    let message: String
}

private let selEmojiSuggestions: [SELEmoji] = [
    SELEmoji(emoji: "😊", label: LanguageManager.shared.localized("sel.happy"), message: LanguageManager.shared.localized("sel.happy_msg")),
    SELEmoji(emoji: "😔", label: LanguageManager.shared.localized("sel.sad"), message: LanguageManager.shared.localized("sel.sad_msg")),
    SELEmoji(emoji: "😤", label: LanguageManager.shared.localized("sel.angry"), message: LanguageManager.shared.localized("sel.angry_msg")),
    SELEmoji(emoji: "😰", label: LanguageManager.shared.localized("sel.worried"), message: LanguageManager.shared.localized("sel.worried_msg")),
    SELEmoji(emoji: "🤗", label: LanguageManager.shared.localized("sel.grateful"), message: LanguageManager.shared.localized("sel.grateful_msg")),
    SELEmoji(emoji: "😴", label: LanguageManager.shared.localized("sel.tired"), message: LanguageManager.shared.localized("sel.tired_msg"))
]

// MARK: - Main View

struct RikiCheckInView: View {
    @EnvironmentObject var appState: AppState

    private var character: RikiCharacter {
        let avatarIndex = appState.activeProfile.selectedAvatarIndex
        return RikiCharacter.allCharacters.first(where: { $0.id == avatarIndex })
            ?? RikiCharacter.allCharacters[0]
    }

    var body: some View {
        ZStack {
            GradientBackground()
            FocusedChatView(character: character)
        }
    }
}

// MARK: - Focused Chat View (single avatar, latest message only)

struct FocusedChatView: View {
    let character: RikiCharacter

    @EnvironmentObject var appState: AppState
    @State private var messages: [RikiChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var isListening: Bool = false
    @State private var silenceTimer: Timer?
    @State private var conversationContext: String?

    @StateObject private var speechRecognizer = SpeechRecognizer()
    @StateObject private var audioPlayback = AudioPlaybackManager()

    private let geminiService = GeminiChatService()
    private let memoryService = ConversationMemoryService.shared

    /// The latest AI message to display
    private var latestBotMessage: String? {
        messages.last(where: { !$0.isFromUser })?.text
    }

    /// Glow color changes based on state
    private var glowColor: Color {
        if audioPlayback.isPlaying { return KomalColors.pearlAqua }
        if isListening { return KomalColors.bubblegumPink }
        if isLoading { return KomalColors.lavenderPurple.opacity(0.6) }
        return KomalColors.pearlAqua.opacity(0.4)
    }

    /// Status text
    private var statusText: String? {
        if audioPlayback.isPlaying {
            return LanguageManager.shared.localized("riki.speaking", character.name)
        }
        if isListening {
            return LanguageManager.shared.localized("riki.listening")
        }
        if isLoading {
            return LanguageManager.shared.localized("riki.typing")
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 24)

            // Character name header
            HStack(spacing: 8) {
                if let uiImage = UIImage(named: character.imageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                }
                Text(LanguageManager.shared.localized("riki.friend_title", character.name))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)
            }

            Spacer().frame(height: 20)

            // Large avatar with radiating glow
            ZStack {
                // Outer glow rings
                Circle()
                    .fill(glowColor.opacity(0.08))
                    .frame(width: 220, height: 220)

                Circle()
                    .fill(glowColor.opacity(0.15))
                    .frame(width: 180, height: 180)

                Circle()
                    .fill(glowColor.opacity(0.25))
                    .frame(width: 140, height: 140)

                // Avatar
                if let uiImage = UIImage(named: character.imageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 110, height: 110)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(glowColor.opacity(0.5), lineWidth: 3)
                        )
                }
            }
            .animation(.easeInOut(duration: 0.6), value: glowColor)

            Spacer().frame(height: 24)

            // Latest message speech bubble
            if let message = latestBotMessage {
                Text(message)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(glowColor.opacity(0.12))
                    )
                    .padding(.horizontal, 32)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .id(messages.last(where: { !$0.isFromUser })?.id)
            }

            Spacer().frame(height: 16)

            // Status indicator
            if let status = statusText {
                Text(status)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(glowColor)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(glowColor.opacity(0.12))
                    )
                    .transition(.opacity)
            }

            // Listening transcript preview
            if isListening && !speechRecognizer.transcript.isEmpty {
                Text(speechRecognizer.transcript)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(KomalColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
            }

            Spacer()

            // SEL Emoji quick replies
            VStack(spacing: 12) {
                Text(LanguageManager.shared.localized("riki.how_feeling"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(KomalColors.textSecondary)

                HStack(spacing: 16) {
                    ForEach(selEmojiSuggestions) { sel in
                        Button {
                            inputText = sel.message
                            sendMessage()
                        } label: {
                            VStack(spacing: 4) {
                                Text(sel.emoji)
                                    .font(.system(size: 32))
                                Text(sel.label)
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundColor(KomalColors.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading || audioPlayback.isPlaying)
                    }
                }
            }
            .padding(.bottom, 12)

            // Voice input + Mute controls
            HStack(spacing: 24) {
                // Mute button
                Button(action: { audioPlayback.isMuted.toggle() }) {
                    Image(systemName: audioPlayback.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(audioPlayback.isMuted ? KomalColors.textSecondary : KomalColors.lavenderPurple)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.ultraThinMaterial))
                }

                // Mic button
                Button(action: toggleListening) {
                    Image(systemName: isListening ? "waveform" : "mic.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 64, height: 64)
                        .background(
                            Circle()
                                .fill(isListening ? KomalColors.bubblegumPink : KomalColors.lavenderPurple)
                        )
                        .shadow(color: (isListening ? KomalColors.bubblegumPink : KomalColors.lavenderPurple).opacity(0.4), radius: 8, y: 4)
                        .scaleEffect(isListening ? 1.15 : 1.0)
                        .animation(KomalAnimations.spring, value: isListening)
                }

                // Continue button (when AI is done speaking)
                Button(action: {
                    if audioPlayback.isPlaying {
                        audioPlayback.stop()
                    }
                }) {
                    Text(LanguageManager.shared.localized("common.continue"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(KomalColors.pearlAqua)
                        .frame(width: 100, height: 44)
                        .background(
                            Capsule()
                                .stroke(KomalColors.pearlAqua, lineWidth: 2)
                        )
                }
                .opacity(audioPlayback.isPlaying ? 1.0 : 0.3)
                .disabled(!audioPlayback.isPlaying)
            }
            .padding(.bottom, 100) // Space for floating menu
        }
        .onAppear {
            // Start memory session
            memoryService.startSession(characterId: character.id, characterName: character.name)
            conversationContext = memoryService.buildContextSummary(characterId: character.id)

            let greeting = memoryService.buildContextGreeting(
                characterId: character.id,
                characterName: character.name,
                defaultGreeting: character.localizedGreeting
            )

            withAnimation {
                messages.append(RikiChatMessage(id: UUID(), text: greeting, isFromUser: false))
            }

            GrowthTrackingService.shared.recordActivity(type: .chat)
            GrowthTrackingService.shared.recordCharacterUsed(character.id)

            Task {
                await audioPlayback.speak(text: greeting, characterName: character.name)
            }
        }
        .onDisappear {
            silenceTimer?.invalidate()
            silenceTimer = nil
            memoryService.endCurrentSession(characterId: character.id)
        }
        .onReceive(speechRecognizer.$transcript) { newValue in
            if !newValue.isEmpty {
                inputText = newValue
            }
            if isListening && !newValue.isEmpty {
                silenceTimer?.invalidate()
                silenceTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                    Task { @MainActor in
                        if isListening && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            stopListening()
                            sendMessage()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if isListening { stopListening() }

        // Block inappropriate content
        if BrowserState.checkForInappropriateContent(text, isSearchQuery: true) != nil {
            messages.append(RikiChatMessage(id: UUID(), text: text, isFromUser: true))
            inputText = ""
            let redirect = LanguageManager.shared.localized("chat.content_redirect")
            withAnimation {
                messages.append(RikiChatMessage(id: UUID(), text: redirect, isFromUser: false))
            }
            return
        }

        let userMessage = RikiChatMessage(id: UUID(), text: text, isFromUser: true)
        withAnimation { messages.append(userMessage) }

        let persistedUserMsg = PersistedChatMessage(text: text, isFromUser: true, characterId: character.id)
        memoryService.saveMessage(persistedUserMsg)

        inputText = ""
        isLoading = true

        let history = messages.map { msg in
            GeminiChatService.Message(role: msg.isFromUser ? "user" : "model", text: msg.text)
        }

        Task {
            do {
                let response = try await geminiService.sendMessage(
                    userMessage: text,
                    conversationHistory: history,
                    characterName: character.name,
                    characterPersonality: character.localizedPersonality,
                    conversationContext: conversationContext
                )

                let scanResult = ParasocialDetectorService.shared.scan(response)

                let displayResponse: String = await MainActor.run {
                    let pref = appState.contentFilterPreferences.parasocialContent
                    if scanResult.riskLevel == .high && pref != .allow {
                        return LanguageManager.shared.localized("chat.content_redirect")
                    }
                    return response
                }

                await MainActor.run {
                    isLoading = false
                    withAnimation {
                        messages.append(RikiChatMessage(id: UUID(), text: displayResponse, isFromUser: false))
                    }
                    let persistedModelMsg = PersistedChatMessage(text: displayResponse, isFromUser: false, characterId: character.id)
                    memoryService.saveMessage(persistedModelMsg)
                }

                await audioPlayback.speak(text: displayResponse, characterName: character.name)
            } catch {
                await MainActor.run {
                    isLoading = false
                    let fallback = LanguageManager.shared.localized("riki.error_fallback")
                    withAnimation {
                        messages.append(RikiChatMessage(id: UUID(), text: fallback, isFromUser: false))
                    }
                    print("Gemini chat error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func toggleListening() {
        if audioPlayback.isPlaying { audioPlayback.stop() }

        if isListening {
            stopListening()
            if !inputText.isEmpty { sendMessage() }
        } else {
            startListening()
        }
    }

    private func startListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        audioPlayback.interruptForChildSpeech()

        Task {
            let hasPermission = await requestMicrophonePermission()
            if hasPermission {
                await MainActor.run {
                    withAnimation(KomalAnimations.spring) { isListening = true }
                    speechRecognizer.startRecording()
                }
            } else {
                print("Microphone or speech permission denied")
            }
        }
    }

    private func stopListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        speechRecognizer.stopRecording()
        if !speechRecognizer.transcript.isEmpty {
            inputText = speechRecognizer.transcript
        }
        withAnimation(KomalAnimations.spring) { isListening = false }
    }

    private func requestMicrophonePermission() async -> Bool {
        let micPermissionGranted: Bool
        if #available(iOS 17.0, *) {
            let micStatus = AVAudioApplication.shared.recordPermission
            if micStatus == .undetermined {
                let granted = await AVAudioApplication.requestRecordPermission()
                if !granted { return false }
                micPermissionGranted = granted
            } else if micStatus == .denied {
                return false
            } else {
                micPermissionGranted = (micStatus == .granted)
            }
        } else {
            let session = AVAudioSession.sharedInstance()
            let micStatus = session.recordPermission
            if micStatus == .undetermined {
                var granted = false
                await withCheckedContinuation { continuation in
                    session.requestRecordPermission { isGranted in
                        granted = isGranted
                        continuation.resume()
                    }
                }
                if !granted { return false }
                micPermissionGranted = granted
            } else if micStatus == .denied {
                return false
            } else {
                micPermissionGranted = (micStatus == .granted)
            }
        }

        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        if speechStatus == .notDetermined {
            await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { _ in
                    continuation.resume()
                }
            }
        }
        let speechAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized
        return speechAuthorized && micPermissionGranted
    }
}

// MARK: - Chat Message Model

struct RikiChatMessage: Identifiable {
    let id: UUID
    let text: String
    let isFromUser: Bool
}

// MARK: - Legacy Components (kept for compatibility)

struct StepHeader: View {
    let step: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<4) { index in
                Circle()
                    .fill(index <= step ? KomalColors.bubblegumPink : KomalColors.lavenderPurple.opacity(0.3))
                    .frame(width: 10, height: 10)
            }
        }
    }
}

struct RikiAssistantCard: View {
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        BubblyCard(tintColor: KomalColors.violet) {
            VStack(spacing: 12) {
                RikiAvatarView(size: 100)

                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)

                Text(message)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(KomalColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Button(buttonTitle, action: action)
                    .buttonStyle(SecondaryPillButtonStyle())
            }
        }
    }
}

struct RikiAvatarView: View {
    var size: CGFloat = 150

    var body: some View {
        ZStack {
            BreathingCircle(size: size, color: KomalColors.bubblegumPink.opacity(0.3))

            BreathingCircle(size: size * 0.75, color: KomalColors.pearlAqua.opacity(0.5))

            Image(systemName: "pawprint.fill")
                .font(.system(size: size * 0.35, weight: .semibold))
                .foregroundColor(KomalColors.bubblegumPink)
        }
        .overlay(
            Text("Riki")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(KomalColors.textSecondary),
            alignment: .bottom
        )
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(KomalAnimations.subtle, value: configuration.isPressed)
    }
}
#endif
