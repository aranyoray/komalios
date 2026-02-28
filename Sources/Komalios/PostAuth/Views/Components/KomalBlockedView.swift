//
//  KomalBlockedView.swift
//  Komalios
//
//  Created on 18/01/26.
//

#if canImport(SwiftUI)
import SwiftUI

struct KomalBlockedView: View {
    let category: ContentCategory
    let reason: String
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showMessage = false
    
    /// Curiosity-satisfying explanations — per spec: replace block screen with
    /// age-appropriate educational framing and invite guided exploration.
    private var friendlyMessage: String {
        let messages = [
            "That's an interesting area to explore! Let's find a way to learn about it that's just right for you.",
            "Some things are best explored with a guide. How about we discover something cool together?",
            "Your curiosity is awesome! Let me help you find something amazing to check out.",
            "The world is full of incredible things to discover. Want to explore a new topic?"
        ]
        return messages.randomElement() ?? messages[0]
    }
    
    var body: some View {
        ZStack {
            GradientBackground()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Selected avatar with gentle animation
                Group {
                    if let uiImage = UIImage(named: "animal\(appState.activeProfile.selectedAvatarIndex)") {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 60))
                            .foregroundColor(KomalColors.bubblegumPink)
                    }
                }
                    .frame(width: 160, height: 160)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
                    .scaleEffect(showMessage ? 1.0 : 0.95)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showMessage)
                    .accessibilityLabel(LanguageManager.localized("accessibility.komal_character"))
                    .onAppear {
                        withAnimation {
                            showMessage = true
                        }
                    }
                
                BubblyCard {
                    VStack(spacing: 20) {
                        Text(LanguageManager.localized("blocked.hi_there"))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)
                        
                        Text(friendlyMessage)
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(KomalColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .opacity(showMessage ? 1.0 : 0)
                            .animation(.easeIn(duration: 0.5).delay(0.2), value: showMessage)
                        
                        Divider()
                            .padding(.vertical, 8)
                            .opacity(showMessage ? 1.0 : 0)
                            .animation(.easeIn(duration: 0.3).delay(0.4), value: showMessage)
                        
                        Button(action: {
                            dismiss()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 16, weight: .semibold))
                                
                                Text(LanguageManager.localized("blocked.find_something_else"))
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(KomalColors.pearlAqua)
                            .cornerRadius(16)
                        }
                        .opacity(showMessage ? 1.0 : 0)
                        .animation(.easeIn(duration: 0.3).delay(0.6), value: showMessage)
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
    KomalBlockedView(category: .violence, reason: "Content blocked")
}
#endif
#endif
