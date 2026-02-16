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
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .duckOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func speak(text: String, characterName: String) async {
        guard !isMuted else { return }
        stop()
        do {
            let audioData = try await ttsService.synthesize(text: text, characterName: characterName)
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPlaying = true
        } catch {
            isPlaying = false
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
