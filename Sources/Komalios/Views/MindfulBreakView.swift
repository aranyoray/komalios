#if canImport(SwiftUI)
import SwiftUI
#if canImport(Speech) && canImport(AVFoundation)
import AVFoundation
import Speech
#endif

struct MindfulBreakView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var timer = 10
#if canImport(Speech) && canImport(AVFoundation)
    @StateObject private var speechService = SpeechService.shared
#endif

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: 20) {
                Spacer()

                Text("Mindful Break")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)

                RikiAvatarView(size: 160)

                BubblyCard(tintColor: KomalColors.yellow) {
                    VStack(spacing: 14) {
                        Text("Take a gentle pause. Notice your breath and the room around you.")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(KomalColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)

                        ZStack {
                            Circle()
                                .fill(KomalColors.pearlAqua.opacity(0.3))
                                .frame(width: 100, height: 100)

                            Text("\(timer)s")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundColor(KomalColors.bubblegumPink)
                        }
                    }
                }
                .padding(.horizontal, 20)

                Button("I'm ready") {
                    dismiss()
                }
                .buttonStyle(PillButtonStyle())
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .onAppear(perform: startTimer)
        .onAppear {
#if canImport(Speech) && canImport(AVFoundation)
            speechService.speak("Take a gentle pause. Notice your breath and the room around you.")
#endif
        }
    }

    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if self.timer > 0 {
                self.timer -= 1
            } else {
                timer.invalidate()
            }
        }
    }
}
#endif
