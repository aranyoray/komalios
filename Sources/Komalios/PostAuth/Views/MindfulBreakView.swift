#if os(iOS)
import SwiftUI

struct MindfulBreakView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var timeRemaining = 10
    @State private var countdownTimer: Timer?

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: 20) {
                Spacer()

                Text(LanguageManager.localized("mindful.title"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)

                ZStack {
                    Circle()
                        .fill(KomalColors.pearlAqua.opacity(0.25))
                        .frame(width: 160, height: 160)
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .foregroundStyle(KomalColors.bubblegumPink)
                        .opacity(0.9)
                }

                BubblyCard(tintColor: KomalColors.yellow) {
                    VStack(spacing: 14) {
                        Text(LanguageManager.localized("mindful.pause_message"))
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(KomalColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)

                        ZStack {
                            Circle()
                                .fill(KomalColors.pearlAqua.opacity(0.3))
                                .frame(width: 100, height: 100)

                            Text("\(timeRemaining)s")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundColor(KomalColors.bubblegumPink)
                        }
                    }
                }
                .padding(.horizontal, 20)

                Button(LanguageManager.localized("mindful.im_ready")) {
                    dismiss()
                }
                .buttonStyle(PillButtonStyle())
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .onAppear(perform: startTimer)
        .onDisappear {
            countdownTimer?.invalidate()
            countdownTimer = nil
        }
    }

    private func startTimer() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            Task { @MainActor in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    timer.invalidate()
                }
            }
        }
    }
}
#endif

