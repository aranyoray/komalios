//
//  KomalCheckInView.swift
//  Komalios
//
//  Created on 18/01/26.
//

#if canImport(SwiftUI)
import SwiftUI

struct KomalCheckInView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var userInput: String = ""
    @State private var showResponse = false
    @State private var responseText: String = ""

    /// Seamless conversational prompts — no emoji markers, no sliders, no multi-click friction
    private let conversationalPrompts = [
        "What's been on your mind today?",
        "Tell me about something that happened today.",
        "What's something you noticed today?",
        "What are you curious about right now?"
    ]

    private var selectedPrompt: String {
        conversationalPrompts.randomElement() ?? conversationalPrompts[0]
    }

    private let warmResponses = [
        "That's really cool to share. Thanks for telling me!",
        "I hear you. It's good to talk about these things.",
        "Thanks for opening up! That takes courage.",
        "I'm glad you told me that. You're doing great."
    ]

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: 24) {
                Spacer()

                // Selected avatar image
                Image("animal\(appState.activeProfile.selectedAvatarIndex)")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)

                BubblyCard {
                    VStack(spacing: 20) {
                        if !showResponse {
                            // Seamless conversational prompt — no emoji grid, no sliders
                            VStack(spacing: 12) {
                                Text(LanguageManager.shared.localized("checkin.hi_there"))
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(KomalColors.textPrimary)

                                Text(selectedPrompt)
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(KomalColors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(4)
                            }

                            TextField("Type here...", text: $userInput)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .padding(14)
                                .background(KomalColors.background)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                )

                            Button(action: {
                                responseText = warmResponses.randomElement() ?? warmResponses[0]
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    showResponse = true
                                }
                            }) {
                                Text(LanguageManager.shared.localized("common.next"))
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(userInput.isEmpty ? KomalColors.pearlAqua.opacity(0.5) : KomalColors.pearlAqua)
                                    .cornerRadius(16)
                            }
                            .disabled(userInput.isEmpty)
                        } else {
                            // Warm response — no friction, single tap to continue
                            VStack(spacing: 16) {
                                Text(responseText)
                                    .font(.system(size: 18, weight: .medium, design: .rounded))
                                    .foregroundColor(KomalColors.textPrimary)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(4)

                                Button(action: { dismiss() }) {
                                    Text(LanguageManager.shared.localized("checkin.thanks_komal"))
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(KomalColors.pearlAqua)
                                        .cornerRadius(16)
                                }
                            }
                        }
                    }
                    .padding(24)
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }
}

#if canImport(PreviewsMacros)
#Preview {
    KomalCheckInView()
}
#endif
#endif
