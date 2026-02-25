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
    
    private var friendlyMessage: String {
        let lang = LanguageManager.shared
        let messages = [
            lang.localized("blocked.friendly_1"),
            lang.localized("blocked.friendly_2"),
            lang.localized("blocked.friendly_3"),
            lang.localized("blocked.friendly_4")
        ]
        return messages.randomElement() ?? messages[0]
    }
    
    var body: some View {
        ZStack {
            GradientBackground()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Selected avatar with gentle animation
                Image("animal\(appState.activeProfile.selectedAvatarIndex)")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
                    .scaleEffect(showMessage ? 1.0 : 0.95)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showMessage)
                    .onAppear {
                        withAnimation {
                            showMessage = true
                        }
                    }
                
                BubblyCard {
                    VStack(spacing: 20) {
                        Text(LanguageManager.shared.localized("blocked.hi_there"))
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
                                
                                Text(LanguageManager.shared.localized("blocked.find_something_else"))
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
