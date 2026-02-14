#if os(iOS)
import SwiftUI

struct MindfulBreakView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var timer = 10

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: 20) {
                Spacer()

                Text("Mindful Break")
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

