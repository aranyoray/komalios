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
    
    private var isYoungerChild: Bool {
        appState.activeProfile.ageGroup == .under10 || appState.activeProfile.ageGroup == .tenToThirteen
    }
    
    enum SessionType {
        case welcome
        case sel // Social-Emotional Learning (under 13)
        case mindfulness // For all ages
        case reflection // Guided reflection questions
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
                    case .mindfulness:
                        mindfulnessView
                    case .reflection:
                        reflectionView
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
                    Text("Reflection Time")
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
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        timerActive = true
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
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
                    Text("Welcome to Reflection Time")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(KomalColors.textPrimary)
                    
                    Text("15 minutes of mindful digital wellness")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(KomalColors.textSecondary)
                }
                
                // Session options
                VStack(spacing: 12) {
                    if isYoungerChild {
                        SessionOptionCard(
                            icon: "heart.circle.fill",
                            title: "Feelings Check-In",
                            description: "Explore and understand your emotions",
                            color: KomalColors.bubblegumPink
                        ) {
                            withAnimation { currentSession = .sel }
                        }
                    }
                    
                    SessionOptionCard(
                        icon: "sparkles",
                        title: "Mindfulness Exercise",
                        description: "Calm breathing and relaxation",
                        color: KomalColors.pearlAqua
                    ) {
                        withAnimation { currentSession = .mindfulness }
                    }
                    
                    SessionOptionCard(
                        icon: "text.bubble.fill",
                        title: "Guided Reflection",
                        description: "Think about your digital experiences",
                        color: KomalColors.lavenderPurple
                    ) {
                        withAnimation { currentSession = .reflection }
                    }
                    
                    SessionOptionCard(
                        icon: "bubble.left.and.bubble.right.fill",
                        title: "Free Chat",
                        description: "Talk about anything on your mind",
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
        SELSessionView(onBack: { withAnimation { currentSession = .welcome } })
    }
    
    // MARK: - Mindfulness View
    
    private var mindfulnessView: some View {
        MindfulnessSessionView(onBack: { withAnimation { currentSession = .welcome } })
    }
    
    // MARK: - Reflection View
    
    private var reflectionView: some View {
        ReflectionSessionView(onBack: { withAnimation { currentSession = .welcome } })
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
                
                Text("remaining")
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
    @State private var emotionIntensity: Double = 5
    
    private let emotions = [
        ("😊", "Happy", KomalColors.pearlAqua),
        ("😢", "Sad", Color.blue),
        ("😠", "Angry", Color.red),
        ("😰", "Worried", Color.orange),
        ("😴", "Tired", Color.gray),
        ("🤩", "Excited", KomalColors.bubblegumPink),
        ("😐", "Okay", Color.gray),
        ("🤔", "Confused", KomalColors.lavenderPurple)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
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
                        Text("How Are You Feeling?")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)
                        
                        Text("It's okay to feel any emotion. Let's explore together.")
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
                                withAnimation { selectedEmotion = emotion.1 }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    if selectedEmotion != nil {
                        // Intensity slider
                        VStack(spacing: 12) {
                            Text("How strong is this feeling?")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(KomalColors.textPrimary)
                            
                            HStack {
                                Text("A little")
                                    .font(.system(size: 12))
                                    .foregroundColor(KomalColors.textSecondary)
                                
                                Slider(value: $emotionIntensity, in: 1...10, step: 1)
                                    .tint(KomalColors.lavenderPurple)
                                
                                Text("A lot")
                                    .font(.system(size: 12))
                                    .foregroundColor(KomalColors.textSecondary)
                            }
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                        
                        // Coping strategies
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Things that might help:")
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
    
    private func getCopingStrategies() -> [String] {
        switch selectedEmotion {
        case "Sad":
            return ["Talk to someone you trust", "Draw or write about your feelings", "Listen to your favorite music", "Give yourself a hug"]
        case "Angry":
            return ["Take 5 deep breaths", "Count backwards from 10", "Squeeze a stress ball", "Go for a short walk"]
        case "Worried":
            return ["Tell an adult how you feel", "Think of 3 things you're grateful for", "Imagine your happy place", "Take slow, deep breaths"]
        case "Tired":
            return ["Rest your eyes for a minute", "Drink some water", "Stretch your body", "Take a break from screens"]
        default:
            return ["Share your feelings with someone", "Do something you enjoy", "Take a mindful moment", "Be kind to yourself"]
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
        case inhale = "Breathe In"
        case hold = "Hold"
        case exhale = "Breathe Out"
    }
    
    private let exercises = [
        MindfulnessExercise(
            title: "Box Breathing",
            description: "A calming technique used by athletes and astronauts",
            icon: "square",
            steps: ["Breathe in for 4 seconds", "Hold for 4 seconds", "Breathe out for 4 seconds", "Hold for 4 seconds", "Repeat 4 times"]
        ),
        MindfulnessExercise(
            title: "5-4-3-2-1 Grounding",
            description: "Connect with the present moment",
            icon: "hand.raised.fill",
            steps: ["Notice 5 things you can SEE", "Notice 4 things you can TOUCH", "Notice 3 things you can HEAR", "Notice 2 things you can SMELL", "Notice 1 thing you can TASTE"]
        ),
        MindfulnessExercise(
            title: "Body Scan",
            description: "Relax your body from head to toe",
            icon: "figure.stand",
            steps: ["Relax your forehead and eyes", "Relax your jaw and shoulders", "Relax your arms and hands", "Relax your stomach", "Relax your legs and feet"]
        ),
        MindfulnessExercise(
            title: "Gratitude Moment",
            description: "Focus on the good things in life",
            icon: "heart.fill",
            steps: ["Think of someone who makes you happy", "Think of something you're good at", "Think of a place that makes you feel safe", "Think of a happy memory", "Smile and feel grateful"]
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
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
                        Text("Mindfulness")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)
                        
                        Text("Take a moment to calm your mind")
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

// MARK: - Reflection Session

struct ReflectionSessionView: View {
    let onBack: () -> Void
    @State private var currentQuestion = 0
    @State private var response = ""
    @State private var responses: [String] = []
    
    private let questions = [
        ReflectionQuestion(question: "What was the best thing you saw online today?", prompt: "Share something that made you smile or feel good..."),
        ReflectionQuestion(question: "Did anything online make you feel uncomfortable?", prompt: "It's okay to talk about things that bothered you..."),
        ReflectionQuestion(question: "What did you learn today from the internet?", prompt: "Share something interesting you discovered..."),
        ReflectionQuestion(question: "How much time did you spend on screens today?", prompt: "Was it too much, just right, or not enough?"),
        ReflectionQuestion(question: "What would you like to do offline tomorrow?", prompt: "Think of fun activities away from screens...")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
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
                    
                    // Question
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
                    
                    // Navigation
                    HStack(spacing: 12) {
                        if currentQuestion > 0 {
                            Button(action: {
                                withAnimation {
                                    currentQuestion -= 1
                                    response = responses.count > currentQuestion ? responses[currentQuestion] : ""
                                }
                            }) {
                                Text("Previous")
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
                            withAnimation {
                                if responses.count > currentQuestion {
                                    responses[currentQuestion] = response
                                } else {
                                    responses.append(response)
                                }
                                
                                if currentQuestion < questions.count - 1 {
                                    currentQuestion += 1
                                    response = responses.count > currentQuestion ? responses[currentQuestion] : ""
                                }
                            }
                        }) {
                            Text(currentQuestion == questions.count - 1 ? "Done" : "Next")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(KomalColors.lavenderPurple)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer().frame(height: 40)
                }
            }
        }
    }
}

struct ReflectionQuestion {
    let question: String
    let prompt: String
}

// MARK: - Free Chat Session

struct FreeChatSessionView: View {
    let onBack: () -> Void
    @State private var messages: [ReflectionChatMessage] = []
    @State private var inputText = ""
    
    private let prompts = [
        "What's on your mind today?",
        "Tell me about something interesting that happened",
        "Is there anything bothering you?",
        "What made you happy recently?",
        "What would you like to talk about?"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
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
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    .id("bottom")
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            
            // Input
            HStack(spacing: 12) {
                TextField("Type your thoughts...", text: $inputText)
                    .font(.system(size: 16, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(24)
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(inputText.isEmpty ? Color.gray.opacity(0.3) : KomalColors.lavenderPurple)
                }
                .disabled(inputText.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.9))
        }
        .onAppear {
            // Initial greeting
            messages.append(ReflectionChatMessage(
                id: UUID(),
                text: "Hi! This is a safe space to share your thoughts. \(prompts.randomElement() ?? "")",
                isFromUser: false
            ))
        }
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let userMessage = ReflectionChatMessage(id: UUID(), text: inputText, isFromUser: true)
        messages.append(userMessage)
        inputText = ""
        
        // Supportive response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let responses = [
                "Thank you for sharing that with me. How does that make you feel?",
                "I hear you. That sounds really important to you.",
                "It's great that you're talking about this. Tell me more?",
                "I understand. It's okay to feel that way.",
                "Thanks for trusting me with that. What else is on your mind?"
            ]
            let responseMessage = ReflectionChatMessage(id: UUID(), text: responses.randomElement() ?? "I'm listening.", isFromUser: false)
            withAnimation {
                messages.append(responseMessage)
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
                Text("Great Job!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                
                Text("You completed your Reflection Time")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(KomalColors.textSecondary)
            }
            
            Text("Taking time to reflect helps you understand yourself better and stay healthy online.")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(KomalColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Text("Done")
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

