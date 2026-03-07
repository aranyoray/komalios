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

    /// Guard against re-entrant stopRecording calls from the recognition task callback
    private var isStopping = false

    func startRecording() {
        // Reset
        transcript = ""
        errorMessage = nil

        // Check authorization
        guard isAuthorized else {
            errorMessage = "Speech recognition not authorized"
            return
        }

        // Clean up any previous session without triggering re-entrant stop
        cleanupPreviousSession()

        // Configure audio session for recording
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
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

        // Get input node and validate format
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Guard against 0-channel format (common on iOS Simulator with no mic hardware)
        guard recordingFormat.channelCount > 0 else {
            errorMessage = "No microphone input available"
            return
        }

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
                    // Only auto-stop if we're still recording — prevents re-entrant loops
                    if self.isRecording {
                        self.stopRecording()
                    }
                }
            }
        }

        // Remove any stale tap before installing a new one.
        inputNode.removeTap(onBus: 0)

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
            cleanupPreviousSession()
        }
    }

    /// Clean up engine, tap, request, and task without triggering re-entrant callbacks
    private func cleanupPreviousSession() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil
    }

    func stopRecording() {
        guard !isStopping else { return }
        isStopping = true

        cleanupPreviousSession()
        isRecording = false

        // Restore audio session for playback so TTS can work after recording
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            #if DEBUG
            print("[SpeechRecognizer] Failed to restore audio session: \(error.localizedDescription)")
            #endif
        }

        isStopping = false
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
