#if canImport(SwiftUI)
import SwiftUI

struct BlockedView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: 20) {
                Spacer()

                AnimatedIcon(
                    systemName: "shield.slash",
                    size: 64,
                    color: KomalColors.pearlAqua
                )

                BubblyCard {
                    VStack(spacing: 14) {
                        Text(LanguageManager.shared.localized("blocked.title"))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)

                        Divider()
                            .padding(.vertical, 8)

                        Button(action: {
                            dismiss()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "hand.raised.fill")
                                    .foregroundColor(KomalColors.softPink)

                                Text(LanguageManager.shared.localized("blocked.ask_parent"))
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(KomalColors.textPrimary)
                            }
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
