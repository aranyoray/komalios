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
        VStack(spacing: 20) {
            StepHeader(step: step)
            RikiAvatarView()
            Text(prompts[step])
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: advance) {
                Text(step == prompts.count - 1 ? "Continue" : "Next")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            if step == prompts.count - 1 {
                Text("Riki is here whenever you need a calm reset.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private func advance() {
        if step < prompts.count - 1 {
            step += 1
        }
    }
}

struct StepHeader: View {
    let step: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<4) { index in
                Circle()
                    .fill(index <= step ? Color.green : Color.gray.opacity(0.3))
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
        VStack(spacing: 16) {
            RikiAvatarView()
            Text(title)
                .font(.headline)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(buttonTitle, action: action)
                .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct RikiAvatarView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green.opacity(0.15))
                .frame(width: 180, height: 180)
            Circle()
                .fill(Color.green.opacity(0.3))
                .frame(width: 140, height: 140)
            Image(systemName: "pawprint.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.green)
        }
        .overlay(
            Text("Riki")
                .font(.caption)
                .foregroundStyle(.secondary),
            alignment: .bottom
        )
    }
}
#endif
