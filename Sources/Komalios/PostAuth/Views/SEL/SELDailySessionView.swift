#if os(iOS)
import SwiftUI

struct SELDailySessionView: View {
    let onComplete: () -> Void

    @State private var phase: Phase = .breathing
    @State private var breathCount = 0
    @State private var breathAnimating = false
    @State private var breathTimer: Timer?
    @State private var breathingCompleted = false

    // Curriculum state
    @State private var session: SELCurriculumSession?
    @State private var stepIdx = 0
    @State private var selectedOption: SELResponseOption? = nil
    @State private var showFeedback = false
    @State private var results: [SELCheckResult] = []
    @State private var showAvatarDialogue = true

    private let breathCycles = 3

    private enum Phase {
        case breathing, session, closing
    }

    private var currentStep: SELCurriculumStep? {
        guard let session = session else { return nil }
        return session.steps.indices.contains(stepIdx) ? session.steps[stepIdx] : nil
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.95, blue: 1.0),
                    Color(red: 0.9, green: 0.95, blue: 0.98)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            switch phase {
            case .breathing:
                breathingView
            case .session:
                sessionView
            case .closing:
                closingView
            }
        }
        .onAppear {
            loadCurriculumSession()
            startBreathing()
        }
        .onDisappear {
            breathTimer?.invalidate()
            breathTimer = nil
        }
    }

    // MARK: - Load Curriculum

    private func loadCurriculumSession() {
        let progress = Self.loadProgress()
        let nextNum = progress.nextSessionNumber
        // Cycle through sessions 1-5
        let sessionNum = ((nextNum - 1) % SELCurriculumLibrary.sessions.count) + 1
        session = SELCurriculumLibrary.session(forNumber: sessionNum)
    }

    // MARK: - Breathing Phase

    private var breathingView: some View {
        VStack(spacing: 0) {
            Spacer()

            Text(LanguageManager.localized("sel.mindfulness_moment"))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(KomalColors.lavenderPurple)
                .tracking(1.5)
                .padding(.bottom, 16)

            Text(LanguageManager.localized("sel.deep_breaths", breathCycles))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)
                .padding(.bottom, 8)

            Text(LanguageManager.localized("sel.breathe_instruction"))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(KomalColors.textSecondary)
                .padding(.bottom, 20)

            ZStack {
                Circle()
                    .fill(KomalColors.lavenderPurple.opacity(0.1))
                    .frame(width: 128, height: 128)
                    .scaleEffect(breathAnimating ? 1.5 : 1.0)
                    .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: breathAnimating)

                Circle()
                    .fill(KomalColors.lavenderPurple.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .scaleEffect(breathAnimating ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: breathAnimating)

                Text("🌿")
                    .font(.system(size: 36))
            }
            .padding(.bottom, 20)
            .accessibilityLabel(LanguageManager.localized("accessibility.sel.breathing_circle"))
            .accessibilityValue(LanguageManager.localized("sel.breath_counter", breathCount + 1, breathCycles))

            Text(LanguageManager.localized("sel.breath_counter", breathCount + 1, breathCycles))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(KomalColors.textSecondary)

            Spacer()

            Button(action: { withAnimation { phase = .session } }) {
                Text(LanguageManager.localized("sel.skip_to_activities"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(KomalColors.textSecondary)
                    .underline()
            }
            .padding(.bottom, 20)
        }
    }

    private func startBreathing() {
        breathAnimating = true
        breathTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { timer in
            Task { @MainActor in
                breathCount += 1
                if breathCount >= breathCycles {
                    timer.invalidate()
                    breathingCompleted = true
                    withAnimation { phase = .session }
                }
            }
        }
    }

    // MARK: - Session Phase (Curriculum-driven)

    private var sessionView: some View {
        VStack(spacing: 0) {
            if let session = session {
                // Session header
                HStack(spacing: 8) {
                    Text(session.emoji)
                        .font(.system(size: 20))
                    Text(session.theme)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(KomalColors.textPrimary)
                    Spacer()
                    Text("\(stepIdx + 1)/\(session.steps.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(KomalColors.lavenderPurple)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(KomalColors.lavenderPurple)
                            .frame(width: geo.size.width * CGFloat(stepIdx + 1) / CGFloat(max(1, session.steps.count)), height: 6)
                            .animation(.easeInOut(duration: 0.3), value: stepIdx)
                    }
                }
                .frame(height: 6)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }

            if let step = currentStep {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Goals tags
                        if !step.targetGoals.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(step.targetDomains, id: \.self) { domain in
                                        Text(domain.emoji)
                                            .font(.system(size: 10))
                                    }
                                    ForEach(step.targetGoals, id: \.self) { goal in
                                        Text(goal)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(KomalColors.lavenderPurple)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(KomalColors.lavenderPurple.opacity(0.1))
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // Avatar dialogue bubble
                        if showAvatarDialogue {
                            HStack(alignment: .top, spacing: 10) {
                                Text("🧑‍🎤")
                                    .font(.system(size: 28))

                                Text(step.avatarDialogue)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(KomalColors.textPrimary)
                                    .lineSpacing(3)
                                    .padding(14)
                                    .background(Color.white)
                                    .cornerRadius(16)
                                    .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
                            }
                            .padding(.horizontal, 16)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Participation prompt (the question)
                        Text(step.participationPrompt)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)
                            .lineSpacing(2)
                            .padding(.horizontal, 16)

                        // Response options from curriculum
                        VStack(spacing: 10) {
                            ForEach(step.responseOptions) { option in
                                Button(action: { handleOptionSelect(option, step: step) }) {
                                    HStack(spacing: 12) {
                                        Text(option.emoji)
                                            .font(.system(size: 24))

                                        Text(option.text)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(KomalColors.textPrimary)
                                            .multilineTextAlignment(.leading)

                                        Spacer()
                                    }
                                    .padding(14)
                                    .background(
                                        selectedOption?.id == option.id
                                            ? KomalColors.lavenderPurple.opacity(0.1)
                                            : showFeedback ? Color.gray.opacity(0.05) : Color.white
                                    )
                                    .cornerRadius(14)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(
                                                selectedOption?.id == option.id
                                                    ? KomalColors.lavenderPurple
                                                    : Color.gray.opacity(0.15),
                                                lineWidth: selectedOption?.id == option.id ? 2 : 1
                                            )
                                    )
                                    .opacity(showFeedback && selectedOption?.id != option.id ? 0.5 : 1.0)
                                }
                                .buttonStyle(.plain)
                                .disabled(showFeedback)
                            }
                        }
                        .padding(.horizontal, 16)

                        // Feedback
                        if showFeedback, let selected = selectedOption {
                            HStack {
                                Spacer()
                                Text(feedbackText(for: selected.qualityScore))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(KomalColors.pearlAqua)
                                Spacer()
                            }
                            .padding(12)
                            .background(KomalColors.pearlAqua.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            .transition(.opacity)
                        }

                        Spacer().frame(height: 20)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    private func handleOptionSelect(_ option: SELResponseOption, step: SELCurriculumStep) {
        guard !showFeedback else { return }

        selectedOption = option
        showFeedback = true

        // Map curriculum step to SELCheckResult for scoring
        let primaryDomain = step.targetDomains.first ?? .socialCommunication
        let result = SELCheckResult(
            checkId: step.id,
            domain: primaryDomain,
            competency: step.targetGoals.first ?? "",
            score: option.qualityScore
        )
        results.append(result)

        // Also record results for secondary domains
        for domain in step.targetDomains.dropFirst() {
            results.append(SELCheckResult(
                checkId: "\(step.id)-\(domain.rawValue)",
                domain: domain,
                competency: step.targetGoals.first ?? "",
                score: option.qualityScore
            ))
        }

        // Auto-advance after 1.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showFeedback = false
                selectedOption = nil
                showAvatarDialogue = true

                if let session = session, stepIdx < session.steps.count - 1 {
                    stepIdx += 1
                } else {
                    phase = .closing
                }
            }
        }
    }

    private func feedbackText(for score: Int) -> String {
        switch score {
        case 3: return LanguageManager.localized("sel.feedback.great") + " 🌟"
        case 2: return LanguageManager.localized("sel.feedback.good") + " 👍"
        default: return LanguageManager.localized("sel.feedback.okay") + " 😊"
        }
    }

    // MARK: - Closing Phase

    private var closingView: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("🌟")
                .font(.system(size: 64))
                .padding(.bottom, 24)
                .accessibilityLabel(LanguageManager.localized("accessibility.sel.completion_star"))

            Text(LanguageManager.localized("sel.wonderful_job"))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)
                .padding(.bottom, 8)

            if let session = session {
                Text(session.theme)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(KomalColors.lavenderPurple)
                    .padding(.bottom, 4)
            }

            Text(LanguageManager.localized("sel.closing_message"))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(KomalColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

            Text(LanguageManager.localized("sel.activities_completed", results.count))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(KomalColors.lavenderPurple)
                .padding(.bottom, 32)

            Button(action: handleFinish) {
                Text(LanguageManager.localized("common.done"))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: 280)
                    .padding(.vertical, 14)
                    .background(KomalColors.lavenderPurple)
                    .cornerRadius(28)
            }

            Spacer()
        }
    }

    private func handleFinish() {
        _ = SELAssessmentService.shared.saveSessionRecord(results: results, mindfulnessDone: breathingCompleted)
        GrowthTrackingService.shared.recordActivity(type: .reflection)

        // Update curriculum progress
        if let session = session {
            var progress = Self.loadProgress()
            progress.completedSessionIds.append(session.id)
            progress.currentSessionId = nil
            progress.currentStepIndex = 0
            Self.saveProgress(progress)
        }

        onComplete()
    }

    // MARK: - Progress Persistence

    private static let progressURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return docs.appendingPathComponent("sel_curriculum_progress.json")
    }()

    private static func loadProgress() -> SELCurriculumProgress {
        guard let data = try? Data(contentsOf: progressURL) else { return SELCurriculumProgress() }
        return (try? JSONDecoder().decode(SELCurriculumProgress.self, from: data)) ?? SELCurriculumProgress()
    }

    private static func saveProgress(_ progress: SELCurriculumProgress) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        try? data.write(to: progressURL, options: [.atomic, .completeFileProtection])
    }
}
#endif
