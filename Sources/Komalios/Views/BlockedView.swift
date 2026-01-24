#if canImport(SwiftUI)
import SwiftUI
#if canImport(Speech) && canImport(AVFoundation)
import AVFoundation
import Speech
#endif

struct BlockedView: View {
    let category: ContentCategory
    let reason: String
#if canImport(Speech) && canImport(AVFoundation)
    @StateObject private var speechService = SpeechService.shared
#endif

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
                        Text("This content is blocked")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)

                        Text("Komal blocked this page because it includes \(category.label.lowercased()) content.")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(KomalColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)

                        Text(reason)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(KomalColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Divider()
                            .padding(.vertical, 8)

                        HStack(spacing: 8) {
                            Image(systemName: "hand.raised.fill")
                                .foregroundColor(KomalColors.softPink)

                            Text("Ask a parent if you need access.")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(KomalColors.textPrimary)
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .onAppear {
#if canImport(Speech) && canImport(AVFoundation)
            speechService.speak("This content is blocked because it includes \(category.label) content. \(reason)")
#endif
        }
    }
}
#endif
