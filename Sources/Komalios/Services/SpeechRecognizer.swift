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
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // MARK: - Initialization
    
    init() {
        let localeId = LanguageManager.speechRecognitionLocale
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeId))
        Task {
            await requestAuthorization()
        }
    }

    /// Update the recognizer locale (e.g. when the user changes language).
    func updateLocale() {
        let localeId = LanguageManager.speechRecognitionLocale
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeId))
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

        // Ensure audio session is active (category is managed by the caller — e.g.
        // FocusedChatView sets .playAndRecord for the entire session to avoid
        // category-switching races that cause 0 Hz format bugs).
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Failed to activate audio session: \(error.localizedDescription)"
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

        // Guard against invalid format (0 Hz / 0 channels — common on iOS Simulator with no mic hardware)
        guard recordingFormat.channelCount > 0, recordingFormat.sampleRate > 0 else {
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
        audioEngine.reset()

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
        isStopping = false
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    // MARK: - Audio Session Helpers

    /// Configure the shared audio session for a voice chat session.
    /// Call once on view appear; do NOT switch categories mid-session.
    static func configureVoiceChatSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playAndRecord,
                mode: .default,
                options: [.duckOthers, .defaultToSpeaker, .allowBluetoothHFP]
            )
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            #if DEBUG
            print("[SpeechRecognizer] Failed to configure voice chat session: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Shared Permission Check

    /// Check and request microphone + speech recognition permissions.
    /// Returns true only if both are granted.
    static func requestPermissions() async -> Bool {
        // Microphone
        let micGranted: Bool
        if #available(iOS 17.0, *) {
            let micStatus = AVAudioApplication.shared.recordPermission
            if micStatus == .undetermined {
                micGranted = await AVAudioApplication.requestRecordPermission()
            } else {
                micGranted = (micStatus == .granted)
            }
        } else {
            let session = AVAudioSession.sharedInstance()
            if session.recordPermission == .undetermined {
                micGranted = await withCheckedContinuation { continuation in
                    session.requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
            } else {
                micGranted = (session.recordPermission == .granted)
            }
        }

        guard micGranted else { return false }

        // Speech recognition
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        if speechStatus == .notDetermined {
            let status = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { authStatus in
                    continuation.resume(returning: authStatus)
                }
            }
            return status == .authorized
        }
        return speechStatus == .authorized
    }
}
#endif
