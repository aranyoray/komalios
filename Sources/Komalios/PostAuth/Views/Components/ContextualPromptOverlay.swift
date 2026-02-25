#if os(iOS)
import SwiftUI

struct ContextualPromptOverlay: View {
    let prompt: ContextualPrompt
    let onAction: (ContextualPromptAction) -> Void
    let onDismiss: () -> Void

    @EnvironmentObject private var appState: AppState
    @State private var isVisible = false

    private var isYoungerChild: Bool {
        appState.activeProfile.ageGroup == .under10
    }

    private var isOlderTeen: Bool {
        appState.activeProfile.ageGroup == .thirteenToSixteen ||
        appState.activeProfile.ageGroup == .sixteenToEighteen
    }

    private var avatarSize: CGFloat {
        isYoungerChild ? 56 : 44
    }

    private var messageFontSize: CGFloat {
        isYoungerChild ? 16 : (isOlderTeen ? 14 : 14)
    }

    private var nameFontSize: CGFloat {
        isYoungerChild ? 14 : 12
    }

    var body: some View {
        VStack {
            Spacer()

            HStack(spacing: 12) {
                // Character avatar
                if let uiImage = UIImage(named: prompt.characterImage) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: avatarSize, height: avatarSize)
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(prompt.characterName)
                        .font(.system(size: nameFontSize, weight: .bold, design: .rounded))
                        .foregroundColor(isOlderTeen ? KomalColors.textSecondary : KomalColors.lavenderPurple)

                    Text(prompt.message)
                        .font(.system(size: messageFontSize, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.textPrimary)
                        .lineLimit(isYoungerChild ? 4 : 3)
                }

                Spacer(minLength: 0)

                // Dismiss
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(KomalColors.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.gray.opacity(0.1)))
                }
            }

            // Action button
            if let actionLabel = prompt.actionLabel, let action = prompt.action {
                Button(action: { onAction(action) }) {
                    Text(actionLabel)
                        .font(.system(size: isYoungerChild ? 16 : 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isYoungerChild ? 12 : 10)
                        .background(isOlderTeen ? KomalColors.textPrimary.opacity(0.85) : KomalColors.lavenderPurple)
                        .cornerRadius(isYoungerChild ? 14 : 10)
                }
                .padding(.top, 4)
            }
        }
        .padding(isYoungerChild ? 20 : 16)
        .background(
            RoundedRectangle(cornerRadius: isYoungerChild ? 24 : 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: -4)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 72) // Above floating menu
        .offset(y: isVisible ? 0 : 200)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isVisible = true
            }
            // Auto-dismiss after 8 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                withAnimation(.spring(response: 0.3)) {
                    isVisible = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            }
        }
    }
}
#endif
