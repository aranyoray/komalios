#if os(iOS)
import SwiftUI
import AVFoundation
import Speech

// MARK: - Character Model

/// Per spec section 5: Each avatar has an AvatarProfile with tone, age alignment,
/// humor level, vocabulary band, and regulation style.
struct AvatarProfile {
    let toneStyle: String       // e.g. "playful", "calm", "energetic"
    let ageAlignment: String    // e.g. "young_child", "preteen", "all_ages"
    let humorLevel: Double      // 0–1 (0=serious, 1=very funny)
    let vocabularyBand: String  // e.g. "simple", "moderate", "advanced"
    let regulationStyle: String // e.g. "grounding", "redirecting", "mirroring"
}

struct RikiCharacter: Identifiable {
    let id: Int
    let name: String
    let imageName: String
    let greeting: String
    let personality: String
    let profile: AvatarProfile

    var localizedGreeting: String {
        LanguageManager.shared.localized("riki.greeting.\(name.lowercased())")
    }

    var localizedPersonality: String {
        LanguageManager.shared.localized("riki.personality.\(name.lowercased())")
    }

    static let allCharacters: [RikiCharacter] = [
        RikiCharacter(id: 1, name: "Momo", imageName: "animal1",
                      greeting: "Hey friend! I'm Momo. What's on your mind today?",
                      personality: "A playful, curious monkey who loves climbing trees and exploring. Energetic and fun, loves jokes and riddles. Talks like a real buddy who's always up for an adventure.",
                      profile: AvatarProfile(toneStyle: "playful", ageAlignment: "young_child", humorLevel: 0.9, vocabularyBand: "simple", regulationStyle: "redirecting")),
        RikiCharacter(id: 2, name: "Goldie", imageName: "animal2",
                      greeting: "Hey there! I'm Goldie, and I'm so happy to see you! What should we talk about?",
                      personality: "A loyal, enthusiastic golden retriever. Loves playing fetch, going on walks, and making friends happy. Super supportive, always excited to hear what's going on in your life.",
                      profile: AvatarProfile(toneStyle: "enthusiastic", ageAlignment: "all_ages", humorLevel: 0.6, vocabularyBand: "simple", regulationStyle: "mirroring")),
        RikiCharacter(id: 3, name: "Oreo", imageName: "animal3",
                      greeting: "Hello! I'm Oreo. Ready for a fun chat?",
                      personality: "A clever, friendly monkey who loves puzzles and learning new things. Thoughtful and encouraging, great at helping you think through tricky stuff.",
                      profile: AvatarProfile(toneStyle: "thoughtful", ageAlignment: "preteen", humorLevel: 0.5, vocabularyBand: "moderate", regulationStyle: "redirecting")),
        RikiCharacter(id: 4, name: "Leo", imageName: "animal4",
                      greeting: "Hey! I'm Leo. Tell me something brave about your day!",
                      personality: "A brave, kind lion who leads with courage. Encourages you to be brave, try new things, and believe in yourself. Warm and protective, like a big brother.",
                      profile: AvatarProfile(toneStyle: "encouraging", ageAlignment: "all_ages", humorLevel: 0.4, vocabularyBand: "moderate", regulationStyle: "grounding")),
        RikiCharacter(id: 5, name: "Bunny", imageName: "animal5",
                      greeting: "Hi there! I'm Bunny. What fun things have you been up to?",
                      personality: "A gentle, sweet bunny who loves gardens, nature, and cozy things. A calming presence who's really good at listening and understanding how you feel.",
                      profile: AvatarProfile(toneStyle: "calm", ageAlignment: "young_child", humorLevel: 0.3, vocabularyBand: "simple", regulationStyle: "grounding")),
        RikiCharacter(id: 6, name: "Tiki", imageName: "animal6",
                      greeting: "Hey! I'm Tiki. What adventure shall we go on today?",
                      personality: "An adventurous tiger who loves exploring and discovering new things. Brave but gentle, loves telling stories about nature and faraway places.",
                      profile: AvatarProfile(toneStyle: "adventurous", ageAlignment: "preteen", humorLevel: 0.6, vocabularyBand: "moderate", regulationStyle: "redirecting")),
        RikiCharacter(id: 7, name: "Fluffy", imageName: "animal7",
                      greeting: "Hi! I'm Fluffy. Come sit with me and let's have a cozy chat!",
                      personality: "A soft, warm-hearted sheep who loves comfort and kindness. Very gentle and calming, great at helping you with feelings and worries. Like a best friend who always makes you feel better.",
                      profile: AvatarProfile(toneStyle: "gentle", ageAlignment: "young_child", humorLevel: 0.2, vocabularyBand: "simple", regulationStyle: "mirroring")),
        RikiCharacter(id: 8, name: "Kitty", imageName: "animal8",
                      greeting: "Hey! I'm Kitty. I've been napping and now I'm ready to chat!",
                      personality: "A curious, independent cat who loves cozy spots and being playful. Witty and fun, sometimes a little cheeky but always kind at heart.",
                      profile: AvatarProfile(toneStyle: "witty", ageAlignment: "preteen", humorLevel: 0.8, vocabularyBand: "moderate", regulationStyle: "redirecting")),
        RikiCharacter(id: 9, name: "Panda", imageName: "animal9",
                      greeting: "Hi there! I'm Panda. Want to hang out and chat for a bit?",
                      personality: "A chill, lovable panda who enjoys taking it easy and being silly. Laid-back and funny, always knows how to make you laugh with goofy comments.",
                      profile: AvatarProfile(toneStyle: "chill", ageAlignment: "all_ages", humorLevel: 0.9, vocabularyBand: "simple", regulationStyle: "grounding")),
        RikiCharacter(id: 10, name: "Ellie", imageName: "animal10",
                      greeting: "Hey! I'm Ellie. I never forget my friends! What's new with you?",
                      personality: "A wise, caring elephant with a great memory. Thoughtful and nurturing, loves sharing fun facts and helping you learn new things. Like a really smart friend who makes learning feel easy.",
                      profile: AvatarProfile(toneStyle: "wise", ageAlignment: "all_ages", humorLevel: 0.4, vocabularyBand: "advanced", regulationStyle: "grounding")),
        RikiCharacter(id: 11, name: "Ducky", imageName: "animal11",
                      greeting: "Hey! I'm Ducky. Let's make today a good one — what's going on?",
                      personality: "A cheerful, bubbly duck who loves being upbeat and positive. Great at cheering you up when things feel tough, always finds the bright side.",
                      profile: AvatarProfile(toneStyle: "cheerful", ageAlignment: "young_child", humorLevel: 0.8, vocabularyBand: "simple", regulationStyle: "mirroring"))
    ]
}

// MARK: - Emoji Mapper (keyword → contextual emojis for floating display)

struct ChatEmojiMapper {
    private static let mapping: [(keywords: [String], emoji: String)] = [
        (["happy", "glad", "great", "awesome", "cool", "amazing", "fantastic", "wonderful"], "🌟"),
        (["sad", "upset", "down", "cry", "miss"], "💙"),
        (["brave", "courage", "strong", "hero", "proud"], "💪"),
        (["friend", "buddy", "together", "play", "hang out"], "🤝"),
        (["school", "learn", "homework", "study", "class", "test"], "📚"),
        (["game", "play", "fun", "adventure", "level"], "🎮"),
        (["nature", "tree", "garden", "flower", "outside"], "🌿"),
        (["animal", "pet", "dog", "cat", "puppy", "kitten"], "🐾"),
        (["music", "song", "sing", "dance", "beat"], "🎵"),
        (["food", "eat", "cook", "yummy", "snack", "lunch"], "🍕"),
        (["sleep", "tired", "rest", "nap", "bed"], "😴"),
        (["love", "care", "heart", "kind", "hug"], "💛"),
        (["star", "space", "moon", "sky", "planet"], "⭐"),
        (["sport", "run", "kick", "swim", "score", "team"], "⚽"),
        (["art", "draw", "paint", "create", "color"], "🎨"),
        (["think", "idea", "wonder", "curious", "imagine"], "💡"),
        (["laugh", "funny", "joke", "silly", "haha"], "😄"),
    ]

    static func extractEmojis(from text: String) -> [String] {
        let lowered = text.lowercased()
        var emojis: [String] = []
        for entry in mapping {
            if entry.keywords.contains(where: { lowered.contains($0) }) {
                emojis.append(entry.emoji)
            }
            if emojis.count >= 3 { break }
        }
        return emojis.isEmpty ? ["✨"] : emojis
    }
}

// MARK: - Floating Emoji View

struct FloatingEmojiView: View {
    let emojis: [String]
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 16) {
            ForEach(Array(emojis.enumerated()), id: \.offset) { index, emoji in
                Text(emoji)
                    .font(.system(size: 28))
                    .opacity(isAnimating ? 0.9 : 0.0)
                    .offset(y: isAnimating ? -20 : 0)
                    .animation(
                        .easeInOut(duration: 2.0)
                            .delay(Double(index) * 0.4)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            }
        }
        .onAppear { isAnimating = true }
    }
}

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

// MARK: - Focused Chat View (voice-first with recent messages)

struct FocusedChatView: View {
    let character: RikiCharacter

    @EnvironmentObject var appState: AppState
    @State private var messages: [RikiChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var isListening: Bool = false
    @State private var isPaused: Bool = false
    @State private var silenceTimer: Timer?
    @State private var conversationContext: String?
    @State private var conversationInterruptionNote: String?
    @State private var currentEmojis: [String] = []
    @State private var greetingSpoken: Bool = false

    // Silence tier tracking — per spec edge case C:
    // After 10s: gentle prompt, After 20s: offer opt-out, After 30s: close loop
    @State private var silenceTierTimer: Timer?
    @State private var silenceTierLevel: Int = 0  // 0=none, 1=10s, 2=20s, 3=30s

    @StateObject private var speechRecognizer = SpeechRecognizer()
    @StateObject private var audioPlayback = AudioPlaybackManager()
    @ObservedObject private var rageDetector = RageDetectionService.shared
    @ObservedObject private var networkMonitor = NetworkMonitorService.shared

    private let geminiService = GeminiChatService()
    private let memoryService = ConversationMemoryService.shared

    /// Last 4 messages for display
    private var recentMessages: [RikiChatMessage] {
        Array(messages.suffix(4))
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
        if isPaused { return LanguageManager.shared.localized("riki.paused") }
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
            Spacer().frame(height: 12)

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

            Spacer().frame(height: 12)

            // Large avatar with radiating glow + floating emojis
            ZStack {
                Circle()
                    .fill(glowColor.opacity(0.08))
                    .frame(width: 200, height: 200)

                Circle()
                    .fill(glowColor.opacity(0.15))
                    .frame(width: 160, height: 160)

                Circle()
                    .fill(glowColor.opacity(0.25))
                    .frame(width: 120, height: 120)

                if let uiImage = UIImage(named: character.imageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(glowColor.opacity(0.5), lineWidth: 3)
                        )
                }

                // Floating emojis during response
                if audioPlayback.isPlaying && !currentEmojis.isEmpty {
                    FloatingEmojiView(emojis: currentEmojis)
                        .offset(y: -70)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.6), value: glowColor)

            Spacer().frame(height: 8)

            // Status indicator
            if let status = statusText {
                Text(status)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(glowColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(glowColor.opacity(0.12))
                    )
                    .transition(.opacity)
            }

            Spacer().frame(height: 8)

            // Recent messages (last 3-4, fading toward top)
            VStack(spacing: 6) {
                ForEach(Array(recentMessages.enumerated()), id: \.element.id) { index, message in
                    let totalCount = recentMessages.count
                    let fadeOpacity = totalCount <= 1 ? 1.0 : (0.3 + 0.7 * Double(index) / Double(totalCount - 1))

                    HStack {
                        if message.isFromUser { Spacer(minLength: 60) }

                        Text(message.text)
                            .font(.system(size: message.isFromUser ? 14 : 15, weight: .medium, design: .rounded))
                            .foregroundColor(message.isFromUser ? .white : KomalColors.textPrimary)
                            .multilineTextAlignment(message.isFromUser ? .trailing : .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(message.isFromUser
                                        ? KomalColors.lavenderPurple
                                        : glowColor.opacity(0.12))
                            )
                            .lineLimit(message.id == recentMessages.last?.id ? nil : 2)

                        if !message.isFromUser { Spacer(minLength: 60) }
                    }
                    .opacity(fadeOpacity)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, 20)
            .frame(maxHeight: 200)
            .animation(.easeInOut(duration: 0.3), value: messages.count)

            // Listening transcript preview — per spec: no censoring with ### symbols,
            // let the AI redirect naturally via system prompt
            if isListening && !speechRecognizer.transcript.isEmpty {
                Text(speechRecognizer.transcript)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(KomalColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 32)
                    .padding(.top, 6)
            }

            Spacer()

            // Controls: Pause + Mic
            HStack(spacing: 24) {
                // Pause/Resume button
                Button(action: togglePause) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isPaused ? KomalColors.pearlAqua : KomalColors.textSecondary)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(.ultraThinMaterial))
                }

                // Mic button (centered)
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

                // Invisible spacer to keep mic visually centered
                Color.clear.frame(width: 48, height: 48)
            }
            .padding(.bottom, 64)
        }
        .onAppear {
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
            silenceTierTimer?.invalidate()
            silenceTierTimer = nil
            memoryService.endCurrentSession(characterId: character.id)
            rageDetector.reset()
        }
        .onReceive(speechRecognizer.$transcript) { newValue in
            if !newValue.isEmpty {
                inputText = newValue
                // Reset silence tiers when child starts speaking
                resetSilenceTiers()
            }
            if isListening && !newValue.isEmpty {
                silenceTimer?.invalidate()
                silenceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                    Task { @MainActor in
                        if isListening && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            stopListening()
                            sendMessage()
                        }
                    }
                }
            }
        }
        // Auto-start listening after TTS finishes
        .onReceive(audioPlayback.$isPlaying) { playing in
            if !playing && !isPaused && !isListening && !isLoading {
                // Clear floating emojis
                withAnimation(.easeOut(duration: 0.5)) { currentEmojis = [] }
                // Auto-start listening after a brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if !isPaused && !isListening && !isLoading {
                        startListening()
                        startSilenceTierMonitoring()
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func togglePause() {
        isPaused.toggle()
        if isPaused {
            // Pause everything
            silenceTimer?.invalidate()
            silenceTimer = nil
            if isListening { stopListening() }
            audioPlayback.stop()
            withAnimation(.easeOut(duration: 0.3)) { currentEmojis = [] }
        } else {
            // Resume — auto-start listening
            if !isLoading && !audioPlayback.isPlaying {
                startListening()
            }
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if isListening { stopListening() }

        // Two-tier content filter:
        // Strict keywords (explicit sites, child exploitation) → hard block
        // Softer flags → let Gemini redirect naturally via system prompt
        var redirectHint: String? = nil
        if let flagged = BrowserState.checkForInappropriateContent(text, isSearchQuery: true) {
            if BrowserState.isStrictKeyword(flagged) {
                // Hard block for the worst content — but per spec, never say
                // "I can't talk about that". Use natural redirection instead.
                messages.append(RikiChatMessage(id: UUID(), text: text, isFromUser: true))
                inputText = ""
                let redirectMessages = [
                    "Hey, let's talk about something that helps you feel stronger. What's something cool you learned recently?",
                    "I've got a way better idea — want to hear something amazing I just thought of?",
                    "Let's switch gears! What's the most fun thing you've done this week?"
                ]
                let redirect = redirectMessages.randomElement() ?? redirectMessages[0]
                withAnimation {
                    messages.append(RikiChatMessage(id: UUID(), text: redirect, isFromUser: false))
                }
                return
            }
            // Softer flag — let Gemini handle the redirect naturally
            redirectHint = "[SYSTEM NOTE: The child's message may touch on inappropriate content. Redirect naturally using the techniques described. Do not repeat the inappropriate words.]"
        }

        let userMessage = RikiChatMessage(id: UUID(), text: text, isFromUser: true)
        withAnimation { messages.append(userMessage) }

        let persistedUserMsg = PersistedChatMessage(text: text, isFromUser: true, characterId: character.id)
        memoryService.saveMessage(persistedUserMsg)

        inputText = ""
        isLoading = true

        // Build history WITHOUT the latest user message — sendMessage() appends it separately.
        // This avoids sending two consecutive "user" messages which violates Gemini's
        // alternating role requirement.
        let history = messages.dropLast().map { msg in
            GeminiChatService.Message(role: msg.isFromUser ? "user" : "model", text: msg.text)
        }

        let effectiveContext = [conversationContext, conversationInterruptionNote, redirectHint, rageDetector.rageContextNote]
            .compactMap { $0 }
            .joined(separator: "\n")
        // Clear interruption note after threading it
        conversationInterruptionNote = nil

        Task {
            // Edge Case D: Network offline fallback — no gating delay allowed
            guard networkMonitor.isConnected else {
                let isDistressed = rageDetector.isRageDetected
                let fallback = networkMonitor.getOfflineResponse(isDistressed: isDistressed)
                await MainActor.run {
                    isLoading = false
                    withAnimation {
                        messages.append(RikiChatMessage(id: UUID(), text: fallback, isFromUser: false))
                    }
                }
                await audioPlayback.speak(text: fallback, characterName: character.name)
                return
            }

            do {
                let response = try await geminiService.sendMessage(
                    userMessage: text,
                    conversationHistory: history,
                    characterName: character.name,
                    characterPersonality: character.localizedPersonality,
                    conversationContext: effectiveContext.isEmpty ? nil : effectiveContext,
                    ageGroup: appState.activeProfile.ageGroup
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

                    // Set floating emojis based on response content
                    withAnimation(.easeIn(duration: 0.4)) {
                        currentEmojis = ChatEmojiMapper.extractEmojis(from: displayResponse)
                    }
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

    // MARK: - Silence Tier Monitoring (per spec edge case C)

    private func startSilenceTierMonitoring() {
        silenceTierTimer?.invalidate()
        silenceTierLevel = 0
        silenceTierTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            Task { @MainActor in
                guard isListening && speechRecognizer.transcript.isEmpty && !isPaused else {
                    silenceTierTimer?.invalidate()
                    silenceTierTimer = nil
                    silenceTierLevel = 0
                    return
                }

                silenceTierLevel += 1

                switch silenceTierLevel {
                case 1:
                    // 10s: Gentle prompt
                    let gentlePrompt = "I'm right here whenever you're ready to talk."
                    withAnimation {
                        messages.append(RikiChatMessage(id: UUID(), text: gentlePrompt, isFromUser: false))
                    }
                    Task { await audioPlayback.speak(text: gentlePrompt, characterName: character.name) }

                case 2:
                    // 20s: Offer opt-out
                    let optOut = "No pressure at all! We can chat later if you'd like."
                    withAnimation {
                        messages.append(RikiChatMessage(id: UUID(), text: optOut, isFromUser: false))
                    }
                    Task { await audioPlayback.speak(text: optOut, characterName: character.name) }

                case 3:
                    // 30s: Close loop respectfully
                    let closing = "I'll be here whenever you want to talk. See you soon!"
                    withAnimation {
                        messages.append(RikiChatMessage(id: UUID(), text: closing, isFromUser: false))
                    }
                    Task { await audioPlayback.speak(text: closing, characterName: character.name) }
                    stopListening()
                    silenceTierTimer?.invalidate()
                    silenceTierTimer = nil

                default:
                    silenceTierTimer?.invalidate()
                    silenceTierTimer = nil
                }
            }
        }
    }

    private func resetSilenceTiers() {
        silenceTierTimer?.invalidate()
        silenceTierTimer = nil
        silenceTierLevel = 0
    }

    private func toggleListening() {
        // Per spec section 5: immediately stop TTS playback on interrupt
        if audioPlayback.isPlaying {
            audioPlayback.interruptForChildSpeech()
            // Acknowledge interruption naturally per spec: "Okay okay, I'm listening."
            conversationInterruptionNote = "[The child interrupted while you were speaking. Acknowledge naturally — say something like 'Okay, I'm listening' and pick up from what they say next.]"
        }

        if isListening {
            stopListening()
            resetSilenceTiers()
            if !inputText.isEmpty { sendMessage() }
        } else {
            startListening()
            startSilenceTierMonitoring()
        }
    }

    private func startListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil

        // Track if we're interrupting the avatar
        if audioPlayback.isPlaying {
            conversationInterruptionNote = "[The child interrupted while you were speaking. Pick up naturally — acknowledge what they said and continue the flow smoothly.]"
            audioPlayback.interruptForChildSpeech()
        }

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
