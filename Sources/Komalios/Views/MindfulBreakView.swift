#if canImport(SwiftUI)
import SwiftUI

struct MindfulBreakView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var timer = 10

    var body: some View {
        VStack(spacing: 24) {
            Text("Mindful Break")
                .font(.title2)
                .bold()
            RikiAvatarView()
            Text("Take a gentle pause. Notice your breath and the room around you.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Text("\(timer)s")
                .font(.largeTitle)
                .bold()

            Button("I'm ready") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
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
