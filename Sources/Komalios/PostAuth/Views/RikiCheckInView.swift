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

// MARK: - Main View

struct RikiCheckInView: View {
    @State private var selectedCharacter: RikiCharacter? = nil

    var body: some View {
        ZStack {
            GradientBackground()

            if let character = selectedCharacter {
                CharacterChatView(character: character) {
                    withAnimation(KomalAnimations.spring) {
                        selectedCharacter = nil
                    }
                }
            } else {
                CharacterSelectionView { character in
                    withAnimation(KomalAnimations.spring) {
                        selectedCharacter = character
                    }
                }
            }
        }
    }
}

// MARK: - Character Selection View

struct CharacterSelectionView: View {
    let onSelect: (RikiCharacter) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 6) {
                Text("Choose a Friend")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)

                Text("Who would you like to chat with?")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(KomalColors.textSecondary)
            }
            .padding(.top, 16)

            // Character Grid - Bento Style
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(RikiCharacter.allCharacters) { character in
                        CharacterCard(character: character) {
                            onSelect(character)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
        }
    }
}

// MARK: - Character Card (Bento Style)

struct CharacterCard: View {
    let character: RikiCharacter
    let onTap: () -> Void

    // Grey color matching the image backgrounds (#86868a)
    private let cardBackground = Color(red: 0x86/255, green: 0x86/255, blue: 0x8a/255)

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Character Image
                if let uiImage = UIImage(named: character.imageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 56, height: 56)
                } else {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 28))
                        .foregroundColor(KomalColors.bubblegumPink)
                        .frame(width: 56, height: 56)
                }

                // Character Name - White text
                Text(character.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(cardBackground)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(KomalAnimations.subtle, value: configuration.isPressed)
    }
}

// MARK: - Chat View

struct CharacterChatView: View {
    let character: RikiCharacter
    let onBack: () -> Void

    @State private var messages: [RikiChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var isListening: Bool = false
    @State private var silenceTimer: Timer?
    @FocusState private var isInputFocused: Bool

    @StateObject private var speechRecognizer = SpeechRecognizer()
    @StateObject private var audioPlayback = AudioPlaybackManager()

    private let geminiService = GeminiChatService()

    private var lastCharacterMessageId: UUID? {
        messages.last(where: { !$0.isFromUser })?.id
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader

            // Messages
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            ChatBubble(
                                message: message,
                                character: character,
                                isSpeaking: !message.isFromUser && message.id == lastCharacterMessageId && audioPlayback.isPlaying
                            )
                        }

                        // Typing indicator
                        if isLoading {
                            TypingIndicator(character: character)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    .id("bottom")
                }
                .onChange(of: messages.count) { _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onChange(of: isLoading) { _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }

            // Input Area
            inputArea
        }
        .onAppear {
            // Add greeting message
            messages.append(RikiChatMessage(
                id: UUID(),
                text: character.greeting,
                isFromUser: false
            ))
            // Speak the greeting via TTS
            Task {
                await audioPlayback.speak(text: character.greeting, characterName: character.name)
            }
        }
        .onDisappear {
            silenceTimer?.invalidate()
            silenceTimer = nil
        }
        .onReceive(speechRecognizer.$transcript) { newValue in
            if !newValue.isEmpty {
                inputText = newValue
            }
            // Reset 3-second silence timer for auto-send
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

    // MARK: - Chat Header

    private var chatHeader: some View {
        HStack(spacing: 12) {
            // Back button
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(KomalColors.bubblegumPink)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
            }

            // Character avatar
            if let uiImage = UIImage(named: character.imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(KomalColors.pearlAqua, lineWidth: 2)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(character.name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)

                HStack(spacing: 4) {
                    Circle()
                        .fill(KomalColors.pearlAqua)
                        .frame(width: 8, height: 8)
                    Text(isLoading ? "Typing..." : "Online")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.textSecondary)
                }
            }

            Spacer()

            // Mute/unmute TTS button
            Button(action: { audioPlayback.isMuted.toggle() }) {
                Image(systemName: audioPlayback.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(audioPlayback.isMuted ? KomalColors.textSecondary : KomalColors.lavenderPurple)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }

    // MARK: - Input Area (Voice-Only)

    private var inputArea: some View {
        VStack(spacing: 0) {
            // Listening indicator
            if isListening {
                HStack(spacing: 8) {
                    BreathingCircle(size: 12, color: KomalColors.bubblegumPink)
                    Text("Listening...")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.bubblegumPink)
                    if !speechRecognizer.transcript.isEmpty {
                        Text(speechRecognizer.transcript)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(KomalColors.textSecondary)
                            .lineLimit(2)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
            }

            // Voice playback indicator
            if audioPlayback.isPlaying {
                HStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(KomalColors.lavenderPurple)
                    Text("\(character.name) is speaking...")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.lavenderPurple)
                }
                .padding(.vertical, 6)
            }

            // Voice-only input: large mic button centered
            VStack(spacing: 8) {
                Text(isListening ? "Tap to send" : "Tap to talk")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(KomalColors.textSecondary)

                Button(action: toggleListening) {
                    Image(systemName: isListening ? "waveform" : "mic.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 64, height: 64)
                        .background(
                            Circle()
                                .fill(isListening ? KomalColors.bubblegumPink : KomalColors.lavenderPurple)
                        )
                        .shadow(color: (isListening ? KomalColors.bubblegumPink : KomalColors.lavenderPurple).opacity(0.4), radius: 8, x: 0, y: 4)
                        .scaleEffect(isListening ? 1.15 : 1.0)
                        .animation(KomalAnimations.spring, value: isListening)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.bottom, 100) // Space for floating menu
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: -2)
            )
        }
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Stop listening if active
        if isListening {
            stopListening()
        }

        let userMessage = RikiChatMessage(id: UUID(), text: text, isFromUser: true)
        withAnimation {
            messages.append(userMessage)
        }
        inputText = ""
        isInputFocused = false
        isLoading = true

        // Build conversation history for context
        let history = messages.map { msg in
            GeminiChatService.Message(
                role: msg.isFromUser ? "user" : "model",
                text: msg.text
            )
        }

        Task {
            do {
                let response = try await geminiService.sendMessage(
                    userMessage: text,
                    conversationHistory: history,
                    characterName: character.name,
                    characterPersonality: character.personality
                )

                await MainActor.run {
                    isLoading = false
                    let responseMessage = RikiChatMessage(id: UUID(), text: response, isFromUser: false)
                    withAnimation {
                        messages.append(responseMessage)
                    }
                }

                // Speak the response via TTS
                await audioPlayback.speak(text: response, characterName: character.name)
            } catch {
                await MainActor.run {
                    isLoading = false
                    let fallback = "Oops! I got a little confused there. Can you try saying that again?"
                    let responseMessage = RikiChatMessage(id: UUID(), text: fallback, isFromUser: false)
                    withAnimation {
                        messages.append(responseMessage)
                    }
                    print("Gemini chat error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func toggleListening() {
        // Stop any playing audio when toggling
        if audioPlayback.isPlaying {
            audioPlayback.stop()
        }

        if isListening {
            stopListening()
            // Send the transcribed text if any
            if !inputText.isEmpty {
                sendMessage()
            }
        } else {
            startListening()
        }
    }

    private func startListening() {
        // Cancel any existing silence timer
        silenceTimer?.invalidate()
        silenceTimer = nil
        // Interrupt any character speech when child starts talking
        audioPlayback.interruptForChildSpeech()

        Task {
            let hasPermission = await requestMicrophonePermission()
            if hasPermission {
                await MainActor.run {
                    withAnimation(KomalAnimations.spring) {
                        isListening = true
                    }
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
        // Capture final transcript
        if !speechRecognizer.transcript.isEmpty {
            inputText = speechRecognizer.transcript
        }
        withAnimation(KomalAnimations.spring) {
            isListening = false
        }
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

        // Check speech recognition permission
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

// MARK: - Typing Indicator

struct TypingIndicator: View {
    let character: RikiCharacter
    @State private var dotCount = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Character avatar
            if let uiImage = UIImage(named: character.imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
            }

            HStack(spacing: 6) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(KomalColors.lavenderPurple)
                        .frame(width: 8, height: 8)
                        .scaleEffect(dotCount == index ? 1.3 : 0.8)
                        .opacity(dotCount == index ? 1.0 : 0.4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            )

            Spacer(minLength: 60)
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    dotCount = (dotCount + 1) % 3
                }
            }
        }
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: RikiChatMessage
    let character: RikiCharacter
    var isSpeaking: Bool = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromUser {
                Spacer(minLength: 60)
            } else {
                // Character avatar for their messages
                ZStack(alignment: .bottomTrailing) {
                    if let uiImage = UIImage(named: character.imageName) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(KomalColors.lavenderPurple.opacity(0.3))
                            .frame(width: 32, height: 32)
                    }

                    // Speaking indicator
                    if isSpeaking {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .padding(3)
                            .background(Circle().fill(KomalColors.lavenderPurple))
                            .offset(x: 4, y: 4)
                    }
                }
            }

            Text(message.text)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(message.isFromUser ? .white : KomalColors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(message.isFromUser ? KomalColors.bubblegumPink : Color.white)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                )

            if !message.isFromUser {
                Spacer(minLength: 60)
            }
        }
    }
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
#endif
