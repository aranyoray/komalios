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
        ensureAudioSessionActive()
    }

    /// Ensure the audio session is active. Category is now managed at the
    /// session level (SpeechRecognizer.configureVoiceChatSession()) to avoid
    /// category-switching races that cause 0 Hz format bugs.
    private func ensureAudioSessionActive() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            #if DEBUG
            print("[AudioPlayback] Failed to activate audio session: \(error.localizedDescription)")
            #endif
        }
    }

    func speak(text: String, characterName: String) async {
        stop()

        ensureAudioSessionActive()

        // Defense-in-depth: strip any inappropriate words before TTS synthesis
        let sanitized = BrowserState.stripForTTS(text)
        guard !sanitized.isEmpty else { return }

        do {
            let audioData = try await ttsService.synthesize(text: sanitized, characterName: characterName)
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPlaying = true
        } catch {
            isPlaying = false
            #if DEBUG
            print("[AudioPlayback] TTS speak error: \(error.localizedDescription)")
            #endif
        }
    }

    func stop() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        audioPlayer?.stop()
        audioPlayer = nil
        // Only publish if actually changing — prevents spurious onReceive fires
        if isPlaying { isPlaying = false }
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
        fadeTimer?.invalidate()
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
