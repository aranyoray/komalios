//
//  KomalCheckInView.swift
//  Komalios
//
//  Created on 18/01/26.
//

#if canImport(SwiftUI)
import SwiftUI

struct KomalCheckInView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedEmotion: String? = nil
    @State private var showResponse = false
    
    private let emotions = [
        ("😊", "Happy"),
        ("😐", "Okay"),
        ("😔", "Sad"),
        ("😴", "Tired"),
        ("🤔", "Curious"),
        ("😎", "Excited")
    ]
    
    private let responses: [String: String] = [
        "Happy": "That's wonderful! I'm so glad you're having a good time exploring! 🌟",
        "Okay": "That's alright! If you need anything, I'm here to help! 💙",
        "Sad": "I'm sorry you're feeling that way. Would you like to take a break? 🫂",
        "Tired": "It's okay to rest! Maybe we can explore more later? 😴",
        "Curious": "I love your curiosity! What are you wondering about? 🤔",
        "Excited": "That's awesome! I'm excited to explore with you too! 🎉"
    ]
    
    var body: some View {
        ZStack {
            GradientBackground()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Komal Elephant Image
                Image("animal10") // Ellie the Elephant
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
                    .scaleEffect(showResponse ? 1.0 : 1.1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6).repeatForever(autoreverses: true), value: showResponse)
                
                BubblyCard {
                    VStack(spacing: 20) {
                        if !showResponse {
                            // Initial greeting
                            VStack(spacing: 12) {
                                Text("Hi there! 👋")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(KomalColors.textPrimary)
                                
                                Text("I'm Komal, and I'm here surfing the internet with you! How are you feeling right now?")
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
                                if let emotion = selectedEmotion,
                                   let response = responses[emotion] {
                                    Text(response)
                                        .font(.system(size: 18, weight: .medium, design: .rounded))
                                        .foregroundColor(KomalColors.textPrimary)
                                        .multilineTextAlignment(.center)
                                        .lineSpacing(4)
                                }
                                
                                Button(action: {
                                    dismiss()
                                }) {
                                    Text("Thanks, Komal! 😊")
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

#Preview {
    KomalCheckInView()
}
#endif
