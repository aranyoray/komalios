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
    @State private var selectedEmotion: String? = nil
    @State private var showResponse = false
    
    private var emotions: [(String, String)] {
        let lang = LanguageManager.shared
        return [
            ("😊", lang.localized("checkin.emotion.happy")),
            ("😐", lang.localized("checkin.emotion.okay")),
            ("😔", lang.localized("checkin.emotion.sad")),
            ("😴", lang.localized("checkin.emotion.tired")),
            ("🤔", lang.localized("checkin.emotion.curious")),
            ("😎", lang.localized("checkin.emotion.excited"))
        ]
    }

    private func responseForEmotion(_ label: String) -> String {
        let lang = LanguageManager.shared
        let happyLabel = lang.localized("checkin.emotion.happy")
        let okayLabel = lang.localized("checkin.emotion.okay")
        let sadLabel = lang.localized("checkin.emotion.sad")
        let tiredLabel = lang.localized("checkin.emotion.tired")
        let curiousLabel = lang.localized("checkin.emotion.curious")
        let excitedLabel = lang.localized("checkin.emotion.excited")
        if label == happyLabel { return lang.localized("checkin.response.happy") }
        if label == okayLabel { return lang.localized("checkin.response.okay") }
        if label == sadLabel { return lang.localized("checkin.response.sad") }
        if label == tiredLabel { return lang.localized("checkin.response.tired") }
        if label == curiousLabel { return lang.localized("checkin.response.curious") }
        if label == excitedLabel { return lang.localized("checkin.response.excited") }
        return lang.localized("checkin.response.happy")
    }
    
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
                    .scaleEffect(showResponse ? 1.0 : 1.1)
                    .animation(
                        showResponse
                            ? .spring(response: 0.3, dampingFraction: 0.6)
                            : .spring(response: 0.3, dampingFraction: 0.6).repeatForever(autoreverses: true),
                        value: showResponse
                    )
                
                BubblyCard {
                    VStack(spacing: 20) {
                        if !showResponse {
                            // Initial greeting
                            VStack(spacing: 12) {
                                Text(LanguageManager.shared.localized("checkin.hi_there"))
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(KomalColors.textPrimary)

                                Text(LanguageManager.shared.localized("checkin.intro_message"))
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(KomalColors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(4)
                            }
                            
                            // Emotion buttons
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(emotions, id: \.1) { emoji, label in
                                    Button(action: {
                                        selectedEmotion = label
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                            showResponse = true
                                        }
                                    }) {
                                        VStack(spacing: 8) {
                                            Text(emoji)
                                                .font(.system(size: 32))
                                            Text(label)
                                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                                .foregroundColor(KomalColors.textSecondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(selectedEmotion == label ? KomalColors.pearlAqua.opacity(0.2) : KomalColors.background)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(selectedEmotion == label ? KomalColors.pearlAqua : Color.clear, lineWidth: 2)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } else {
                            // Response after emotion selected
                            VStack(spacing: 16) {
                                if let emotion = selectedEmotion {
                                    Text(responseForEmotion(emotion))
                                        .font(.system(size: 18, weight: .medium, design: .rounded))
                                        .foregroundColor(KomalColors.textPrimary)
                                        .multilineTextAlignment(.center)
                                        .lineSpacing(4)
                                }
                                
                                Button(action: {
                                    dismiss()
                                }) {
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
