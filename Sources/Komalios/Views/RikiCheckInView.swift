#if canImport(SwiftUI)
import SwiftUI
#if canImport(Speech) && canImport(AVFoundation)
import AVFoundation
import Speech
#endif

// MARK: - Character Model

struct RikiCharacter: Identifiable {
    let id: Int
    let name: String
    let imageName: String
    let greeting: String
    let responses: [String]
    
    static let allCharacters: [RikiCharacter] = [
        RikiCharacter(id: 1, name: "Momo", imageName: "animal1", greeting: "Hey friend! I'm Momo the Monkey! 🐵", responses: [
            "That's so cool! Tell me more!",
            "Ooh ooh! I love hearing about that!",
            "You're amazing! Keep going!",
            "Wow, I wish I could do that too!"
        ]),
        RikiCharacter(id: 2, name: "Goldie", imageName: "animal2", greeting: "Woof woof! I'm Goldie! 🐕", responses: [
            "That makes my tail wag so much!",
            "You're pawsitively awesome!",
            "I love playing with friends like you!",
            "Wanna go on an adventure together?"
        ]),
        RikiCharacter(id: 3, name: "Oreo", imageName: "animal3", greeting: "Hello! I'm Oreo! 🐒", responses: [
            "That sounds super fun!",
            "I like the way you think!",
            "You're such a good friend!",
            "Let's explore together!"
        ]),
        RikiCharacter(id: 4, name: "Leo", imageName: "animal4", greeting: "Roar! I'm Leo the Lion! 🦁", responses: [
            "You're brave like a lion!",
            "That's a roar-some idea!",
            "I believe in you, friend!",
            "Together we can do anything!"
        ]),
        RikiCharacter(id: 5, name: "Bunny", imageName: "animal5", greeting: "Hop hop! I'm Bunny! 🐰", responses: [
            "That makes me so hoppy!",
            "You're carrot-astic!",
            "Let's hop into fun together!",
            "I love having friends like you!"
        ]),
        RikiCharacter(id: 6, name: "Tiki", imageName: "animal6", greeting: "Rawr! I'm Tiki the Tiger! 🐯", responses: [
            "You're tiger-ific!",
            "That's a stripe-tacular idea!",
            "You've got the heart of a tiger!",
            "Let's be adventure buddies!"
        ]),
        RikiCharacter(id: 7, name: "Fluffy", imageName: "animal7", greeting: "Baa! I'm Fluffy! 🐑", responses: [
            "That's so warm and fuzzy!",
            "You make me feel all fluffy inside!",
            "I love spending time with you!",
            "Let's count happy thoughts together!"
        ]),
        RikiCharacter(id: 8, name: "Kitty", imageName: "animal8", greeting: "Meow! I'm Kitty! 🐱", responses: [
            "Purrfect! I love that!",
            "You're the cat's meow!",
            "That makes me purr with joy!",
            "Let's have a pawsome time!"
        ]),
        RikiCharacter(id: 9, name: "Panda", imageName: "animal9", greeting: "Hi there! I'm Panda! 🐼", responses: [
            "That's bamboo-tiful!",
            "You're un-bear-ably cool!",
            "I love cuddly chats like this!",
            "Let's roll around and have fun!"
        ]),
        RikiCharacter(id: 10, name: "Ellie", imageName: "animal10", greeting: "Trumpet! I'm Ellie! 🐘", responses: [
            "I'll never forget how awesome you are!",
            "That's ele-fantastic!",
            "You've got the biggest heart!",
            "Let's stomp into adventure!"
        ]),
        RikiCharacter(id: 11, name: "Ducky", imageName: "animal11", greeting: "Quack! I'm Ducky! 🦆", responses: [
            "That's just ducky!",
            "You're quack-tastic!",
            "Let's make a splash together!",
            "I'm so happy to chat with you!"
        ])
    ]
}

// MARK: - Main View

struct RikiCheckInView: View {
    @State private var selectedCharacter: RikiCharacter? = nil
    
    var body: some View {
        ZStack {
            GradientBackground()
            
            if let character = selectedCharacter {
                CharacterChatView(character: character) {
                    withAnimation(KomalAnimations.spring) {
                        selectedCharacter = nil
                    }
                }
            } else {
                CharacterSelectionView { character in
                    withAnimation(KomalAnimations.spring) {
                        selectedCharacter = character
                    }
                }
            }
        }
    }
}

// MARK: - Character Selection View

struct CharacterSelectionView: View {
    let onSelect: (RikiCharacter) -> Void
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Text("Choose Your Friend!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)
                
                Text("Who would you like to chat with today?")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(KomalColors.textSecondary)
            }
            .padding(.top, 20)
            
            // Character Grid
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(RikiCharacter.allCharacters) { character in
                        CharacterCard(character: character) {
                            onSelect(character)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120) // Space for floating menu
            }
        }
    }
}

// MARK: - Character Card

struct CharacterCard: View {
    let character: RikiCharacter
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Character Image
                ZStack {
                    Circle()
                        .fill(KomalColors.lavenderPurple.opacity(0.15))
                        .frame(width: 80, height: 80)
                    
                    if let uiImage = UIImage(named: character.imageName) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 70, height: 70)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 30))
                            .foregroundColor(KomalColors.bubblegumPink)
                    }
                }
                
                // Character Name
                Text(character.name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white)
                    .shadow(color: KomalColors.bubblegumPink.opacity(0.15), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(KomalAnimations.subtle, value: configuration.isPressed)
    }
}

// MARK: - Chat View

struct CharacterChatView: View {
    let character: RikiCharacter
    let onBack: () -> Void
    
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isListening: Bool = false
    @State private var freeTextMode = false
    @FocusState private var isInputFocused: Bool
#if canImport(Speech) && canImport(AVFoundation)
    @StateObject private var speechService = SpeechService.shared
#endif
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            ChatBubble(message: message, character: character)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    .id("bottom")
                }
                .onChange(of: messages.count) { _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            
            // Input Area
            inputArea
        }
        .onAppear {
            // Add greeting message
            let greeting = ChatMessage(
                id: UUID(),
                text: character.greeting,
                isFromUser: false
            )
            messages.append(greeting)
#if canImport(Speech) && canImport(AVFoundation)
            speechService.speak(greeting.text)
#endif
        }
    }
    
    // MARK: - Chat Header
    
    private var chatHeader: some View {
        HStack(spacing: 12) {
            // Back button
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(KomalColors.bubblegumPink)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
            }
            
            // Character avatar
            if let uiImage = UIImage(named: character.imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(KomalColors.pearlAqua, lineWidth: 2)
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(character.name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(KomalColors.pearlAqua)
                        .frame(width: 8, height: 8)
                    Text("Online")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.textSecondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Input Area
    
    private var inputArea: some View {
        VStack(spacing: 0) {
            // Listening indicator
            if isListening {
                HStack(spacing: 8) {
                    BreathingCircle(size: 12, color: KomalColors.bubblegumPink)
                    Text(freeTextMode ? "Listening for text…" : "Listening…")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.bubblegumPink)
                }
                .padding(.vertical, 8)
            }
            
            HStack(spacing: 12) {
                if freeTextMode {
                    // Text input (only when explicitly enabled)
                    HStack {
                        TextField("Type a message...", text: $inputText)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .focused($isInputFocused)
                        
                        if !inputText.isEmpty {
                            Button(action: { inputText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(KomalColors.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.white)
                            .overlay(
                                Capsule()
                                    .stroke(KomalColors.lavenderPurple.opacity(0.3), lineWidth: 1.5)
                            )
                    )
                } else {
                    Label("Hands-free mode", systemImage: "sparkles")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(KomalColors.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(.white.opacity(0.9)))
                }
                
                // Mic button
                Button(action: toggleListening) {
                    Image(systemName: isListening ? "waveform" : "mic.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(isListening ? KomalColors.bubblegumPink : KomalColors.lavenderPurple)
                        )
                        .scaleEffect(isListening ? 1.1 : 1.0)
                        .animation(KomalAnimations.spring, value: isListening)
                }

                Button {
                    withAnimation(KomalAnimations.spring) {
                        freeTextMode.toggle()
                        if !freeTextMode {
                            isInputFocused = false
                            inputText = ""
                        }
                    }
                } label: {
                    Image(systemName: freeTextMode ? "keyboard.chevron.compact.down" : "keyboard")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(KomalColors.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.white.opacity(0.9)))
                }
                
                // Send button
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(inputText.isEmpty ? KomalColors.pearlAqua.opacity(0.5) : KomalColors.bubblegumPink)
                        )
                }
                .disabled(!freeTextMode || inputText.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 100) // Space for floating menu
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: -2)
            )
        }
    }
    
    // MARK: - Actions
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = ChatMessage(id: UUID(), text: inputText, isFromUser: true)
        messages.append(userMessage)
        inputText = ""
        isInputFocused = false
        
        // Simulate character response after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let response = character.responses.randomElement() ?? "That's so cool!"
            let responseMessage = ChatMessage(id: UUID(), text: response, isFromUser: false)
            withAnimation {
                messages.append(responseMessage)
            }
#if canImport(Speech) && canImport(AVFoundation)
            speechService.speak(response)
#endif
        }
    }
    
    private func toggleListening() {
        withAnimation(KomalAnimations.spring) {
            isListening.toggle()
        }
#if canImport(Speech) && canImport(AVFoundation)
        speechService.toggleListening()
        if !speechService.isListening {
            commitVoiceTranscript()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                if speechService.isListening {
                    speechService.stopListening()
                    isListening = false
                    commitVoiceTranscript()
                }
            }
        }
#endif
    }

    private func commitVoiceTranscript() {
#if canImport(Speech) && canImport(AVFoundation)
        let transcript = speechService.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else { return }
        inputText = transcript
        sendMessage()
#endif
    }
}

// MARK: - Chat Message Model

struct ChatMessage: Identifiable {
    let id: UUID
    let text: String
    let isFromUser: Bool
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage
    let character: RikiCharacter
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromUser {
                Spacer(minLength: 60)
            } else {
                // Character avatar for their messages
                if let uiImage = UIImage(named: character.imageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(KomalColors.lavenderPurple.opacity(0.3))
                        .frame(width: 32, height: 32)
                }
            }
            
            Text(message.text)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(message.isFromUser ? .white : KomalColors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(message.isFromUser ? KomalColors.bubblegumPink : Color.white)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
            
            if !message.isFromUser {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Legacy Components (kept for compatibility)

struct StepHeader: View {
    let step: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<4) { index in
                Circle()
                    .fill(index <= step ? KomalColors.bubblegumPink : KomalColors.lavenderPurple.opacity(0.3))
                    .frame(width: 10, height: 10)
            }
        }
    }
}

struct RikiAssistantCard: View {
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        BubblyCard(tintColor: KomalColors.violet) {
            VStack(spacing: 12) {
                RikiAvatarView(size: 100)

                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)

                Text(message)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(KomalColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Button(buttonTitle, action: action)
                    .buttonStyle(SecondaryPillButtonStyle())
            }
        }
    }
}

struct RikiAvatarView: View {
    var size: CGFloat = 150

    var body: some View {
        ZStack {
            BreathingCircle(size: size, color: KomalColors.bubblegumPink.opacity(0.3))

            BreathingCircle(size: size * 0.75, color: KomalColors.pearlAqua.opacity(0.5))

            Image(systemName: "pawprint.fill")
                .font(.system(size: size * 0.35, weight: .semibold))
                .foregroundColor(KomalColors.bubblegumPink)
        }
        .overlay(
            Text("Riki")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(KomalColors.textSecondary),
            alignment: .bottom
        )
    }
}
#endif
