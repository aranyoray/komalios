#if os(iOS)
import Foundation
import AVFoundation

@MainActor
class AudioPlaybackManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var isMuted = false

    private var audioPlayer: AVAudioPlayer?
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
        guard !isMuted else { return }
        stop()

        // Reconfigure audio session for playback before each speak call,
        // since SpeechRecognizer may have switched it to .record mode.
        configureAudioSession()

        do {
            let audioData = try await ttsService.synthesize(text: text, characterName: characterName)
            // Re-check muted state after async call returns
            guard !isMuted else { return }
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
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
    }

    func interruptForChildSpeech() { stop() }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.isPlaying = false }
    }
}
#endif
