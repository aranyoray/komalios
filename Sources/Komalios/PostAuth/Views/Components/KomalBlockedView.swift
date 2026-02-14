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
    @Environment(\.dismiss) private var dismiss
    @State private var showMessage = false
    
    private var friendlyMessage: String {
        // Generate respectful, child-friendly messages based on category
        let messages = [
            "I'm sorry, but this content isn't available right now. Let's find something else fun to explore together! 🌟",
            "This isn't quite right for us right now. How about we look for something else that's awesome? 💙",
            "Let's skip this one and find something even better! I'm here to help you discover great things! 🎈",
            "This content isn't available at the moment. Want to explore something else together? 😊"
        ]
        return messages.randomElement() ?? messages[0]
    }
    
    var body: some View {
        ZStack {
            GradientBackground()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Komal Elephant with gentle animation
                Image("animal10") // Ellie the Elephant
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
                        Text("Hi there! 👋")
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
                                
                                Text("Let's find something else!")
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
