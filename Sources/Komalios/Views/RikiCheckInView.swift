#if canImport(SwiftUI)
import SwiftUI

struct RikiCheckInView: View {
    @State private var step = 0
    private let prompts = [
        "Hi there! I'm Riki the Raccoon. Let's take a mindful check-in.",
        "Take a slow breath. Inhale for four, exhale for six.",
        "Name one thing you're excited to learn today.",
        "You're ready! Let's browse with curiosity and care."
    ]

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: 20) {
                Spacer()

                StepIndicator(currentStep: step, totalSteps: prompts.count)

                RikiAvatarView()

                BubblyCard {
                    VStack(spacing: 12) {
                        Text(prompts[step])
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                }
                .padding(.horizontal, 16)

                Button(action: advance) {
                    Text(step == prompts.count - 1 ? "Continue" : "Next")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PillButtonStyle())
                .padding(.horizontal, 24)

                if step == prompts.count - 1 {
                    Text("Riki is here whenever you need a calm reset.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.textSecondary)
                }

                Spacer()
            }
        }
    }

    private func advance() {
        withAnimation(KomalAnimations.spring) {
            if step < prompts.count - 1 {
                step += 1
            }
        }
    }
}

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
