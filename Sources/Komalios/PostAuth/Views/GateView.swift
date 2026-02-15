#if os(iOS)
import SwiftUI

struct GateView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let category: ContentCategory
    @State private var pin = ""
    @State private var showMindfulBreak = false

    var body: some View {
        NavigationStack {
            ZStack {
                GradientBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        RikiAssistantCard(
                            title: "Riki suggests a pause",
                            message: "This page touches on \(category.label). Let's check in before continuing.",
                            buttonTitle: "Start Mindful Break"
                        ) {
                            showMindfulBreak = true
                        }
                        .padding(.horizontal, 16)

                        BubblyCard(tintColor: KomalColors.yellow) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "lock.shield.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(KomalColors.pearlAqua)

                                    Text("Parent approval")
                                        .font(.system(size: 22, weight: .bold, design: .rounded))
                                        .foregroundColor(KomalColors.textPrimary)

                                    Spacer()
                                }

                                SecureField("Enter parent PIN", text: $pin)
                                    .roundedTextFieldStyle()

                                Button {
                                    if pin == KeychainService.getPin() ?? "1234" {
                                        dismiss()
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Approve and Continue")
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(PillButtonStyle(backgroundColor: KomalColors.pearlAqua, foregroundColor: KomalColors.textPrimary))
                            }
                        }
                        .padding(.horizontal, 16)

                        Text("Access is gated for \(appState.currentProfileName) (\(appState.activeProfile.ageGroup.rawValue)).")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(KomalColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Gated content")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showMindfulBreak) {
                MindfulBreakView()
            }
        }
    }
}
#endif
