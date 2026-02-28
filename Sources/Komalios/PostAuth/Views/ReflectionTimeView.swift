#if os(iOS)
import SwiftUI
import AVFoundation
import Speech

// MARK: - Reflection Time Main View

struct ReflectionTimeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var currentSession: SessionType = .welcome
    @State private var timeRemaining: Int = 15 * 60 // 15 minutes
    @State private var timerActive = false
    @State private var currentQuestionIndex = 0
    @State private var userResponses: [String] = []
    @State private var currentResponse = ""
    @State private var showCompletion = false
    @State private var sessionTimer: Timer?

    private var isYoungerChild: Bool {
        appState.activeProfile.ageGroup == .under10 || appState.activeProfile.ageGroup == .tenToThirteen
    }

    enum SessionType {
        case welcome
        case sel // Social-Emotional Learning
        case freeChat // Open conversation
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Calming gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.95, blue: 1.0),
                        Color(red: 0.9, green: 0.95, blue: 0.98)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Timer bar
                    if timerActive {
                        TimerBar(timeRemaining: timeRemaining, totalTime: 15 * 60)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                    }

                    // Content
                    switch currentSession {
                    case .welcome:
                        welcomeView
                    case .sel:
                        selSessionView
                    case .freeChat:
                        freeChatView
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.gray.opacity(0.6))
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(LanguageManager.shared.localized("reflect.title"))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                }
            }
            .sheet(isPresented: $showCompletion) {
                CompletionView(dismiss: dismiss)
            }
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            // Stop the timer when leaving the Reflect tab
            sessionTimer?.invalidate()
            sessionTimer = nil
            timerActive = false
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timerActive = true
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            Task { @MainActor in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    timer.invalidate()
                    showCompletion = true
                }
            }
        }
    }

    // MARK: - Welcome View

    private var welcomeView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 20)

                // Icon
                ZStack {
                    Circle()
                        .fill(KomalColors.lavenderPurple.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Image(systemName: "leaf.fill")
                        .font(.system(size: 44))
                        .foregroundColor(KomalColors.lavenderPurple)
                }

                VStack(spacing: 8) {
                    Text(LanguageManager.shared.localized("reflect.welcome.title"))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(KomalColors.textPrimary)

                    Text(LanguageManager.shared.localized("reflect.welcome.subtitle"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(KomalColors.textSecondary)
                }

                // Session options
                VStack(spacing: 12) {
                    SessionOptionCard(
                        icon: "brain.head.profile",
                        title: LanguageManager.shared.localized("reflect.daily_checkin.title"),
                        description: LanguageManager.shared.localized("reflect.daily_checkin.desc"),
                        color: KomalColors.bubblegumPink
                    ) {
                        withAnimation { currentSession = .sel }
                    }

                    SessionOptionCard(
                        icon: "bubble.left.and.bubble.right.fill",
                        title: LanguageManager.shared.localized("reflect.free_chat.title"),
                        description: LanguageManager.shared.localized("reflect.free_chat.desc"),
                        color: Color.orange
                    ) {
                        withAnimation { currentSession = .freeChat }
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }

    // MARK: - SEL Session View (Social-Emotional Learning)

    private var selSessionView: some View {
        SELDailySessionView(onComplete: { withAnimation { currentSession = .welcome } })
    }

    // MARK: - Free Chat View

    private var freeChatView: some View {
        FreeChatSessionView(onBack: { withAnimation { currentSession = .welcome } })
    }
}

// MARK: - Timer Bar

struct TimerBar: View {
    let timeRemaining: Int
    let totalTime: Int

    private var progress: Double {
        min(max(Double(totalTime - timeRemaining) / Double(max(totalTime, 1)), 0.0), 1.0)
    }

    private var timeString: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(KomalColors.lavenderPurple)

                Text(timeString)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(KomalColors.textPrimary)

                Spacer()

                Text(LanguageManager.shared.localized("reflect.remaining"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(KomalColors.textSecondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(KomalColors.lavenderPurple)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .background(Color.white.opacity(0.8))
        .cornerRadius(12)
    }
}

// MARK: - Session Option Card

struct SessionOptionCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(color)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(KomalColors.textPrimary)

                    Text(description)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(KomalColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.gray.opacity(0.4))
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Emotion Button

struct EmotionButton: View {
    let emoji: String
    let label: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text(emoji)
                    .font(.system(size: 32))

                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? color : KomalColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? color.opacity(0.15) : Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color : Color.gray.opacity(0.1), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Free Chat Session (Gemini-powered)

struct FreeChatSessionView: View {
    let onBack: () -> Void
    @EnvironmentObject private var appState: AppState
    @State private var messages: [ReflectionChatMessage] = []
    @State private var inputText = ""
    @State private var isGenerating = false
    @State private var isRecording = false
    @StateObject private var speechRecognizer = SpeechRecognizer()

    /// characterId 0 is reserved for the Reflect free-chat session
    private static let reflectCharacterId = 0
    private let memoryService = ConversationMemoryService.shared

    var body: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text(LanguageManager.shared.localized("common.back"))
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(KomalColors.lavenderPurple)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            FreeChatBubble(message: message)
                        }

                        if isGenerating {
                            HStack {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                    Text(LanguageManager.shared.localized("reflect.free_chat.thinking"))
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(KomalColors.textSecondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color.white)
                                )
                                Spacer(minLength: 60)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    .id("bottom")
                }
                .onChange(of: messages.count) {
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }

            // Input with speech-to-text
            HStack(spacing: 8) {
                // Mic button for STT accessibility
                Button(action: toggleSpeechToText) {
                    Image(systemName: isRecording ? "waveform" : "mic.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isRecording ? .white : KomalColors.lavenderPurple)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(isRecording ? KomalColors.bubblegumPink : KomalColors.lavenderPurple.opacity(0.12))
                        )
                        .animation(KomalAnimations.spring, value: isRecording)
                }

                TextField(LanguageManager.shared.localized("reflect.free_chat.placeholder"), text: $inputText)
                    .font(.system(size: 16, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(isRecording ? KomalColors.bubblegumPink.opacity(0.5) : Color.black.opacity(0.1), lineWidth: isRecording ? 1.5 : 0.5)
                    )

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(inputText.isEmpty || isGenerating ? Color.gray.opacity(0.3) : KomalColors.lavenderPurple)
                }
                .disabled(inputText.isEmpty || isGenerating)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.9))
        }
        .onAppear {
            // Start a memory session for the reflect free-chat
            memoryService.startSession(characterId: Self.reflectCharacterId, characterName: "Reflect")

            // Initial greeting
            let greetings = [
                LanguageManager.shared.localized("reflect.chat.greeting.1"),
                LanguageManager.shared.localized("reflect.chat.greeting.2"),
                LanguageManager.shared.localized("reflect.chat.greeting.3")
            ]
            messages.append(ReflectionChatMessage(
                id: UUID(),
                text: greetings.randomElement() ?? greetings[0],
                isFromUser: false
            ))
        }
        .onDisappear {
            if isRecording { stopSpeechToText() }
            // Save all messages and end the session
            for msg in messages {
                let persisted = PersistedChatMessage(
                    text: msg.text,
                    isFromUser: msg.isFromUser,
                    characterId: Self.reflectCharacterId
                )
                memoryService.saveMessage(persisted)
            }
            memoryService.endCurrentSession(characterId: Self.reflectCharacterId)
        }
        .onReceive(speechRecognizer.$transcript) { newValue in
            if isRecording && !newValue.isEmpty {
                inputText = newValue
            }
        }
    }

    private func toggleSpeechToText() {
        if isRecording {
            stopSpeechToText()
        } else {
            startSpeechToText()
        }
    }

    private func startSpeechToText() {
        Task {
            let hasPermission = await requestMicrophonePermission()
            if hasPermission {
                await MainActor.run {
                    isRecording = true
                    speechRecognizer.startRecording()
                }
            }
        }
    }

    private func stopSpeechToText() {
        speechRecognizer.stopRecording()
        if !speechRecognizer.transcript.isEmpty {
            inputText = speechRecognizer.transcript
        }
        isRecording = false
    }

    private func requestMicrophonePermission() async -> Bool {
        if #available(iOS 17.0, *) {
            let micStatus = AVAudioApplication.shared.recordPermission
            if micStatus == .undetermined {
                return await AVAudioApplication.requestRecordPermission()
            }
            return micStatus == .granted
        } else {
            let session = AVAudioSession.sharedInstance()
            if session.recordPermission == .undetermined {
                var granted = false
                await withCheckedContinuation { continuation in
                    session.requestRecordPermission { isGranted in
                        granted = isGranted
                        continuation.resume()
                    }
                }
                return granted
            }
            return session.recordPermission == .granted
        }
    }

    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        // Two-tier content filter: strict keywords hard-block, softer flags let Gemini redirect
        var redirectHint: String? = nil
        if let flagged = BrowserState.checkForInappropriateContent(inputText, isSearchQuery: true) {
            if BrowserState.isStrictKeyword(flagged) {
                let userMessage = ReflectionChatMessage(id: UUID(), text: inputText, isFromUser: true)
                messages.append(userMessage)
                inputText = ""
                let redirectMessage = ReflectionChatMessage(
                    id: UUID(),
                    text: LanguageManager.shared.localized("chat.content_redirect"),
                    isFromUser: false
                )
                withAnimation { messages.append(redirectMessage) }
                return
            }
            redirectHint = "[SYSTEM NOTE: The child's message may touch on inappropriate content. Redirect naturally. Do not repeat the inappropriate words.]"
        }

        let userMessage = ReflectionChatMessage(id: UUID(), text: inputText, isFromUser: true)
        messages.append(userMessage)
        let messageText = inputText
        inputText = ""
        isGenerating = true

        let ageGroup = appState.activeProfile.ageGroup

        Task {
            do {
                let gemini = GeminiChatService()
                let response = try await gemini.generateFreeChatResponse(
                    userMessage: redirectHint != nil ? "\(messageText)\n\(redirectHint!)" : messageText,
                    conversationHistory: messages,
                    ageGroup: ageGroup
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
                    isGenerating = false
                    let responseMessage = ReflectionChatMessage(id: UUID(), text: displayResponse, isFromUser: false)
                    withAnimation {
                        messages.append(responseMessage)
                    }
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    // Fallback response
                    let fallbackResponses = [
                        LanguageManager.shared.localized("reflect.chat.fallback.1"),
                        LanguageManager.shared.localized("reflect.chat.fallback.2"),
                        LanguageManager.shared.localized("reflect.chat.fallback.3"),
                        LanguageManager.shared.localized("reflect.chat.fallback.4"),
                        LanguageManager.shared.localized("reflect.chat.fallback.5")
                    ]
                    let responseMessage = ReflectionChatMessage(
                        id: UUID(),
                        text: fallbackResponses.randomElement() ?? fallbackResponses[0],
                        isFromUser: false
                    )
                    withAnimation {
                        messages.append(responseMessage)
                    }
                }
            }
        }
    }
}

// Using a distinct name to avoid conflicts with other ChatMessage types in the project
struct ReflectionChatMessage: Identifiable {
    let id: UUID
    let text: String
    let isFromUser: Bool
}

struct FreeChatBubble: View {
    let message: ReflectionChatMessage

    var body: some View {
        HStack {
            if message.isFromUser { Spacer(minLength: 60) }

            Text(message.text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(message.isFromUser ? .white : KomalColors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(message.isFromUser ? KomalColors.lavenderPurple : Color.white)
                )

            if !message.isFromUser { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Completion View

struct CompletionView: View {
    let dismiss: DismissAction

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(KomalColors.pearlAqua.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(KomalColors.pearlAqua)
            }

            VStack(spacing: 8) {
                Text(LanguageManager.shared.localized("reflect.completion.title"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text(LanguageManager.shared.localized("reflect.completion.subtitle"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(KomalColors.textSecondary)
            }

            Text(LanguageManager.shared.localized("reflect.completion.message"))
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(KomalColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()

            Button(action: { dismiss() }) {
                Text(LanguageManager.shared.localized("common.done"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(KomalColors.pearlAqua)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }
}

#if canImport(PreviewsMacros)
#Preview {
    ReflectionTimeView()
        .environmentObject(AppState())
}
#endif
#endif
