// SpeechRecognizer.swift
// Speech-to-text using Apple's Speech framework

#if os(iOS)
import Foundation
import Speech
import AVFoundation

@MainActor
class SpeechRecognizer: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var isAuthorized: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // MARK: - Initialization
    
    init() {
        Task {
            await requestAuthorization()
        }
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { authStatus in
                continuation.resume(returning: authStatus)
            }
        }

        switch status {
        case .authorized:
            isAuthorized = true
        case .denied, .restricted, .notDetermined:
            isAuthorized = false
            errorMessage = "Speech recognition not authorized"
        @unknown default:
            isAuthorized = false
        }
    }
    
    // MARK: - Recording Control
    
    func startRecording() {
        // Reset
        transcript = ""
        errorMessage = nil
        
        // Check authorization
        guard isAuthorized else {
            errorMessage = "Speech recognition not authorized"
            return
        }
        
        // Cancel any existing task
        if let task = recognitionTask {
            task.cancel()
            recognitionTask = nil
        }
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Failed to configure audio session: \(error.localizedDescription)"
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Unable to create recognition request"
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Get input node
        let inputNode = audioEngine.inputNode
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                Task { @MainActor in
                    self.transcript = result.bestTranscription.formattedString
                }
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                Task { @MainActor in
                    self.stopRecording()
                }
            }
        }
        
        // Configure microphone input
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
        } catch {
            errorMessage = "Failed to start audio engine: \(error.localizedDescription)"
            stopRecording()
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        isRecording = false

        // Restore audio session for playback so TTS can work after recording
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[SpeechRecognizer] Failed to restore audio session: \(error.localizedDescription)")
        }
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
}
#endif
