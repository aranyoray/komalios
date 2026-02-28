#if os(iOS)
import Foundation
import AVFoundation

@MainActor
class AudioPlaybackManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var wasInterrupted = false

    private var audioPlayer: AVAudioPlayer?
    private var fadeTimer: Timer?
    private let ttsService = TextToSpeechService.shared

    override init() {
        super.init()
        configureAudioSession()
    }

    /// Configure audio session for playback. Must be called before each play
    /// because SpeechRecognizer switches the session to .record mode.
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[AudioPlayback] Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    func speak(text: String, characterName: String) async {
        stop()

        // Reconfigure audio session for playback before each speak call,
        // since SpeechRecognizer may have switched it to .record mode.
        configureAudioSession()

        // Per spec: no censoring with ### or asterisks — AI redirects naturally via system prompt.
        // TTS speaks the AI's response as-is since it's already child-safe.
        guard !text.isEmpty else { return }

        do {
            let audioData = try await ttsService.synthesize(text: text, characterName: characterName)
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPlaying = true
        } catch {
            isPlaying = false
            print("[AudioPlayback] TTS speak error: \(error.localizedDescription)")
        }
    }

    func stop() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
    }

    func interruptForChildSpeech() {
        guard isPlaying, let player = audioPlayer else {
            stop()
            return
        }
        wasInterrupted = true
        // Quick 0.3s volume fade-out for natural feel
        let steps = 6
        let interval = 0.3 / Double(steps)
        let volumeStep = player.volume / Float(steps)
        var remaining = steps
        fadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                remaining -= 1
                if remaining <= 0 {
                    timer.invalidate()
                    self?.fadeTimer = nil
                    self?.audioPlayer?.stop()
                    self?.audioPlayer = nil
                    self?.isPlaying = false
                } else {
                    self?.audioPlayer?.volume -= volumeStep
                }
            }
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.isPlaying = false }
    }
}
#endif
