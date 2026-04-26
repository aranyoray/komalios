import Foundation

actor TextToSpeechService {
    static let shared = TextToSpeechService()

    private let apiKey = Config.googleCloudAPIKey
    private let endpoint = "https://texttospeech.googleapis.com/v1/text:synthesize"

    private init() {}

    private struct VoiceConfig {
        let pitch: Double, speakingRate: Double
        /// Voice variant index used to differentiate characters within the same locale.
        /// Maps to a specific Neural2 voice per language (see `voiceName(for:variant:)`).
        let variant: Int
    }

    // Variants give each character a distinct voice. The actual Neural2 voice name
    // is resolved per-locale in voiceName(for:variant:).
    private let voices: [String: VoiceConfig] = [
        "Komal":  .init(pitch: 1.0, speakingRate: 1.15, variant: 0),
        "Momo":   .init(pitch: 4.0, speakingRate: 1.30, variant: 1),
        "Goldie": .init(pitch: 0.0, speakingRate: 1.20, variant: 0),
        "Oreo":   .init(pitch: 2.0, speakingRate: 1.20, variant: 2),
        "Leo":    .init(pitch: -2.0, speakingRate: 1.10, variant: 3),
        "Bunny":  .init(pitch: 3.0, speakingRate: 1.05, variant: 2),
        "Tiki":   .init(pitch: 0.0, speakingRate: 1.20, variant: 4),
        "Fluffy": .init(pitch: 2.0, speakingRate: 1.05, variant: 0),
        "Kitty":  .init(pitch: 1.0, speakingRate: 1.25, variant: 5),
        "Panda":  .init(pitch: -1.0, speakingRate: 1.10, variant: 1),
        "Ellie":  .init(pitch: -1.0, speakingRate: 1.10, variant: 0),
        "Ducky":  .init(pitch: 3.0, speakingRate: 1.30, variant: 5),
    ]

    /// Maps (locale, variant) to a Google Cloud TTS voice name.
    /// English uses en-IN Journey voices (warm, conversational, Indian English accent).
    /// Other locales use Neural2 voices.
    private func voiceName(for locale: String, variant: Int) -> String {
        let pool: [String]
        switch locale {
        case "fr-FR":
            pool = ["fr-FR-Neural2-A", "fr-FR-Neural2-B", "fr-FR-Neural2-C",
                     "fr-FR-Neural2-D", "fr-FR-Neural2-E", "fr-FR-Neural2-A"]
        case "es-ES":
            pool = ["es-ES-Neural2-A", "es-ES-Neural2-B", "es-ES-Neural2-C",
                     "es-ES-Neural2-D", "es-ES-Neural2-E", "es-ES-Neural2-F"]
        case "pt-BR":
            pool = ["pt-BR-Neural2-A", "pt-BR-Neural2-B", "pt-BR-Neural2-C",
                     "pt-BR-Neural2-A", "pt-BR-Neural2-B", "pt-BR-Neural2-C"]
        case "ar-SA":
            // Arabic has fewer Neural2 options; fall back to ar-XA
            pool = ["ar-XA-Neural2-A", "ar-XA-Neural2-C", "ar-XA-Neural2-D",
                     "ar-XA-Neural2-A", "ar-XA-Neural2-C", "ar-XA-Neural2-D"]
        default: // en-IN (Indian English) — Journey voices for warm, human-like quality
            pool = ["en-IN-Neural2-D", "en-IN-Neural2-A", "en-IN-Neural2-C",
                     "en-IN-Neural2-B", "en-IN-Neural2-D", "en-IN-Neural2-A"]
        }
        return pool[variant % pool.count]
    }

    /// Returns the TTS locale code for API requests.
    /// Maps internal locale strings to the correct Google Cloud TTS languageCode.
    private func ttsLocaleCode(for locale: String) -> String {
        switch locale {
        case "ar-SA": return "ar-XA"
        default: return locale.hasPrefix("en") ? "en-IN" : locale
        }
    }

    func synthesize(text: String, characterName: String) async throws -> Data {
        let voice = voices[characterName] ?? VoiceConfig(pitch: 0.0, speakingRate: 1.0, variant: 0)
        let locale = LanguageManager.speechRecognitionLocale
        let ttsLocale = ttsLocaleCode(for: locale)
        let resolvedVoiceName = voiceName(for: locale, variant: voice.variant)

        let body: [String: Any] = [
            "input": ["text": text],
            "voice": ["languageCode": ttsLocale, "name": resolvedVoiceName],
            "audioConfig": ["audioEncoding": "LINEAR16", "pitch": voice.pitch, "speakingRate": voice.speakingRate]
        ]

        guard let url = URL(string: endpoint) else { throw TTSError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let bodyStr = String(data: data, encoding: .utf8) ?? "no body"
            #if DEBUG
            print("[TTS] API error: status=\(statusCode) body=\(bodyStr)")
            #endif
            throw TTSError.apiError("status \(statusCode): \(bodyStr)")
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
