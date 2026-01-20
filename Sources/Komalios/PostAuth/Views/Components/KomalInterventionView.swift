//
//  KomalInterventionView.swift
//  Komalios
//
//  Digital Guardian - Caring intervention when child searches for sensitive content
//

import SwiftUI

struct KomalInterventionView: View {
    let trigger: KomalInterventionTrigger
    let onReflectionTime: () -> Void
    let onGoBack: () -> Void
    let onContinueAnyway: (() -> Void)?
    
    @State private var selectedAnimal = Int.random(in: 1...11)
    @State private var showingReflection = false
    @State private var reflectionAnswer = ""
    
    // Animation states - appear one by one
    @State private var showMascot = false
    @State private var showMessage = false
    @State private var showTip = false
    @State private var showButtons = false
    @State private var mascotScale: CGFloat = 0.3
    
    private var isSevereContent: Bool {
        let severe = ["porn", "xxx", "sex", "nude", "naked", "gore", "suicide", "self harm", "drug", "cocaine", "heroin"]
        return severe.contains { trigger.searchTerm.lowercased().contains($0) }
    }
    
    // Soft pastel violet colors
    private let softViolet = Color(red: 0.69, green: 0.62, blue: 0.85)
    private let lightViolet = Color(red: 0.85, green: 0.80, blue: 0.95)
    private let paleViolet = Color(red: 0.95, green: 0.93, blue: 0.98)
    
    var body: some View {
        ZStack {
            // Blurred background - shows browser behind
            Color.black.opacity(0.3)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    // Optionally dismiss on background tap
                }
            
            // Main card
            VStack(spacing: 16) {
                // Komal mascot - circle cropped
                if showMascot {
                    mascotSection
                        .transition(.scale.combined(with: .opacity))
                }
                
                // Caring message
                if showMessage {
                    messageSection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Tip
                if showTip {
                    tipSection
                        .transition(.opacity)
                }
                
                // Reflection section (if showing)
                if showingReflection {
                    reflectionSection
                        .transition(.scale.combined(with: .opacity))
                }
                
                // Action buttons
                if showButtons {
                    actionButtons
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.white)
                    .shadow(color: softViolet.opacity(0.3), radius: 30, x: 0, y: 15)
            )
            .padding(.horizontal, 24)
        }
        .onAppear {
            startAnimationSequence()
        }
    }
    
    // MARK: - Animation Sequence
    private func startAnimationSequence() {
        // Gentle, welcoming animation sequence
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
            showMascot = true
            mascotScale = 1.0
        }
        
        withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
            showMessage = true
        }
        
        withAnimation(.easeOut(duration: 0.3).delay(0.7)) {
            showTip = true
        }
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.9)) {
            showButtons = true
        }
    }
    
    // MARK: - Mascot Section (Circle Cropped)
    private var mascotSection: some View {
        VStack(spacing: 8) {
            // Circle cropped mascot
            ZStack {
                // Soft glow
                Circle()
                    .fill(lightViolet.opacity(0.5))
                    .frame(width: 100, height: 100)
                    .blur(radius: 10)
                
                // Mascot image - circle cropped
                Image("animal\(selectedAnimal)")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(softViolet.opacity(0.3), lineWidth: 3)
                    )
                    .shadow(color: softViolet.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            .scaleEffect(mascotScale)
            
            // Name with heart
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 12))
                    .foregroundColor(softViolet)
                Text("Komal")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.4))
            }
        }
    }
    
    // MARK: - Message Section (Compact)
    private var messageSection: some View {
        VStack(spacing: 8) {
            Text(mainMessage)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.35))
                .multilineTextAlignment(.center)
            
            Text(subMessage)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - Tip Section
    private var tipSection: some View {
        HStack(spacing: 6) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 12))
                .foregroundColor(.orange)
            Text("It's okay to be curious - that's how we learn!")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.45))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.orange.opacity(0.08))
        )
    }
    
    // MARK: - Reflection Section
    private var reflectionSection: some View {
        VStack(spacing: 12) {
            Text("Let's think about it...")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.4))
            
            Text(reflectionPrompt)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
                .multilineTextAlignment(.center)
            
            TextField("Share your thoughts...", text: $reflectionAnswer, axis: .vertical)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(paleViolet)
                )
                .lineLimit(2...4)
            
            if !reflectionAnswer.isEmpty {
                Button(action: onReflectionTime) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                        Text("Done reflecting")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(softViolet))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(paleViolet.opacity(0.5))
        )
    }
    
    // MARK: - Action Buttons (Soft Violet)
    private var actionButtons: some View {
        VStack(spacing: 10) {
            // Primary: Let's Talk - Soft Violet Pastel
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showingReflection = true
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 15))
                    Text("Let's Talk About It")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [softViolet, Color(red: 0.75, green: 0.68, blue: 0.90)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: softViolet.opacity(0.35), radius: 8, x: 0, y: 4)
            }
            .opacity(showingReflection ? 0.6 : 1.0)
            .disabled(showingReflection)
            
            // Secondary: Go back
            Button(action: onGoBack) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 13))
                    Text("Go Back to Safety")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .stroke(Color(red: 0.85, green: 0.85, blue: 0.88), lineWidth: 1.5)
                )
            }
        }
    }
    
    // MARK: - Dynamic Text (More Concise)
    private var mainMessage: String {
        switch trigger {
        case .searchQuery:
            return "Hey, I noticed you searched for something..."
        case .urlKeyword:
            return "Hold on a moment!"
        case .imageContent:
            return "I found something we should talk about"
        case .pageContent:
            return "This page has some grown-up content"
        }
    }
    
    private var subMessage: String {
        switch trigger {
        case .searchQuery:
            return "Curiosity is totally normal! But some topics are better to explore with a trusted grown-up."
        case .urlKeyword:
            return "This website might have content meant for adults. Would you like to talk about what you're looking for?"
        case .imageContent:
            return "I spotted something that might not be appropriate. Let's chat about it."
        case .pageContent:
            return "Some of what's here is for older people. Want to talk, or find something else?"
        }
    }
    
    private var reflectionPrompt: String {
        switch trigger {
        case .searchQuery:
            return "What made you curious about this?"
        case .urlKeyword:
            return "What were you hoping to find?"
        case .imageContent:
            return "How did seeing that make you feel?"
        case .pageContent:
            return "Is there something you had questions about?"
        }
    }
}

#if DEBUG
struct KomalInterventionView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            // Simulated browser background
            Color.blue.opacity(0.3)
            
            KomalInterventionView(
                trigger: .searchQuery("something"),
                onReflectionTime: {},
                onGoBack: {},
                onContinueAnyway: {}
            )
        }
    }
}
#endif
