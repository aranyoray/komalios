#if os(iOS)
import SwiftUI

struct LoginOnboardingView: View {
    // Completion closure to notify caller when onboarding is finished
    let onFinished: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Simple background to match potential app style
            LinearGradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "sparkles")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(.tint)

                Text("Welcome")
                    .font(.system(size: 32, weight: .bold, design: .rounded))

                Text("A quick tour to get you started. You can customize this onboarding later.")
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                Button(action: finish) {
                    Text("Get Started")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
            .padding()
        }
    }

    private func finish() {
        onFinished()
        // Attempt to dismiss if presented as a sheet/fullScreenCover
        dismiss()
    }
}

#if canImport(PreviewsMacros)
#Preview {
    LoginOnboardingView { }
}
#endif
#endif
