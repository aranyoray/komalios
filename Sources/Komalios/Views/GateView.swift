#if canImport(SwiftUI)
import SwiftUI
#if canImport(Speech) && canImport(AVFoundation)
import AVFoundation
import Speech
#endif

struct GateView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let category: ContentCategory
    @State private var pin = ""
    @State private var showMindfulBreak = false
#if canImport(Speech) && canImport(AVFoundation)
    @StateObject private var speechService = SpeechService.shared
#endif

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

                                HStack(spacing: 8) {
                                    SecureField("Enter parent PIN", text: $pin)
                                        .roundedTextFieldStyle()

#if canImport(Speech) && canImport(AVFoundation)
                                    Button {
                                        speechService.toggleListening()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                            if speechService.isListening {
                                                speechService.stopListening()
                                            }
                                            let digits = speechService.transcript.filter(\.isNumber)
                                            if !digits.isEmpty {
                                                pin = digits
                                            }
                                        }
                                    } label: {
                                        Image(systemName: speechService.isListening ? "waveform" : "mic.fill")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 44, height: 44)
                                            .background(Circle().fill(KomalColors.lavenderPurple))
                                    }
#endif
                                }

                                Button {
                                    if pin == appState.parentSettings.parentPin {
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
            .onAppear {
#if canImport(Speech) && canImport(AVFoundation)
                speechService.speak("This page touches on \(category.label). Let's pause and check in together.")
#endif
            }
        }
    }
}
#endif
