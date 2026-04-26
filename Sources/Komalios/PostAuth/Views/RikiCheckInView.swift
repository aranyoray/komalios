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
        LanguageManager.localized("riki.greeting.\(name.lowercased())")
    }

    var localizedPersonality: String {
        LanguageManager.localized("riki.personality.\(name.lowercased())")
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

// MARK: - Emoji Mapper (keyword → contextual emojis triggered by child's speech)

struct ChatEmojiMapper {
    private static let mapping: [(keywords: [String], emoji: String)] = [
        (["happy", "glad", "great", "awesome", "cool", "amazing", "fantastic", "wonderful", "excited", "yay"], "🌟"),
        (["sad", "upset", "down", "cry", "miss", "lonely", "hurt"], "💙"),
        (["brave", "courage", "strong", "hero", "proud", "scared", "afraid", "nervous"], "💪"),
        (["friend", "buddy", "together", "play", "hang out", "team", "group"], "🤝"),
        (["school", "learn", "homework", "study", "class", "test", "teacher", "math", "grade"], "📚"),
        (["game", "gaming", "play", "minecraft", "roblox", "level", "win", "xbox"], "🎮"),
        (["nature", "tree", "garden", "flower", "outside", "park", "beach", "walk"], "🌿"),
        (["animal", "pet", "dog", "cat", "puppy", "kitten", "rabbit", "bird", "fish"], "🐾"),
        (["music", "song", "sing", "dance", "concert", "band", "listen", "playlist"], "🎵"),
        (["food", "eat", "cook", "yummy", "snack", "lunch", "dinner", "pizza", "cookie"], "🍕"),
        (["sleep", "tired", "rest", "nap", "bed", "dream", "night", "sleepy"], "😴"),
        (["love", "care", "heart", "kind", "hug", "family", "mom", "dad", "sister", "brother"], "💛"),
        (["star", "space", "moon", "sky", "planet", "wish", "dream", "hope"], "⭐"),
        (["sport", "soccer", "basketball", "swim", "run", "gym", "exercise", "practice"], "⚽"),
        (["art", "draw", "paint", "create", "color", "craft", "design", "picture"], "🎨"),
        (["think", "idea", "wonder", "curious", "imagine", "why", "how", "question", "confused"], "💡"),
        (["laugh", "funny", "joke", "silly", "haha", "hilarious", "lol", "giggle"], "😄"),
    ]

    /// Returns up to 3 emojis matching keywords in the child's transcript
    static func emojis(for transcript: String) -> [String] {
        let lowered = transcript.lowercased()
        var emojis: [String] = []
        for entry in mapping {
            if entry.keywords.contains(where: { lowered.contains($0) }) {
                emojis.append(entry.emoji)
            }
            if emojis.count >= 3 { break }
        }
        return emojis
    }
}

// MARK: - Floating Single Emoji (gentle drift animation)

private struct FloatingSingleEmoji: View {
    let emoji: String
    let isVisible: Bool
    let driftPhase: Int

    @State private var driftOffset: CGFloat = 0
    @State private var displayOpacity: Double = 0

    var body: some View {
        Text(emoji)
            .font(.system(size: 28))
            .offset(y: driftOffset)
            .opacity(displayOpacity)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(driftPhase) * 0.3) {
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        driftOffset = driftPhase.isMultiple(of: 2) ? -8 : 8
                    }
                }
                withAnimation(.easeInOut(duration: 0.5)) { displayOpacity = 1.0 }
            }
            .onChange(of: isVisible) {
                if isVisible {
                    withAnimation(.easeInOut(duration: 0.5)) { displayOpacity = 1.0 }
                } else {
                    withAnimation(.easeOut(duration: 0.8)) { displayOpacity = 0.0 }
                }
            }
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
    @State private var greetingSpoken: Bool = false
    @State private var displayTranscript: String = ""
    @State private var activeEmojis: [String] = []
    @State private var showEmojis: Bool = false
    @State private var idleRestartTask: Task<Void, Never>?

    // Silence tier tracking — per spec edge case C:
    // After 10s: gentle prompt, After 20s: offer opt-out, After 30s: close loop
    @State private var silenceTierTimer: Timer?
    @State private var silenceTierLevel: Int = 0  // 0=none, 1=10s, 2=20s, 3=30s

    // Mic permission error state (Issue 3 — child-friendly feedback)
    @State private var micPermissionDenied: Bool = false

    // Curriculum session state
    @State private var showCurriculumSession: Bool = false

    // Avatar micro-animation state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isBreathing = false
    @State private var messageWiggle = false

    // Session duration cap (Issue 10 — COPPA: limit continuous mic access)
    @State private var sessionStartTime: Date?
    @State private var sessionCapTimer: Timer?

    @StateObject private var speechRecognizer = SpeechRecognizer()
    @StateObject private var audioPlayback = AudioPlaybackManager()
    @ObservedObject private var rageDetector = RageDetectionService.shared
    @ObservedObject private var networkMonitor = NetworkMonitorService.shared

    private let geminiService = GeminiChatService()
    private let memoryService = ConversationMemoryService.shared

    /// Last 6 messages for display (3 back-and-forth exchanges visible at once)
    private var recentMessages: [RikiChatMessage] {
        Array(messages.suffix(6))
    }

    /// Glow color changes based on state
    private var glowColor: Color {
        if audioPlayback.isPlaying { return KomalColors.pearlAqua }
        if isListening { return KomalColors.bubblegumPink }
        if isLoading { return KomalColors.lavenderPurple.opacity(0.6) }
        return KomalColors.pearlAqua.opacity(0.4)
    }

    /// Status text
    private var curriculumSessionButton: some View {
        let progress = CurriculumSessionView.loadProgress()
        let completed = progress.completedSessionIds.count
        let hasInProgress = progress.currentSessionId != nil
        let nextNum = progress.nextSessionNumber

        return Button(action: { showCurriculumSession = true }) {
            HStack(spacing: 6) {
                Image(systemName: "book.circle.fill")
                    .font(.system(size: 16))
                if hasInProgress {
                    Text(LanguageManager.localized("curriculum.continue", nextNum))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                } else if completed >= 5 {
                    Text(LanguageManager.localized("curriculum.start"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                } else {
                    Text(LanguageManager.localized("curriculum.start"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                if completed > 0 && completed < 5 {
                    Text(LanguageManager.localized("curriculum.completed_badge", completed, 5))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.lavenderPurple.opacity(0.7))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(KomalColors.lavenderPurple.opacity(0.15)))
            .foregroundColor(KomalColors.lavenderPurple)
        }
        .fullScreenCover(isPresented: $showCurriculumSession) {
            CurriculumSessionView(character: character)
                .environmentObject(appState)
        }
        .onChange(of: showCurriculumSession) { _, isPresented in
            if isPresented {
                // Pause Riki's voice loop while curriculum session is active
                // MUST release audio engine tap before CurriculumSessionView installs its own
                if isListening { stopListening() }
                speechRecognizer.stopRecording() // Release AVAudioEngine tap
                silenceTimer?.invalidate()
                silenceTimer = nil
                silenceTierTimer?.invalidate()
                silenceTierTimer = nil
                idleRestartTask?.cancel()
                idleRestartTask = nil
                audioPlayback.stop()
            } else {
                // Resume after session closes — 0.5s delay for session's cleanup() to finish
                if greetingSpoken && !isPaused && !isLoading {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        SpeechRecognizer.configureVoiceChatSession()
                        startListening()
                        startSilenceTierMonitoring(reset: true)
                    }
                }
            }
        }
    }

    private var statusText: String? {
        if isPaused { return LanguageManager.localized("riki.paused") }
        if audioPlayback.isPlaying {
            return LanguageManager.localized("riki.speaking", character.name)
        }
        if isListening {
            return LanguageManager.localized("riki.listening")
        }
        if isLoading {
            return LanguageManager.localized("riki.typing")
        }
        return nil
    }

    /// Micro-scale for breathing/bounce — layered ON TOP of existing listening shrink
    private var avatarMicroScale: CGFloat {
        if reduceMotion { return 1.0 }
        if audioPlayback.isPlaying { return isBreathing ? 1.05 : 1.0 }
        return isBreathing ? 1.03 : 1.0
    }

    private var avatarRotation: Angle {
        if reduceMotion { return .zero }
        if messageWiggle { return .degrees(2) }
        return .zero
    }

    var body: some View {
        GeometryReader { geo in
            let bottomClearance = max(geo.safeAreaInsets.bottom, 49) + 8
            let usableHeight = geo.size.height - geo.safeAreaInsets.top - bottomClearance
            let avatarZoneHeight = min(220, usableHeight * 0.30)
            let avatarSize = avatarZoneHeight * 0.5
            let messagesMaxHeight = min(360, max(160, usableHeight * 0.38))

            VStack(spacing: 0) {
                Spacer().frame(height: 12)

                // Character name header
                Text(character.name)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)

                // Curriculum session button
                curriculumSessionButton
                    .padding(.top, 6)

                Spacer().frame(height: 8)

                // Large avatar with radiating glow — shrink when listening to make room
                avatarSection(
                    avatarSize: isListening ? avatarSize * 0.75 : avatarSize,
                    avatarZoneHeight: isListening ? avatarZoneHeight * 0.75 : avatarZoneHeight
                )
                .animation(.easeInOut(duration: 0.3), value: isListening)

                // Status indicator
                statusBadge
                    .padding(.top, 4)

                // Mic permission error banner
                if micPermissionDenied {
                    HStack(spacing: 8) {
                        Image(systemName: "mic.slash.fill")
                            .foregroundColor(.white)
                        Text(LanguageManager.localized("riki.mic_permission_needed"))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(KomalColors.bubblegumPink.opacity(0.85))
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer().frame(height: 4)

                // Recent messages in a ScrollView
                messagesSection(maxHeight: messagesMaxHeight)

                // Siri-like transcript display — replaces messages space when active
                if isListening {
                    SiriTranscriptView(
                        isListening: isListening,
                        transcript: displayTranscript,
                        glowColor: glowColor
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
                    .transition(.opacity)
                }

                Spacer()

                // Pause/Resume control
                pauseButton(bottomPadding: bottomClearance)
            }
            .animation(.easeInOut(duration: 0.2), value: isListening)
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            // Set audio session once for the entire voice chat session (Issue 1)
            SpeechRecognizer.configureVoiceChatSession()
            sessionStartTime = Date()

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

            // Start session duration cap timer (Issue 10)
            startSessionCapTimer()

            // Start breathing animation
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    isBreathing = true
                }
            }

            Task {
                await audioPlayback.speak(text: greeting, characterName: character.name)
                // Greeting TTS finished — now safe to start auto-listen cycle
                greetingSpoken = true
                startListening()
                startSilenceTierMonitoring(reset: true)
            }
        }
        .onDisappear {
            silenceTimer?.invalidate()
            silenceTimer = nil
            silenceTierTimer?.invalidate()
            silenceTierTimer = nil
            sessionCapTimer?.invalidate()
            sessionCapTimer = nil
            idleRestartTask?.cancel()
            idleRestartTask = nil
            memoryService.endCurrentSession(characterId: character.id)
            rageDetector.reset()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .background {
                isBreathing = false
            } else if scenePhase == .active && !reduceMotion {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    isBreathing = true
                }
            }
        }
        .onReceive(speechRecognizer.$transcript) { newValue in
            if !newValue.isEmpty {
                // Speaker echo guard: if the transcript is a substring of the
                // bot's most recent reply, the mic picked up TTS bleed. Ignore it.
                let lastBotMessage = messages.last(where: { !$0.isFromUser })?.text ?? ""
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let isEcho = !lastBotMessage.isEmpty
                    && trimmed.count < 40
                    && lastBotMessage.lowercased().contains(trimmed)

                if !isEcho {
                    // Stop-phrase detection: child explicitly asks to stop
                    let stopPhrases = ["shut up", "stop talking", "be quiet", "leave me alone",
                                       "go away", "i don't want to talk", "stop it", "just stop"]
                    let lowerTranscript = newValue.lowercased()
                    if stopPhrases.contains(where: { lowerTranscript.contains($0) }) {
                        audioPlayback.stop()
                        stopListening()
                        isPaused = true
                        let gentle = LanguageManager.localized("riki.stop_acknowledged")
                        withAnimation {
                            messages.append(RikiChatMessage(id: UUID(), text: gentle, isFromUser: false))
                        }
                        return
                    }

                    inputText = String(newValue.prefix(2000))
                    displayTranscript = BrowserState.censorForDisplay(newValue)
                    // Reset silence tiers when child starts speaking
                    resetSilenceTiers()
                    // Extract emojis from child's speech
                    let detected = ChatEmojiMapper.emojis(for: newValue)
                    if !detected.isEmpty {
                        activeEmojis = detected
                        if !showEmojis {
                            withAnimation { showEmojis = true }
                        }
                    }
                }
            }
            if isListening && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
        // Auto-start listening after TTS finishes + fade out emojis
        .onReceive(audioPlayback.$isPlaying) { playing in
            if !playing && greetingSpoken {
                withAnimation(.easeOut(duration: 0.8)) { showEmojis = false }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { activeEmojis = [] }
            }
            // Seamless Siri-like flow: auto-listen after every TTS reply finishes.
            // Guard on greetingSpoken to prevent premature listen before greeting plays.
            if !playing && greetingSpoken && !isPaused && !isListening && !isLoading && !showCurriculumSession {
                // 3.0s delay after TTS finishes to give the child breathing room
                // before opening the mic. Also prevents STT from picking up the bot's
                // last words as the child's speech input.
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    // Re-check all conditions after delay — TTS may have started again
                    if !audioPlayback.isPlaying && !isPaused && !isListening && !isLoading && !showCurriculumSession {
                        startListening()
                        startSilenceTierMonitoring()
                    }
                }
            }
            // Fallback idle restart: if somehow idle for 2s, auto-start listening
            if !showCurriculumSession { scheduleIdleRestart() }
        }
    }

    // MARK: - Sub-Views

    @ViewBuilder
    private func avatarSection(avatarSize: CGFloat, avatarZoneHeight: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(glowColor.opacity(0.08))
                .frame(width: avatarZoneHeight, height: avatarZoneHeight)

            Circle()
                .fill(glowColor.opacity(0.15))
                .frame(width: avatarZoneHeight * 0.8, height: avatarZoneHeight * 0.8)

            Circle()
                .fill(glowColor.opacity(0.25))
                .frame(width: avatarZoneHeight * 0.6, height: avatarZoneHeight * 0.6)

            if let uiImage = UIImage(named: character.imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: avatarSize, height: avatarSize)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(glowColor.opacity(0.5), lineWidth: 3)
                    )
                    .scaleEffect(avatarMicroScale)
                    .rotationEffect(avatarRotation)
                    .rotation3DEffect(
                        isListening && !reduceMotion ? .degrees(3) : .degrees(0),
                        axis: (x: 0, y: 1, z: 0)
                    )
            }
        }
        .clipped()
        .animation(.easeInOut(duration: 0.6), value: glowColor)
        .overlay(alignment: .trailing) {
            if !activeEmojis.isEmpty {
                VStack(spacing: 6) {
                    ForEach(Array(activeEmojis.prefix(3).enumerated()), id: \.offset) { index, emoji in
                        FloatingSingleEmoji(emoji: emoji, isVisible: showEmojis, driftPhase: index)
                    }
                }
                .offset(x: 15)
                .allowsHitTesting(false)
            }
        }
        .contentShape(Circle())
        .onTapGesture {
            if audioPlayback.isPlaying {
                conversationInterruptionNote = "[The child interrupted while you were speaking. Acknowledge naturally — say something like 'Okay, I'm listening' and pick up from what they say next.]"
                audioPlayback.interruptForChildSpeech()
                startListening()
                startSilenceTierMonitoring(reset: true)
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
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
    }

    @ViewBuilder
    private func messagesSection(maxHeight: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(Array(recentMessages.enumerated()), id: \.element.id) { index, message in
                        let totalCount = recentMessages.count
                        let fadeOpacity = totalCount <= 1 ? 1.0 : (0.4 + 0.6 * Double(index) / Double(totalCount - 1))

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
                                .fixedSize(horizontal: false, vertical: true)

                            if !message.isFromUser { Spacer(minLength: 60) }
                        }
                        .opacity(fadeOpacity)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8, anchor: message.isFromUser ? .trailing : .leading)
                                .combined(with: .opacity),
                            removal: .opacity
                        ))
                        .id(message.id)
                    }

                    // Typing indicator
                    if isLoading {
                        HStack {
                            HStack(spacing: 5) {
                                ForEach(0..<3) { index in
                                    WaveformDot(delay: Double(index) * 0.2, color: glowColor)
                                }
                                Text(LanguageManager.localized("riki.typing"))
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(KomalColors.textSecondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(glowColor.opacity(0.12))
                            )
                            Spacer(minLength: 60)
                        }
                        .transition(.opacity)
                    }
                }
                .padding(.vertical, 8)
            }
            .onChange(of: messages.count) {
                if let lastId = recentMessages.last?.id {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(maxHeight: maxHeight)
        .animation(.easeInOut(duration: 0.3), value: messages.count)
    }

    @ViewBuilder
    private func pauseButton(bottomPadding: CGFloat) -> some View {
        Button(action: togglePause) {
            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isPaused ? KomalColors.pearlAqua : KomalColors.textSecondary.opacity(0.6))
                .frame(width: 36, height: 36)
                .background(Circle().fill(.ultraThinMaterial))
        }
        .padding(.bottom, bottomPadding)
    }

    // MARK: - Actions

    private func togglePause() {
        isPaused.toggle()
        if isPaused {
            // Pause everything
            silenceTimer?.invalidate()
            silenceTimer = nil
            idleRestartTask?.cancel()
            idleRestartTask = nil
            if isListening { stopListening() }
            audioPlayback.stop()
            showEmojis = false
            activeEmojis = []
        } else {
            // Resume — auto-start listening
            if !isLoading && !audioPlayback.isPlaying {
                startListening()
            }
        }
    }

    private func hardBlockRedirect(ageGroup: AgeGroup) -> String {
        switch ageGroup {
        case .under10:
            return [
                "Let's talk about something really cool instead! What animals do you like?",
                "Ooh I have a great idea — can you tell me about your favorite cartoon?",
                "Let's do something fun together! What game are you playing lately?"
            ].randomElement() ?? "Let's talk about something else!"
        case .tenToThirteen:
            return [
                "Let's switch to something way more interesting — what've you been into lately?",
                "Ok different topic — what's something cool that happened this week?",
                "Hey — tell me something awesome you discovered recently."
            ].randomElement() ?? "Let's talk about something else!"
        case .thirteenToSixteen:
            return [
                "That one's off the table, but I'm all ears for what's actually on your mind.",
                "Let's talk about something else — what's been the best part of your week?",
                "Different direction — what's going on with you today?"
            ].randomElement() ?? "Let's talk about something else!"
        case .sixteenToEighteen, .eighteenPlus:
            return [
                "Let's focus on something I can actually help with — what's on your mind?",
                "I'll pass on that one. Anything else you want to talk through?",
                "Gonna steer away from that one. What else is going on?"
            ].randomElement() ?? "Let's talk about something else!"
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if isListening { stopListening() }

        // Content filter: child exploitation → hard block, everything else → Gemini psychological redirect
        let displayText = BrowserState.censorForDisplay(text)
        var redirectHint: String? = nil
        if let flagged = BrowserState.checkForInappropriateContent(text, isSearchQuery: true) {
            if BrowserState.isChildExploitationKeyword(flagged) {
                // Safety-critical hard block — no Gemini call
                messages.append(RikiChatMessage(id: UUID(), text: displayText, isFromUser: true))
                inputText = ""
                let redirect = hardBlockRedirect(ageGroup: appState.activeProfile.ageGroup)
                withAnimation {
                    messages.append(RikiChatMessage(id: UUID(), text: redirect, isFromUser: false))
                }
                Task { await audioPlayback.speak(text: redirect, characterName: character.name) }
                return
            }
            // All other inappropriate content → route through Gemini with psychological redirect hint
            let ageLabel = appState.activeProfile.ageGroup.rawValue
            redirectHint = "[SYSTEM NOTE — REDIRECT REQUIRED: Child's message contains inappropriate content. Apply psychological redirect for \(ageLabel) age group: use time dilution, cognitive defusion, and scaffolding. Make it educational if possible. Say 'Let's focus on...' not 'I can't talk about that.' Do NOT repeat the flagged word. Bridge to a related safe topic naturally.]"
        }

        let userMessage = RikiChatMessage(id: UUID(), text: displayText, isFromUser: true)
        withAnimation { messages.append(userMessage) }

        let persistedUserMsg = PersistedChatMessage(text: displayText, isFromUser: true, characterId: character.id)
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
                        return LanguageManager.localized("chat.content_redirect")
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

                    // Avatar wiggle on new bot message
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { messageWiggle = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation { messageWiggle = false }
                    }
                }

                await audioPlayback.speak(text: displayResponse, characterName: character.name)
            } catch {
                await MainActor.run {
                    isLoading = false
                    let fallback = LanguageManager.localized("riki.error_fallback")
                    withAnimation {
                        messages.append(RikiChatMessage(id: UUID(), text: fallback, isFromUser: false))
                    }
                    #if DEBUG
                    if let chatError = error as? GeminiChatError {
                        print("Gemini chat error: \(chatError.debugDescription)")
                    } else {
                        print("Gemini chat error: \(error.localizedDescription)")
                    }
                    #endif
                }
                // Speak the fallback so auto-listen resumes after TTS
                await audioPlayback.speak(text: LanguageManager.localized("riki.error_fallback"), characterName: character.name)
            }
        }
    }

    // MARK: - Silence Tier Monitoring (per spec edge case C)

    /// Resume silence monitoring without resetting the tier level.
    /// Called by the auto-listen cycle after a silence prompt's TTS finishes.
    /// Only startSilenceTierMonitoring(reset:true) resets the tier (used on
    /// first listen start and after the child actually speaks).
    private func startSilenceTierMonitoring(reset: Bool = false) {
        silenceTierTimer?.invalidate()
        if reset { silenceTierLevel = 0 }

        // If we already hit tier 3, don't restart monitoring
        guard silenceTierLevel < 3 else { return }

        silenceTierTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
            Task { @MainActor in
                guard isListening && speechRecognizer.transcript.isEmpty && !isPaused else {
                    silenceTierTimer?.invalidate()
                    silenceTierTimer = nil
                    return
                }

                silenceTierLevel += 1

                switch silenceTierLevel {
                case 1:
                    // 10s: Gentle prompt — stop listening first so TTS works
                    stopListening()
                    let gentlePrompt = "I'm right here whenever you're ready to talk."
                    withAnimation {
                        messages.append(RikiChatMessage(id: UUID(), text: gentlePrompt, isFromUser: false))
                    }
                    Task { await audioPlayback.speak(text: gentlePrompt, characterName: character.name) }

                case 2:
                    // 20s: Offer opt-out — stop listening first so TTS works
                    stopListening()
                    let optOut = "No pressure at all! We can chat later if you'd like."
                    withAnimation {
                        messages.append(RikiChatMessage(id: UUID(), text: optOut, isFromUser: false))
                    }
                    Task { await audioPlayback.speak(text: optOut, characterName: character.name) }

                case 3:
                    // 30s: Close loop respectfully — no auto-restart after this
                    stopListening()
                    let closing = "I'll be here whenever you want to talk. See you soon!"
                    withAnimation {
                        messages.append(RikiChatMessage(id: UUID(), text: closing, isFromUser: false))
                    }
                    Task { await audioPlayback.speak(text: closing, characterName: character.name) }

                default:
                    break
                }
            }
        }
    }

    private func resetSilenceTiers() {
        silenceTierTimer?.invalidate()
        silenceTierTimer = nil
        silenceTierLevel = 0
    }

    private func scheduleIdleRestart() {
        idleRestartTask?.cancel()
        idleRestartTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000) // 4s (must exceed 3.0s main delay)
            guard !Task.isCancelled else { return }
            if greetingSpoken && !isPaused && !isListening && !isLoading && !audioPlayback.isPlaying {
                startListening()
                startSilenceTierMonitoring()
            }
        }
    }

    private func startListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil

        // Don't start if session cap reached
        guard !isPaused else { return }

        // Track if we're interrupting the avatar
        if audioPlayback.isPlaying {
            conversationInterruptionNote = "[The child interrupted while you were speaking. Pick up naturally — acknowledge what they said and continue the flow smoothly.]"
            audioPlayback.interruptForChildSpeech()
        }

        // Clear stale input from previous cycle to prevent re-sending old messages
        inputText = ""
        displayTranscript = ""

        Task {
            let hasPermission = await SpeechRecognizer.requestPermissions()
            if hasPermission {
                await MainActor.run {
                    micPermissionDenied = false
                    withAnimation(KomalAnimations.spring) { isListening = true }
                    speechRecognizer.startRecording()
                }
            } else {
                await MainActor.run {
                    withAnimation { micPermissionDenied = true }
                }
            }
        }
    }

    private func stopListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        speechRecognizer.stopRecording()
        if !speechRecognizer.transcript.isEmpty {
            inputText = String(speechRecognizer.transcript.prefix(2000))
        }
        displayTranscript = ""
        withAnimation(KomalAnimations.spring) { isListening = false }
    }

    // MARK: - Session Duration Cap (Issue 10)

    private func startSessionCapTimer() {
        let capMinutes = appState.parentSettings.voiceChatSessionCapMinutes
        guard capMinutes > 0 else { return } // 0 = no limit
        let capSeconds = TimeInterval(capMinutes) * 60

        sessionCapTimer?.invalidate()
        sessionCapTimer = Timer.scheduledTimer(withTimeInterval: capSeconds, repeats: false) { _ in
            Task { @MainActor in
                // Gentle wind-down
                if isListening { stopListening() }
                audioPlayback.stop()
                let windDown = LanguageManager.localized("riki.session_cap_reached")
                withAnimation {
                    messages.append(RikiChatMessage(id: UUID(), text: windDown, isFromUser: false))
                }
                isPaused = true
                Task { await audioPlayback.speak(text: windDown, characterName: character.name) }
            }
        }
    }
}

// MARK: - Siri-Like Transcript View

private struct SiriTranscriptView: View {
    let isListening: Bool
    let transcript: String
    let glowColor: Color

    var body: some View {
        if isListening {
            if transcript.isEmpty {
                // Animated waveform dots while waiting for speech
                HStack(spacing: 6) {
                    ForEach(0..<5) { index in
                        WaveformDot(delay: Double(index) * 0.15, color: glowColor)
                    }
                }
                .frame(height: 36)
                .transition(.opacity)
            } else {
                // Live transcript bubble
                Text(transcript)
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.15), value: transcript)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(glowColor.opacity(0.08))
                    )
                    .transition(.opacity)
            }
        }
    }
}

private struct WaveformDot: View {
    let delay: Double
    let color: Color

    @State private var animating = false

    var body: some View {
        Circle()
            .fill(color.opacity(0.6))
            .frame(width: 8, height: 8)
            .scaleEffect(animating ? 1.4 : 0.6)
            .opacity(animating ? 1.0 : 0.3)
            .animation(
                .easeInOut(duration: 0.6)
                .repeatForever(autoreverses: true)
                .delay(delay),
                value: animating
            )
            .onAppear { animating = true }
    }
}

// MARK: - Chat Message Model

struct RikiChatMessage: Identifiable {
    let id: UUID
    let text: String
    let isFromUser: Bool
}

// MARK: - Shared Components (used by GateView, EmojiCheckInBubble, etc.)

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
