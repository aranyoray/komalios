import SwiftUI
import os

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

    /// Thread-safe storage for current language so nonisolated code can read it.
    private nonisolated static let _language = OSAllocatedUnfairLock(initialState: AppLanguage.english)

    @Published var currentLanguage: AppLanguage {
        didSet {
            let lang = currentLanguage
            Self._language.withLock { [lang] in $0 = lang }
            UserDefaults.standard.set(lang.rawValue, forKey: Self.storageKey)
        }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: Self.storageKey),
           let lang = AppLanguage(rawValue: saved) {
            self.currentLanguage = lang
        } else {
            self.currentLanguage = .english
        }
        let initial = currentLanguage
        Self._language.withLock { $0 = initial }
    }

    // MARK: - Lookup

    /// Instance method — callable from @MainActor contexts that already have `shared`.
    func localized(_ key: String) -> String {
        Self.localized(key)
    }

    func localized(_ key: String, _ args: CVarArg...) -> String {
        let template = Self.localized(key)
        return String(format: template, arguments: args)
    }

    /// Static nonisolated lookup — callable from any isolation context.
    nonisolated static func localized(_ key: String) -> String {
        let lang = _language.withLock { $0 }
        let dict: [String: String]
        switch lang {
        case .english:    dict = EnglishStrings.all
        case .french:     dict = FrenchStrings.all
        case .spanish:    dict = SpanishStrings.all
        case .portuguese: dict = PortugueseStrings.all
        }

        if let value = dict[key] {
            return value
        }
        // Fallback to English
        if lang != .english, let value = EnglishStrings.all[key] {
            return value
        }
        // Fallback to key itself
        return key
    }

    nonisolated static func localized(_ key: String, _ args: CVarArg...) -> String {
        let template: String = localized(key)
        return String(format: template, arguments: args)
    }
}
