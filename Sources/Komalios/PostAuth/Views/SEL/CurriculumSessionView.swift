#if os(iOS)
import SwiftUI
import AVFoundation

/// Voice-first guided SEL session view using curriculum data.
/// Owns its own minimal voice loop (STT -> Gemini -> TTS -> listen).
struct CurriculumSessionView: View {
    let character: RikiCharacter

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // MARK: - Session State

    @State private var session: SELCurriculumSession?
    @State private var progress: SELCurriculumProgress = SELCurriculumProgress()
    @State private var currentStepIndex: Int = 0
    @State private var stepResults: [(stepId: String, score: Int, domains: [SELDomain], competency: String)] = []

    // MARK: - Voice Loop State

    @StateObject private var speechRecognizer = SpeechRecognizer()
    @StateObject private var audioPlayback = AudioPlaybackManager()
    @State private var isListening = false
    @State private var childResponse: String = ""
    @State private var isProcessing = false
    @State private var silenceTimer: Timer?
    @State private var promptTimer: Timer?
    @State private var silenceSeconds: Int = 0

    // MARK: - UI State

    @State private var messages: [(text: String, isFromUser: Bool)] = []
    @State private var showCompletion = false
    @State private var micDenied = false

    @ObservedObject private var networkMonitor = NetworkMonitorService.shared

    private let geminiService = GeminiChatService()

    // MARK: - Offline TTS

    private let offlineSynthesizer = AVSpeechSynthesizer()

    // MARK: - Computed

    private var currentStep: SELCurriculumStep? {
        guard let session, currentStepIndex < session.steps.count else { return nil }
        return session.steps[currentStepIndex]
    }

    private var totalSteps: Int {
        session?.steps.count ?? 0
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            GradientBackground()

            if showCompletion {
                completionView
            } else {
                sessionContentView
            }
        }
        .onAppear {
            loadSession()
            // 0.3s delay for audio session handoff
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                SpeechRecognizer.configureVoiceChatSession()
                deliverCurrentStep()
            }
        }
        .onDisappear {
            cleanup()
        }
        .onChange(of: speechRecognizer.transcript) { _, newValue in
            guard isListening, !newValue.isEmpty else { return }
            // Stop-phrase detection
            let stopPhrases = ["shut up", "stop talking", "be quiet", "leave me alone",
                               "go away", "i don't want to talk", "stop it", "just stop"]
            if stopPhrases.contains(where: { newValue.lowercased().contains($0) }) {
                stopListening()
                audioPlayback.stop()
                dismiss()
                return
            }
            childResponse = newValue
            resetSilenceTimer()
        }
    }

    // MARK: - Session Content

    private var sessionContentView: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(KomalColors.textSecondary.opacity(0.6))
                }
                Spacer()
                if let session {
                    Text(LanguageManager.localized("curriculum.step_of", currentStepIndex + 1, session.steps.count))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.textSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Progress bar
            if totalSteps > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(KomalColors.lavenderPurple.opacity(0.15))
                            .frame(height: 6)
                        Capsule()
                            .fill(KomalColors.lavenderPurple)
                            .frame(width: geo.size.width * CGFloat(currentStepIndex) / CGFloat(totalSteps), height: 6)
                    }
                }
                .frame(height: 6)
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

            Spacer().frame(height: 16)

            // Avatar
            Image(character.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            audioPlayback.isPlaying ? KomalColors.pearlAqua : (isListening ? KomalColors.bubblegumPink : Color.clear),
                            lineWidth: 3
                        )
                )
                .shadow(color: audioPlayback.isPlaying ? KomalColors.pearlAqua.opacity(0.4) : .clear, radius: 12)

            Text(character.name)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)
                .padding(.top, 4)

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                            messageBubble(text: message.text, isFromUser: message.isFromUser)
                                .id(index)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 280)
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.indices.last {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }

            // Listening indicator
            if isListening {
                HStack(spacing: 8) {
                    Circle()
                        .fill(KomalColors.bubblegumPink)
                        .frame(width: 8, height: 8)
                    Text(LanguageManager.localized("riki.listening"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.bubblegumPink)
                }
                .padding(.top, 4)
                .transition(.opacity)
            }

            if isProcessing {
                ProgressView()
                    .padding(.top, 8)
            }

            Spacer()

            // Mic denied banner
            if micDenied {
                Text(LanguageManager.localized("curriculum.mic_needed"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(KomalColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 4)
            }

            // Next button
            Button(action: { advanceStep(score: childResponse.isEmpty ? 1 : scoreCurrentStep()) }) {
                HStack {
                    Text(LanguageManager.localized("curriculum.next"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Image(systemName: "arrow.right")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(Capsule().fill(KomalColors.lavenderPurple))
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Completion View

    private var completionView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(character.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(Circle())

            Text(LanguageManager.localized("curriculum.complete.title"))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)

            Text(LanguageManager.localized("curriculum.complete.message"))
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(KomalColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Button(action: { dismiss() }) {
                Text(LanguageManager.localized("common.done"))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(KomalColors.lavenderPurple))
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - Message Bubble

    private func messageBubble(text: String, isFromUser: Bool) -> some View {
        HStack {
            if isFromUser { Spacer() }
            Text(text)
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(isFromUser ? .white : KomalColors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isFromUser ? KomalColors.lavenderPurple : KomalColors.lavenderPurple.opacity(0.12))
                )
            if !isFromUser { Spacer() }
        }
    }

    // MARK: - Session Loading

    private func loadSession() {
        progress = Self.loadProgress()
        let sessionNumber = progress.nextSessionNumber
        guard let loaded = SELCurriculumLibrary.session(forNumber: min(sessionNumber, 5)) else { return }
        session = loaded

        // Resume from persisted step if mid-session
        if progress.currentSessionId == loaded.id {
            currentStepIndex = progress.currentStepIndex
        } else {
            currentStepIndex = 0
            progress.currentSessionId = loaded.id
            progress.currentStepIndex = 0
            Self.saveProgress(progress)
        }
    }

    // MARK: - Step Delivery

    private func deliverCurrentStep() {
        guard let step = currentStep else {
            finishSession()
            return
        }

        let dialogue = step.avatarDialogue
        messages.append((text: dialogue, isFromUser: false))

        // TTS the scripted dialogue
        if networkMonitor.isConnected {
            Task {
                await audioPlayback.speak(text: dialogue, characterName: character.name)
                // Wait for TTS to finish before prompting
                await waitForTTSComplete()
                deliverPrompt(step: step)
            }
        } else {
            // Offline: use AVSpeechSynthesizer
            speakOffline(text: dialogue) {
                deliverPrompt(step: step)
            }
        }
    }

    private func deliverPrompt(step: SELCurriculumStep) {
        let prompt = step.participationPrompt
        messages.append((text: prompt, isFromUser: false))

        // 3s breathing room before opening mic
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            startListening()
        }
    }

    // MARK: - Voice Loop

    private func startListening() {
        guard speechRecognizer.isAuthorized else {
            micDenied = true
            return
        }
        micDenied = false
        childResponse = ""
        isListening = true
        speechRecognizer.startRecording()
        startSilenceMonitor()
    }

    private func stopListening() {
        isListening = false
        speechRecognizer.stopRecording()
        silenceTimer?.invalidate()
        silenceTimer = nil
        promptTimer?.invalidate()
        promptTimer = nil
        silenceSeconds = 0
    }

    private func startSilenceMonitor() {
        silenceSeconds = 0
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                silenceSeconds += 1

                if silenceSeconds == 10 && childResponse.isEmpty {
                    // Tier 1: gentle prompt
                    let promptText = LanguageManager.localized("curriculum.silence_prompt")
                    messages.append((text: promptText, isFromUser: false))
                    if networkMonitor.isConnected {
                        Task { await audioPlayback.speak(text: promptText, characterName: character.name) }
                    } else {
                        speakOffline(text: promptText, completion: nil)
                    }
                }

                if silenceSeconds >= 20 {
                    // Tier 2: auto-advance with score=1
                    stopListening()
                    advanceStep(score: 1)
                }
            }
        }
    }

    private func resetSilenceTimer() {
        silenceSeconds = 0
        // After child stops talking for 2s, process their response
        promptTimer?.invalidate()
        promptTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            Task { @MainActor in
                guard !childResponse.isEmpty else { return }
                stopListening()
                processChildResponse()
            }
        }
    }

    // MARK: - Gemini Processing

    private func processChildResponse() {
        guard let step = currentStep, let session else { return }

        let response = childResponse
        messages.append((text: response, isFromUser: true))

        // Score the step
        let score = scoreCurrentStep()

        isProcessing = true

        if networkMonitor.isConnected {
            Task {
                let context = CurriculumPromptBuilder.build(
                    characterName: character.name,
                    characterPersonality: character.personality,
                    session: session,
                    step: step,
                    ageGroup: appState.activeProfile.ageGroup
                )

                let sanitized = BrowserState.censorForDisplay(response)

                do {
                    let geminiResponse = try await geminiService.sendMessage(
                        userMessage: sanitized,
                        conversationHistory: [],
                        characterName: character.name,
                        characterPersonality: character.personality,
                        conversationContext: context,
                        ageGroup: appState.activeProfile.ageGroup
                    )

                    isProcessing = false
                    messages.append((text: geminiResponse, isFromUser: false))
                    await audioPlayback.speak(text: geminiResponse, characterName: character.name)
                    await waitForTTSComplete()
                    advanceStep(score: score)
                } catch {
                    isProcessing = false
                    // Fallback encouragement on timeout/error
                    let fallback = LanguageManager.localized("curriculum.fallback_encouragement")
                    messages.append((text: fallback, isFromUser: false))
                    await audioPlayback.speak(text: fallback, characterName: character.name)
                    await waitForTTSComplete()
                    advanceStep(score: score)
                }
            }
        } else {
            // Offline: skip Gemini, auto-advance
            isProcessing = false
            let fallback = LanguageManager.localized("curriculum.fallback_encouragement")
            messages.append((text: fallback, isFromUser: false))
            speakOffline(text: fallback) {
                advanceStep(score: score)
            }
        }
    }

    // MARK: - Scoring

    func scoreCurrentStep() -> Int {
        guard let step = currentStep else { return 1 }
        let response = childResponse.lowercased()
        if response.isEmpty { return 1 }

        // Check for keyword match
        for keyword in step.expectedKeywords {
            if response.contains(keyword.lowercased()) {
                return 3
            }
        }
        return 2
    }

    // MARK: - Step Advancement

    private func advanceStep(score: Int) {
        guard let step = currentStep else { return }

        stepResults.append((
            stepId: step.id,
            score: score,
            domains: step.targetDomains,
            competency: step.targetGoals.first ?? "Participation"
        ))

        currentStepIndex += 1
        progress.currentStepIndex = currentStepIndex
        Self.saveProgress(progress)

        childResponse = ""

        if currentStepIndex < totalSteps {
            // Small delay before next step
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                deliverCurrentStep()
            }
        } else {
            finishSession()
        }
    }

    // MARK: - Session Completion

    private func finishSession() {
        guard let session else { return }

        // Save voice session record
        Task {
            await SELAssessmentService.shared.saveVoiceSessionRecord(stepResults: stepResults)
        }

        // Update progress
        if !progress.completedSessionIds.contains(session.id) {
            progress.completedSessionIds.append(session.id)
        }
        progress.currentSessionId = nil
        progress.currentStepIndex = 0
        Self.saveProgress(progress)

        withAnimation {
            showCompletion = true
        }
    }

    // MARK: - Cleanup

    private func cleanup() {
        silenceTimer?.invalidate()
        promptTimer?.invalidate()
        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
        }
        audioPlayback.stop()
    }

    // MARK: - TTS Helpers

    private func waitForTTSComplete() async {
        // Poll until audioPlayback finishes
        while audioPlayback.isPlaying {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
    }

    private func speakOffline(text: String, completion: (() -> Void)?) {
        let locale = LanguageManager.speechRecognitionLocale
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: locale)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.1
        offlineSynthesizer.speak(utterance)
        // Rough timing estimate: ~80ms per character
        let estimatedDuration = Double(text.count) * 0.08
        DispatchQueue.main.asyncAfter(deadline: .now() + estimatedDuration) {
            completion?()
        }
    }

    // MARK: - Progress Persistence

    private static let progressURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return docs.appendingPathComponent("sel_curriculum_progress.json")
    }()

    static func loadProgress() -> SELCurriculumProgress {
        guard let data = try? Data(contentsOf: progressURL) else { return SELCurriculumProgress() }
        return (try? JSONDecoder().decode(SELCurriculumProgress.self, from: data)) ?? SELCurriculumProgress()
    }

    static func saveProgress(_ progress: SELCurriculumProgress) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        try? data.write(to: progressURL, options: [.atomic, .completeFileProtection])
    }
}
#endif
