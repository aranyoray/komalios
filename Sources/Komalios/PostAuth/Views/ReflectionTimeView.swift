#if os(iOS)
import SwiftUI
import AVFoundation
import Speech

// MARK: - Reflection Time Main View

struct ReflectionTimeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var showSELSession = false

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

                if showSELSession {
                    SELDailySessionView {
                        withAnimation { showSELSession = false }
                    }
                } else {
                    FreeChatSessionView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(LanguageManager.localized("reflect.title"))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !showSELSession {
                        Button(action: { withAnimation { showSELSession = true } }) {
                            HStack(spacing: 4) {
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 14))
                                Text(LanguageManager.localized("reflect.daily_checkin"))
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(KomalColors.lavenderPurple)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Free Chat Session (Gemini-powered)

struct FreeChatSessionView: View {
    @EnvironmentObject private var appState: AppState
    @State private var messages: [ReflectionChatMessage] = []
    @State private var inputText = ""
    @State private var isGenerating = false
    @State private var isRecording = false
    @StateObject private var speechRecognizer = SpeechRecognizer()

    /// characterId 0 is reserved for the Reflect free-chat session
    private static let reflectCharacterId = 0
    private let memoryService = ConversationMemoryService.shared
    private let geminiService = GeminiChatService()

    @State private var reflectIconPulse = false

    var body: some View {
        VStack(spacing: 0) {
            // Reflect icon header
            ReflectIconHeader(isPulsing: $reflectIconPulse)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                        reflectIconPulse = true
                    }
                }

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            FreeChatBubble(message: message)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.8, anchor: message.isFromUser ? .trailing : .leading)
                                        .combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }

                        if isGenerating {
                            HStack {
                                HStack(spacing: 5) {
                                    ForEach(0..<3) { index in
                                        ReflectTypingDot(delay: Double(index) * 0.2)
                                    }
                                    Text(LanguageManager.localized("riki.typing"))
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
                            .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                    .id("bottom")
                }
                .onChange(of: messages.count) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
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

                TextField(LanguageManager.localized("reflect.free_chat.placeholder"), text: $inputText)
                    .font(.system(size: 16, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(24)
                    .onChange(of: inputText) {
                        if inputText.count > 2000 { inputText = String(inputText.prefix(2000)) }
                    }
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
            .padding(.bottom, 70)
            .background(Color.white.opacity(0.9))
        }
        .onAppear {
            // Start a memory session for the reflect free-chat
            memoryService.startSession(characterId: Self.reflectCharacterId, characterName: "Reflect")

            // Initial greeting
            let greetings = [
                LanguageManager.localized("reflect.chat.greeting.1"),
                LanguageManager.localized("reflect.chat.greeting.2"),
                LanguageManager.localized("reflect.chat.greeting.3")
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
                inputText = String(newValue.prefix(2000))
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
            let hasPermission = await SpeechRecognizer.requestPermissions()
            if hasPermission {
                // Configure audio session for recording before starting
                SpeechRecognizer.configureVoiceChatSession()
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

    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        // Two-tier content filter: child exploitation → hard block, softer flags → Gemini psychological redirect
        let displayText = BrowserState.censorForDisplay(inputText)
        if let flagged = BrowserState.checkForInappropriateContent(inputText, isSearchQuery: true) {
            if BrowserState.isChildExploitationKeyword(flagged) {
                // Safety-critical hard block — no Gemini call
                let userMessage = ReflectionChatMessage(id: UUID(), text: displayText, isFromUser: true)
                messages.append(userMessage)
                inputText = ""
                let redirectMessage = ReflectionChatMessage(
                    id: UUID(),
                    text: LanguageManager.localized("chat.content_redirect"),
                    isFromUser: false
                )
                withAnimation { messages.append(redirectMessage) }
                return
            }
            // Softer inappropriate content: let Gemini redirect naturally via system prompt
            // (generateFreeChatResponse's system prompt already instructs natural redirection)
        }

        let userMessage = ReflectionChatMessage(id: UUID(), text: displayText, isFromUser: true)
        messages.append(userMessage)
        let messageText = inputText
        inputText = ""
        isGenerating = true

        let ageGroup = appState.activeProfile.ageGroup

        Task {
            do {
                let response = try await geminiService.generateFreeChatResponse(
                    userMessage: messageText,
                    conversationHistory: messages,
                    ageGroup: ageGroup
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
                    isGenerating = false
                    let responseMessage = ReflectionChatMessage(id: UUID(), text: displayResponse, isFromUser: false)
                    withAnimation {
                        messages.append(responseMessage)
                    }
                }
            } catch {
                #if DEBUG
                if let chatError = error as? GeminiChatError {
                    print("ReflectionTimeView: Gemini error — \(chatError.debugDescription)")
                } else {
                    print("ReflectionTimeView: error — \(error.localizedDescription)")
                }
                #endif
                await MainActor.run {
                    isGenerating = false
                    // Fallback response
                    let fallbackResponses = [
                        LanguageManager.localized("reflect.chat.fallback.1"),
                        LanguageManager.localized("reflect.chat.fallback.2"),
                        LanguageManager.localized("reflect.chat.fallback.3"),
                        LanguageManager.localized("reflect.chat.fallback.4"),
                        LanguageManager.localized("reflect.chat.fallback.5")
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

// MARK: - Reflect Icon Header

private struct ReflectIconHeader: View {
    @Binding var isPulsing: Bool

    var body: some View {
        Image(systemName: "brain.head.profile")
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(KomalColors.lavenderPurple)
            .frame(width: 40, height: 40)
            .background(
                Circle()
                    .fill(KomalColors.lavenderPurple.opacity(0.12))
            )
            .opacity(isPulsing ? 1.0 : 0.6)
    }
}

// MARK: - Reflect Typing Dot

private struct ReflectTypingDot: View {
    let delay: Double

    @State private var animating = false

    var body: some View {
        Circle()
            .fill(KomalColors.lavenderPurple.opacity(0.6))
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

#if canImport(PreviewsMacros)
#Preview {
    ReflectionTimeView()
        .environmentObject(AppState())
}
#endif
#endif
