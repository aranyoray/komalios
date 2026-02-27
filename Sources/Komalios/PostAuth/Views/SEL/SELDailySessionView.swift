#if os(iOS)
import SwiftUI

struct SELDailySessionView: View {
    let onComplete: () -> Void

    @State private var phase: Phase = .breathing
    @State private var breathCount = 0
    @State private var breathAnimating = false
    @State private var breathTimer: Timer?
    @State private var scenarios: [SELScenario] = []
    @State private var scenarioIdx = 0
    @State private var checkIdx = 0
    @State private var results: [SELCheckResult] = []
    @State private var selectedOption: SELOption? = nil
    @State private var showFeedback = false
    @State private var breathingCompleted = false

    private let breathCycles = 3

    private enum Phase {
        case breathing, scenarios, closing
    }

    private var currentScenario: SELScenario? {
        scenarios.indices.contains(scenarioIdx) ? scenarios[scenarioIdx] : nil
    }

    private var currentCheck: SELCheck? {
        guard let scenario = currentScenario else { return nil }
        return scenario.checks.indices.contains(checkIdx) ? scenario.checks[checkIdx] : nil
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
            case .scenarios:
                scenarioView
            case .closing:
                closingView
            }
        }
        .onAppear {
            scenarios = SELAssessmentService.shared.getDailyScenarios()
            startBreathing()
        }
        .onDisappear {
            breathTimer?.invalidate()
            breathTimer = nil
        }
    }

    // MARK: - Breathing Phase

    private var breathingView: some View {
        VStack(spacing: 0) {
            Spacer()

            Text(LanguageManager.shared.localized("sel.mindfulness_moment"))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(KomalColors.lavenderPurple)
                .tracking(1.5)
                .padding(.bottom, 16)

            Text(LanguageManager.shared.localized("sel.deep_breaths", breathCycles))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)
                .padding(.bottom, 8)

            Text(LanguageManager.shared.localized("sel.breathe_instruction"))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(KomalColors.textSecondary)
                .padding(.bottom, 20)

            // Breathing circle
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
            .accessibilityLabel(LanguageManager.shared.localized("accessibility.sel.breathing_circle"))
            .accessibilityValue(LanguageManager.shared.localized("sel.breath_counter", breathCount + 1, breathCycles))

            Text(LanguageManager.shared.localized("sel.breath_counter", breathCount + 1, breathCycles))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(KomalColors.textSecondary)

            Spacer()

            Button(action: { withAnimation { phase = .scenarios } }) {
                Text(LanguageManager.shared.localized("sel.skip_to_activities"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(KomalColors.textSecondary)
                    .underline()
            }
            .padding(.bottom, 20)
        }
    }

    private func startBreathing() {
        breathAnimating = true
        // Each breath cycle is ~8 seconds (4s in + 4s out)
        breathTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { timer in
            Task { @MainActor in
                breathCount += 1
                if breathCount >= breathCycles {
                    timer.invalidate()
                    breathingCompleted = true
                    withAnimation { phase = .scenarios }
                }
            }
        }
    }

    // MARK: - Scenario Phase

    private var scenarioView: some View {
        VStack(spacing: 0) {
            // Progress bar
            HStack(spacing: 4) {
                ForEach(Array(scenarios.enumerated()), id: \.element.id) { i, s in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                i < scenarioIdx ? KomalColors.lavenderPurple :
                                i == scenarioIdx ? KomalColors.lavenderPurple.opacity(0.5) :
                                Color.gray.opacity(0.2)
                            )
                            .frame(height: 6)

                        Text(s.domain.emoji)
                            .font(.system(size: 10))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if let scenario = currentScenario, let check = currentCheck {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Domain label
                        Text(LanguageManager.shared.localized("sel.domain_check", scenario.domain.label.uppercased(), checkIdx + 1))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(KomalColors.lavenderPurple)
                            .tracking(0.5)
                            .padding(.horizontal, 16)

                        // Scenario card (only on first check)
                        if checkIdx == 0 {
                            HStack(alignment: .top, spacing: 12) {
                                Text(scenario.emoji)
                                    .font(.system(size: 32))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(scenario.title)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(KomalColors.textPrimary)

                                    Text(scenario.narrative)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(KomalColors.textSecondary)
                                        .lineSpacing(2)
                                }
                            }
                            .padding(16)
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
                            .padding(.horizontal, 16)
                        }

                        // Question
                        Text(check.question)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)
                            .lineSpacing(2)
                            .padding(.horizontal, 16)

                        // Options
                        VStack(spacing: 10) {
                            ForEach(Array(check.options.enumerated()), id: \.offset) { _, option in
                                Button(action: { handleOptionSelect(option) }) {
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
                                        selectedOption == option
                                            ? KomalColors.lavenderPurple.opacity(0.1)
                                            : showFeedback ? Color.gray.opacity(0.05) : Color.white
                                    )
                                    .cornerRadius(14)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(
                                                selectedOption == option
                                                    ? KomalColors.lavenderPurple
                                                    : Color.gray.opacity(0.15),
                                                lineWidth: selectedOption == option ? 2 : 1
                                            )
                                    )
                                    .opacity(showFeedback && selectedOption != option ? 0.5 : 1.0)
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
                                Text(feedbackText(for: selected.score))
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

    private func handleOptionSelect(_ option: SELOption) {
        guard !showFeedback, let scenario = currentScenario, let check = currentCheck else { return }

        selectedOption = option
        showFeedback = true

        let result = SELCheckResult(
            checkId: check.id,
            domain: scenario.domain,
            competency: check.competency,
            score: option.score
        )
        results.append(result)

        // Auto-advance after 1.2s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation {
                showFeedback = false
                selectedOption = nil

                if checkIdx < 2 {
                    checkIdx += 1
                } else if scenarioIdx < scenarios.count - 1 {
                    scenarioIdx += 1
                    checkIdx = 0
                } else {
                    phase = .closing
                }
            }
        }
    }

    private func feedbackText(for score: Int) -> String {
        switch score {
        case 3: return LanguageManager.shared.localized("sel.feedback.great") + " 🌟"
        case 2: return LanguageManager.shared.localized("sel.feedback.good") + " 👍"
        default: return LanguageManager.shared.localized("sel.feedback.okay") + " 😊"
        }
    }

    // MARK: - Closing Phase

    private var closingView: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("🌟")
                .font(.system(size: 64))
                .padding(.bottom, 24)
                .accessibilityLabel(LanguageManager.shared.localized("accessibility.sel.completion_star"))

            Text(LanguageManager.shared.localized("sel.wonderful_job"))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)
                .padding(.bottom, 8)

            Text(LanguageManager.shared.localized("sel.closing_message"))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(KomalColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

            Text(LanguageManager.shared.localized("sel.activities_completed", results.count))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(KomalColors.lavenderPurple)
                .padding(.bottom, 32)

            Button(action: handleFinish) {
                Text(LanguageManager.shared.localized("common.done"))
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
        onComplete()
    }
}
#endif
