#if canImport(SwiftUI)
import SwiftUI

struct BlockedView: View {
    @Environment(\.dismiss) private var dismiss

    /// Educational framing messages — replaces block screen per spec section 4:
    /// "DO NOT show block screen. INSTEAD: age-appropriate educational framing,
    /// curiosity-satisfying explanation, invite guided exploration."
    private var educationalMessages: [String] {
        [
            LanguageManager.shared.localized("blocked.educational.1"),
            LanguageManager.shared.localized("blocked.educational.2"),
            LanguageManager.shared.localized("blocked.educational.3"),
            LanguageManager.shared.localized("blocked.educational.4")
        ]
    }

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: 20) {
                Spacer()

                AnimatedIcon(
                    systemName: "sparkles",
                    size: 64,
                    color: KomalColors.pearlAqua
                )

                BubblyCard {
                    VStack(spacing: 14) {
                        Text(LanguageManager.shared.localized("blocked.hi_there"))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)

                        Text(educationalMessages.randomElement() ?? educationalMessages[0])
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(KomalColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)

                        Button(action: {
                            dismiss()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.white)

                                Text(LanguageManager.shared.localized("blocked.find_something_else"))
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(KomalColors.pearlAqua)
                            .cornerRadius(16)
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }
}
#endif
