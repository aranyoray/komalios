import Foundation

actor TextToSpeechService {
    static let shared = TextToSpeechService()

    private let apiKey = Config.googleCloudAPIKey
    private let endpoint = "https://texttospeech.googleapis.com/v1/text:synthesize"

    private init() {}

    private struct VoiceConfig {
        let name: String, pitch: Double, speakingRate: Double
    }

    private let voices: [String: VoiceConfig] = [
        "Komal": .init(name: "en-US-Neural2-F", pitch: 1.0, speakingRate: 0.95),
        "Momo": .init(name: "en-US-Neural2-A", pitch: 4.0, speakingRate: 1.15),
        "Goldie": .init(name: "en-US-Neural2-F", pitch: 0.0, speakingRate: 1.0),
        "Oreo": .init(name: "en-US-Neural2-C", pitch: 2.0, speakingRate: 1.05),
        "Leo": .init(name: "en-US-Neural2-J", pitch: -2.0, speakingRate: 0.95),
        "Bunny": .init(name: "en-US-Neural2-C", pitch: 3.0, speakingRate: 0.9),
        "Tiki": .init(name: "en-US-Neural2-D", pitch: 0.0, speakingRate: 1.05),
        "Fluffy": .init(name: "en-US-Neural2-F", pitch: 2.0, speakingRate: 0.85),
        "Kitty": .init(name: "en-US-Neural2-E", pitch: 1.0, speakingRate: 1.1),
        "Panda": .init(name: "en-US-Neural2-A", pitch: -1.0, speakingRate: 0.9),
        "Ellie": .init(name: "en-US-Neural2-F", pitch: -1.0, speakingRate: 0.95),
        "Ducky": .init(name: "en-US-Neural2-E", pitch: 3.0, speakingRate: 1.1),
    ]

    func synthesize(text: String, characterName: String) async throws -> Data {
        let voice = voices[characterName] ?? VoiceConfig(name: "en-US-Neural2-F", pitch: 0.0, speakingRate: 1.0)

        let body: [String: Any] = [
            "input": ["text": text],
            "voice": ["languageCode": "en-US", "name": voice.name],
            "audioConfig": ["audioEncoding": "LINEAR16", "pitch": voice.pitch, "speakingRate": voice.speakingRate]
        ]

        guard let url = URL(string: "\(endpoint)?key=\(apiKey)") else { throw TTSError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw TTSError.apiError("TTS API returned non-200 status")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let audioContent = json["audioContent"] as? String,
              let audioData = Data(base64Encoded: audioContent) else {
            throw TTSError.invalidResponse
        }
        return audioData
    }
}

enum TTSError: LocalizedError {
    case invalidURL, apiError(String), invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid TTS API URL"
        case .apiError(let msg): "TTS API error: \(msg)"
        case .invalidResponse: "Invalid TTS response"
        }
    }
}
