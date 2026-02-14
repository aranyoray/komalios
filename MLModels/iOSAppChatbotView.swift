// ChatbotView.swift
// Chatbot interface with speech-to-text support

import SwiftUI

struct ChatbotView: View {
    @StateObject private var viewModel = ChatbotViewModel()
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Messages List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        if let lastMessage = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Input Area
                HStack(spacing: 12) {
                    // Voice Input Button
                    Button(action: {
                        speechRecognizer.toggleRecording()
                        if !speechRecognizer.isRecording {
                            // When recording stops, use the transcript
                            viewModel.inputMessage = speechRecognizer.transcript
                        }
                    }) {
                        Image(systemName: speechRecognizer.isRecording ? "mic.fill" : "mic")
                            .font(.title2)
                            .foregroundColor(speechRecognizer.isRecording ? .red : .blue)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(speechRecognizer.isRecording ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                            )
                    }
                    .disabled(!speechRecognizer.isAuthorized)
                    
                    // Text Input
                    TextField("Message...", text: $viewModel.inputMessage, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .focused($isTextFieldFocused)
                        .lineLimit(1...5)
                    
                    // Send Button
                    Button(action: {
                        Task {
                            await viewModel.sendMessage()
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(viewModel.inputMessage.isEmpty ? .gray : .blue)
                    }
                    .disabled(viewModel.inputMessage.isEmpty || viewModel.isLoading)
                }
                .padding()
                .background(Color(.systemBackground))
                
                // Recording Indicator
                if speechRecognizer.isRecording {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundColor(.red)
                        Text("Recording...")
                            .foregroundColor(.red)
                        Spacer()
                        Text(speechRecognizer.transcript)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .background(Color(.systemBackground))
                }
                
                // Error Message
                if let error = speechRecognizer.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("Safety Chatbot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.clearConversation()
                    }) {
                        Image(systemName: "trash")
                    }
                }
            }
            .onAppear {
                if viewModel.messages.isEmpty {
                    viewModel.addSystemMessage("Hi! I'm your safety assistant. Ask me anything about online safety, content filtering, or how to stay safe online.")
                }
            }
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: SafetyChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .padding(12)
                    .background(bubbleColor)
                    .foregroundColor(message.isUser ? .white : .primary)
                    .cornerRadius(16)
                
                if message.isFiltered {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.shield")
                            .font(.caption2)
                        Text("Content filtered")
                            .font(.caption2)
                    }
                    .foregroundColor(.orange)
                }
                
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 280, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser {
                Spacer()
            }
        }
    }
    
    private var bubbleColor: Color {
        if message.isSystem {
            return Color.orange.opacity(0.2)
        } else if message.isUser {
            return Color.blue
        } else {
            return Color(.systemGray5)
        }
    }
}

// MARK: - Models

struct SafetyChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp: Date
    let isFiltered: Bool
    let isSystem: Bool
    
    init(text: String, isUser: Bool, isFiltered: Bool = false, isSystem: Bool = false) {
        self.text = text
        self.isUser = isUser
        self.timestamp = Date()
        self.isFiltered = isFiltered
        self.isSystem = isSystem
    }
}

// MARK: - ViewModel

@MainActor
class ChatbotViewModel: ObservableObject {
    @Published var messages: [SafetyChatMessage] = []
    @Published var inputMessage: String = ""
    @Published var isLoading: Bool = false
    @Published var conversationId: String?
    
    private let api = KomalWebAPI(baseURL: "http://localhost:5000")
    
    func sendMessage() async {
        guard !inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let userMessage = inputMessage
        inputMessage = ""
        
        // Add user message to UI
        messages.append(SafetyChatMessage(text: userMessage, isUser: true))
        
        isLoading = true
        
        do {
            let response = try await api.sendChatMessage(userMessage, conversationId: conversationId)
            
            // Update conversation ID
            conversationId = response.conversation_id
            
            // Add bot response
            messages.append(SafetyChatMessage(
                text: response.response,
                isUser: false,
                isFiltered: response.safety_check?.filtered_content ?? false
            ))
            
            // If content was filtered, show warning
            if let safetyCheck = response.safety_check, safetyCheck.filtered_content {
                if let reason = safetyCheck.reason {
                    addSystemMessage("⚠️ Note: \(reason)")
                }
            }
            
        } catch {
            messages.append(SafetyChatMessage(
                text: "Sorry, I encountered an error: \(error.localizedDescription)",
                isUser: false
            ))
        }
        
        isLoading = false
    }
    
    func addSystemMessage(_ text: String) {
        messages.append(SafetyChatMessage(text: text, isUser: false, isSystem: true))
    }
    
    func clearConversation() {
        messages.removeAll()
        conversationId = nil
        addSystemMessage("Conversation cleared. How can I help you?")
    }
}

// MARK: - Preview

struct ChatbotView_Previews: PreviewProvider {
    static var previews: some View {
        ChatbotView()
    }
}

