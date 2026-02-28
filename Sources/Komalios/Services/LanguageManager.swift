import SwiftUI

// MARK: - Language Enum

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case french = "fr"
    case spanish = "es"
    case portuguese = "pt"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .french: return "Français"
        case .spanish: return "Español"
        case .portuguese: return "Português"
        }
    }

    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .french: return "🇫🇷"
        case .spanish: return "🇪🇸"
        case .portuguese: return "🇧🇷"
        }
    }

    var nativeName: String {
        switch self {
        case .english: return "English"
        case .french: return "Français"
        case .spanish: return "Español"
        case .portuguese: return "Português"
        }
    }
}

// MARK: - Language Manager

@MainActor
final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    private static let storageKey = "komal.selectedLanguage"

    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: Self.storageKey)
        }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: Self.storageKey),
           let lang = AppLanguage(rawValue: saved) {
            self.currentLanguage = lang
        } else {
            self.currentLanguage = .english
        }
    }

    // MARK: - Lookup

    func localized(_ key: String) -> String {
        let dict: [String: String]
        switch currentLanguage {
        case .english:    dict = EnglishStrings.all
        case .french:     dict = FrenchStrings.all
        case .spanish:    dict = SpanishStrings.all
        case .portuguese: dict = PortugueseStrings.all
        }

        if let value = dict[key] {
            return value
        }
        // Fallback to English
        if currentLanguage != .english, let value = EnglishStrings.all[key] {
            return value
        }
        // Fallback to key itself
        return key
    }

    func localized(_ key: String, _ args: CVarArg...) -> String {
        let template = localized(key)
        return String(format: template, arguments: args)
    }
}
