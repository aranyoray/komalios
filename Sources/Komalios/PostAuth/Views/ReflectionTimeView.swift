#if os(iOS)
import SwiftUI

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
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer.invalidate()
                showCompletion = true
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
                        title: "Daily Check-In",
                        description: "Scenario-based SEL assessment across 5 domains",
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
        Double(totalTime - timeRemaining) / Double(totalTime)
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

// MARK: - SEL Session (Social-Emotional Learning)

struct SELSessionView: View {
    let onBack: () -> Void
    @State private var currentStep = 0
    @State private var selectedEmotion: String? = nil
    @State private var selectedEmoji: String = ""
    @State private var emotionIntensity: Double = 5
    @State private var hasSavedMood = false

    private var emotions: [(String, String, Color)] {
        [
            ("😊", LanguageManager.shared.localized("reflect.emotion.happy"), KomalColors.pearlAqua),
            ("😢", LanguageManager.shared.localized("reflect.emotion.sad"), Color.blue),
            ("😠", LanguageManager.shared.localized("reflect.emotion.angry"), Color.red),
            ("😰", LanguageManager.shared.localized("reflect.emotion.worried"), Color.orange),
            ("😴", LanguageManager.shared.localized("reflect.emotion.tired"), Color.gray),
            ("🤩", LanguageManager.shared.localized("reflect.emotion.excited"), KomalColors.bubblegumPink),
            ("😐", LanguageManager.shared.localized("reflect.emotion.okay"), Color.gray),
            ("🤔", LanguageManager.shared.localized("reflect.emotion.confused"), KomalColors.lavenderPurple)
        ]
    }

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

            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 8) {
                        Text(LanguageManager.shared.localized("reflect.sel.title"))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)

                        Text(LanguageManager.shared.localized("reflect.sel.subtitle"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(KomalColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    // Emotion picker
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(emotions, id: \.1) { emotion in
                            EmotionButton(
                                emoji: emotion.0,
                                label: emotion.1,
                                color: emotion.2,
                                isSelected: selectedEmotion == emotion.1
                            ) {
                                withAnimation {
                                    selectedEmotion = emotion.1
                                    selectedEmoji = emotion.0
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    if selectedEmotion != nil {
                        // Intensity slider
                        VStack(spacing: 12) {
                            Text(LanguageManager.shared.localized("reflect.sel.intensity"))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(KomalColors.textPrimary)

                            HStack {
                                Text(LanguageManager.shared.localized("reflect.sel.a_little"))
                                    .font(.system(size: 12))
                                    .foregroundColor(KomalColors.textSecondary)

                                Slider(value: $emotionIntensity, in: 1...10, step: 1)
                                    .tint(KomalColors.lavenderPurple)
                                    .onChange(of: emotionIntensity) {
                                        saveMoodIfNeeded()
                                    }

                                Text(LanguageManager.shared.localized("reflect.sel.a_lot"))
                                    .font(.system(size: 12))
                                    .foregroundColor(KomalColors.textSecondary)
                            }
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)

                        // Mood history mini view
                        MoodHistoryMiniView()
                            .padding(.horizontal, 20)

                        // Coping strategies
                        VStack(alignment: .leading, spacing: 16) {
                            Text(LanguageManager.shared.localized("reflect.sel.things_help"))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(KomalColors.textPrimary)

                            ForEach(getCopingStrategies(), id: \.self) { strategy in
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(KomalColors.pearlAqua)
                                    Text(strategy)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(KomalColors.textPrimary)
                                }
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                    }

                    Spacer().frame(height: 40)
                }
            }
        }
    }

    private func saveMoodIfNeeded() {
        guard let emotion = selectedEmotion, !hasSavedMood else { return }
        hasSavedMood = true
        let entry = MoodEntry(
            emotion: emotion,
            emoji: selectedEmoji,
            intensity: Int(emotionIntensity),
            context: .selSession
        )
        MoodTrackingService.shared.logMood(entry)
        GrowthTrackingService.shared.recordActivity(type: .moodCheckIn)
        GrowthTrackingService.shared.recordActivity(type: .reflection)
    }

    private func getCopingStrategies() -> [String] {
        switch selectedEmotion {
        case LanguageManager.shared.localized("reflect.emotion.sad"):
            return [
                LanguageManager.shared.localized("reflect.coping.sad.1"),
                LanguageManager.shared.localized("reflect.coping.sad.2"),
                LanguageManager.shared.localized("reflect.coping.sad.3"),
                LanguageManager.shared.localized("reflect.coping.sad.4")
            ]
        case LanguageManager.shared.localized("reflect.emotion.angry"):
            return [
                LanguageManager.shared.localized("reflect.coping.angry.1"),
                LanguageManager.shared.localized("reflect.coping.angry.2"),
                LanguageManager.shared.localized("reflect.coping.angry.3"),
                LanguageManager.shared.localized("reflect.coping.angry.4")
            ]
        case LanguageManager.shared.localized("reflect.emotion.worried"):
            return [
                LanguageManager.shared.localized("reflect.coping.worried.1"),
                LanguageManager.shared.localized("reflect.coping.worried.2"),
                LanguageManager.shared.localized("reflect.coping.worried.3"),
                LanguageManager.shared.localized("reflect.coping.worried.4")
            ]
        case LanguageManager.shared.localized("reflect.emotion.tired"):
            return [
                LanguageManager.shared.localized("reflect.coping.tired.1"),
                LanguageManager.shared.localized("reflect.coping.tired.2"),
                LanguageManager.shared.localized("reflect.coping.tired.3"),
                LanguageManager.shared.localized("reflect.coping.tired.4")
            ]
        default:
            return [
                LanguageManager.shared.localized("reflect.coping.default.1"),
                LanguageManager.shared.localized("reflect.coping.default.2"),
                LanguageManager.shared.localized("reflect.coping.default.3"),
                LanguageManager.shared.localized("reflect.coping.default.4")
            ]
        }
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

// MARK: - Mindfulness Session

struct MindfulnessSessionView: View {
    let onBack: () -> Void
    @State private var currentExercise = 0
    @State private var breathPhase: BreathPhase = .inhale
    @State private var breathCount = 0
    @State private var isBreathing = false

    enum BreathPhase: String {
        case inhale = "inhale"
        case hold = "hold"
        case exhale = "exhale"

        var localizedName: String {
            switch self {
            case .inhale: return LanguageManager.shared.localized("reflect.breathe.inhale")
            case .hold: return LanguageManager.shared.localized("reflect.breathe.hold")
            case .exhale: return LanguageManager.shared.localized("reflect.breathe.exhale")
            }
        }
    }

    private var exercises: [MindfulnessExercise] {
        [
            MindfulnessExercise(
                title: LanguageManager.shared.localized("reflect.exercise.box.title"),
                description: LanguageManager.shared.localized("reflect.exercise.box.desc"),
                icon: "square",
                steps: [
                    LanguageManager.shared.localized("reflect.exercise.box.step1"),
                    LanguageManager.shared.localized("reflect.exercise.box.step2"),
                    LanguageManager.shared.localized("reflect.exercise.box.step3"),
                    LanguageManager.shared.localized("reflect.exercise.box.step4"),
                    LanguageManager.shared.localized("reflect.exercise.box.step5")
                ]
            ),
            MindfulnessExercise(
                title: LanguageManager.shared.localized("reflect.exercise.grounding.title"),
                description: LanguageManager.shared.localized("reflect.exercise.grounding.desc"),
                icon: "hand.raised.fill",
                steps: [
                    LanguageManager.shared.localized("reflect.exercise.grounding.step1"),
                    LanguageManager.shared.localized("reflect.exercise.grounding.step2"),
                    LanguageManager.shared.localized("reflect.exercise.grounding.step3"),
                    LanguageManager.shared.localized("reflect.exercise.grounding.step4"),
                    LanguageManager.shared.localized("reflect.exercise.grounding.step5")
                ]
            ),
            MindfulnessExercise(
                title: LanguageManager.shared.localized("reflect.exercise.bodyscan.title"),
                description: LanguageManager.shared.localized("reflect.exercise.bodyscan.desc"),
                icon: "figure.stand",
                steps: [
                    LanguageManager.shared.localized("reflect.exercise.bodyscan.step1"),
                    LanguageManager.shared.localized("reflect.exercise.bodyscan.step2"),
                    LanguageManager.shared.localized("reflect.exercise.bodyscan.step3"),
                    LanguageManager.shared.localized("reflect.exercise.bodyscan.step4"),
                    LanguageManager.shared.localized("reflect.exercise.bodyscan.step5")
                ]
            ),
            MindfulnessExercise(
                title: LanguageManager.shared.localized("reflect.exercise.gratitude.title"),
                description: LanguageManager.shared.localized("reflect.exercise.gratitude.desc"),
                icon: "heart.fill",
                steps: [
                    LanguageManager.shared.localized("reflect.exercise.gratitude.step1"),
                    LanguageManager.shared.localized("reflect.exercise.gratitude.step2"),
                    LanguageManager.shared.localized("reflect.exercise.gratitude.step3"),
                    LanguageManager.shared.localized("reflect.exercise.gratitude.step4"),
                    LanguageManager.shared.localized("reflect.exercise.gratitude.step5")
                ]
            )
        ]
    }

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

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text(LanguageManager.shared.localized("reflect.mindfulness.header"))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)

                        Text(LanguageManager.shared.localized("reflect.mindfulness.calm_mind"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(KomalColors.textSecondary)
                    }
                    .padding(.top, 20)

                    // Exercise cards
                    ForEach(Array(exercises.enumerated()), id: \.1.title) { index, exercise in
                        ExerciseCard(
                            exercise: exercise,
                            isExpanded: currentExercise == index
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                currentExercise = currentExercise == index ? -1 : index
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 40)
                }
            }
        }
    }
}

struct MindfulnessExercise: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let steps: [String]
}

struct ExerciseCard: View {
    let exercise: MindfulnessExercise
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 14) {
                    Image(systemName: exercise.icon)
                        .font(.system(size: 24))
                        .foregroundColor(KomalColors.pearlAqua)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.title)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)

                        Text(exercise.description)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(KomalColors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(KomalColors.textSecondary)
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(exercise.steps.enumerated()), id: \.0) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                                .background(KomalColors.pearlAqua)
                                .clipShape(Circle())

                            Text(step)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(KomalColors.textPrimary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
    }
}

// MARK: - Reflection Session (with AI follow-ups)

struct ReflectionSessionView: View {
    let onBack: () -> Void
    @EnvironmentObject private var appState: AppState
    @State private var currentQuestion = 0
    @State private var response = ""
    @State private var responses: [String] = []
    @State private var followUpQuestion: String? = nil
    @State private var followUpResponse = ""
    @State private var followUpDepth = 0
    @State private var isGeneratingFollowUp = false
    @State private var reflectionDepthScore: Double = 0

    private let maxFollowUpDepth = 2

    private var questions: [ReflectionQuestion] {
        [
            ReflectionQuestion(question: LanguageManager.shared.localized("reflect.q1.question"), prompt: LanguageManager.shared.localized("reflect.q1.prompt")),
            ReflectionQuestion(question: LanguageManager.shared.localized("reflect.q2.question"), prompt: LanguageManager.shared.localized("reflect.q2.prompt")),
            ReflectionQuestion(question: LanguageManager.shared.localized("reflect.q3.question"), prompt: LanguageManager.shared.localized("reflect.q3.prompt")),
            ReflectionQuestion(question: LanguageManager.shared.localized("reflect.q4.question"), prompt: LanguageManager.shared.localized("reflect.q4.prompt")),
            ReflectionQuestion(question: LanguageManager.shared.localized("reflect.q5.question"), prompt: LanguageManager.shared.localized("reflect.q5.prompt"))
        ]
    }

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

                Text("\(currentQuestion + 1)/\(questions.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(KomalColors.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            ScrollView {
                VStack(spacing: 24) {
                    // Progress dots
                    HStack(spacing: 8) {
                        ForEach(0..<questions.count, id: \.self) { index in
                            Circle()
                                .fill(index <= currentQuestion ? KomalColors.lavenderPurple : Color.gray.opacity(0.2))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.top, 20)

                    if let followUp = followUpQuestion {
                        // AI Follow-up question
                        VStack(spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14))
                                    .foregroundColor(KomalColors.lavenderPurple)
                                Text(LanguageManager.shared.localized("reflect.going_deeper"))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(KomalColors.lavenderPurple)
                            }

                            Text(followUp)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(KomalColors.textPrimary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 20)

                        // Follow-up response area
                        TextEditor(text: $followUpResponse)
                            .font(.system(size: 16, weight: .medium))
                            .frame(minHeight: 120)
                            .padding(16)
                            .background(Color.white)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                            )
                            .padding(.horizontal, 20)

                        // Follow-up navigation
                        HStack(spacing: 12) {
                            Button(action: {
                                withAnimation {
                                    followUpQuestion = nil
                                    followUpResponse = ""
                                }
                            }) {
                                Text(LanguageManager.shared.localized("common.skip"))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(KomalColors.lavenderPurple)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(KomalColors.lavenderPurple, lineWidth: 1)
                                    )
                            }

                            Button(action: {
                                withAnimation {
                                    if !followUpResponse.trimmingCharacters(in: .whitespaces).isEmpty {
                                        reflectionDepthScore += 1.0
                                    }
                                    followUpQuestion = nil
                                    followUpResponse = ""
                                    followUpDepth = 0
                                    advanceToNextQuestion()
                                }
                            }) {
                                Text(LanguageManager.shared.localized("common.continue"))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(KomalColors.lavenderPurple)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 20)
                    } else {
                        // Main question
                        VStack(spacing: 12) {
                            Text(questions[currentQuestion].question)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(KomalColors.textPrimary)
                                .multilineTextAlignment(.center)

                            Text(questions[currentQuestion].prompt)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(KomalColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 20)

                        // Response area
                        TextEditor(text: $response)
                            .font(.system(size: 16, weight: .medium))
                            .frame(minHeight: 150)
                            .padding(16)
                            .background(Color.white)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                            )
                            .padding(.horizontal, 20)

                        // Loading indicator for follow-up generation
                        if isGeneratingFollowUp {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text(LanguageManager.shared.localized("reflect.thinking_followup"))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(KomalColors.textSecondary)
                            }
                        }

                        // Navigation
                        HStack(spacing: 12) {
                            if currentQuestion > 0 {
                                Button(action: {
                                    withAnimation {
                                        currentQuestion -= 1
                                        response = responses.count > currentQuestion ? responses[currentQuestion] : ""
                                    }
                                }) {
                                    Text(LanguageManager.shared.localized("reflect.previous"))
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(KomalColors.lavenderPurple)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.white)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(KomalColors.lavenderPurple, lineWidth: 1)
                                        )
                                }
                            }

                            Button(action: {
                                submitResponse()
                            }) {
                                Text(currentQuestion == questions.count - 1 ? LanguageManager.shared.localized("common.done") : LanguageManager.shared.localized("reflect.next"))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(KomalColors.lavenderPurple)
                                    .cornerRadius(12)
                            }
                            .disabled(isGeneratingFollowUp)
                        }
                        .padding(.horizontal, 20)
                    }

                    Spacer().frame(height: 40)
                }
            }
        }
    }

    private func submitResponse() {
        // Block inappropriate content in journal input
        if BrowserState.checkForInappropriateContent(response, isSearchQuery: true) != nil {
            response = ""
            followUpQuestion = LanguageManager.shared.localized("chat.content_redirect")
            return
        }

        // Save response
        if responses.count > currentQuestion {
            responses[currentQuestion] = response
        } else {
            responses.append(response)
        }

        reflectionDepthScore += 1.0

        // Try to generate a follow-up if response is substantive and we haven't reached max depth
        let trimmedResponse = response.trimmingCharacters(in: .whitespaces)
        if trimmedResponse.count > 20 && followUpDepth < maxFollowUpDepth {
            generateFollowUp(
                question: questions[currentQuestion].question,
                response: trimmedResponse
            )
        } else {
            advanceToNextQuestion()
        }
    }

    private func generateFollowUp(question: String, response: String) {
        isGeneratingFollowUp = true
        let ageGroup = appState.activeProfile.ageGroup

        Task {
            do {
                let gemini = GeminiChatService()
                let followUp = try await gemini.generateReflectionFollowUp(
                    question: question,
                    response: response,
                    ageGroup: ageGroup
                )
                await MainActor.run {
                    isGeneratingFollowUp = false
                    followUpQuestion = followUp
                    followUpDepth += 1
                }
            } catch {
                await MainActor.run {
                    isGeneratingFollowUp = false
                    // If AI fails, just advance
                    advanceToNextQuestion()
                }
            }
        }
    }

    private func advanceToNextQuestion() {
        if currentQuestion < questions.count - 1 {
            currentQuestion += 1
            response = responses.count > currentQuestion ? responses[currentQuestion] : ""
        }
    }
}

struct ReflectionQuestion {
    let question: String
    let prompt: String
}

// MARK: - Free Chat Session (Gemini-powered)

struct FreeChatSessionView: View {
    let onBack: () -> Void
    @EnvironmentObject private var appState: AppState
    @State private var messages: [ReflectionChatMessage] = []
    @State private var inputText = ""
    @State private var isGenerating = false

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

            // Input
            HStack(spacing: 12) {
                TextField(LanguageManager.shared.localized("reflect.free_chat.placeholder"), text: $inputText)
                    .font(.system(size: 16, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(24)

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
    }

    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        // Block inappropriate content in chat input
        if BrowserState.checkForInappropriateContent(inputText, isSearchQuery: true) != nil {
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
                    userMessage: messageText,
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
                .padding(.horizontal, 40)

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
            .padding(.bottom, 40)
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
