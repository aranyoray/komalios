import SwiftUI
import os

// MARK: - Language Enum

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case french = "fr"
    case spanish = "es"
    case portuguese = "pt"
    case arabic = "ar"

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .english: return "English"
        case .french: return "Français"
        case .spanish: return "Español"
        case .portuguese: return "Português"
        case .arabic: return "العربية"
        }
    }

    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .french: return "🇫🇷"
        case .spanish: return "🇪🇸"
        case .portuguese: return "🇧🇷"
        case .arabic: return "🇸🇦"
        }
    }

    var isRTL: Bool {
        switch self {
        case .arabic: return true
        default: return false
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var layoutDirection: LayoutDirection {
        isRTL ? .rightToLeft : .leftToRight
    }

    /// The string dictionary for this language.
    var strings: [String: String] {
        switch self {
        case .english:    return EnglishStrings.all
        case .french:     return FrenchStrings.all
        case .spanish:    return SpanishStrings.all
        case .portuguese: return PortugueseStrings.all
        case .arabic:     return ArabicStrings.all
        }
    }

    // MARK: - CLDR Plural Rules

    /// Returns the plural category for a given count based on CLDR rules.
    ///
    /// Arabic: zero, one, two, few (3-10), many (11-99), other
    /// English/French/Spanish/Portuguese: one, other
    func pluralCategory(for count: Int) -> String {
        switch self {
        case .arabic:
            if count == 0 { return "zero" }
            if count == 1 { return "one" }
            if count == 2 { return "two" }
            let mod100 = count % 100
            if mod100 >= 3 && mod100 <= 10 { return "few" }
            if mod100 >= 11 && mod100 <= 99 { return "many" }
            return "other"
        case .french:
            // French: 0 and 1 are singular
            return (count == 0 || count == 1) ? "one" : "other"
        default:
            // English, Spanish, Portuguese: standard one/other
            return count == 1 ? "one" : "other"
        }
    }

    /// Detect the best matching AppLanguage for the device locale.
    static func fromDeviceLocale() -> AppLanguage? {
        guard let code = Locale.current.language.languageCode?.identifier else { return nil }
        return AppLanguage(rawValue: code)
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
        } else if let detected = AppLanguage.fromDeviceLocale() {
            // Auto-detect device language on first launch
            self.currentLanguage = detected
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

    /// The locale identifier to use for SFSpeechRecognizer / TTS voice selection.
    /// Maps AppLanguage to full BCP-47 locale codes that Apple/Google TTS support.
    nonisolated static var speechRecognitionLocale: String {
        let lang = _language.withLock { $0 }
        switch lang {
        case .english:    return "en-US"
        case .french:     return "fr-FR"
        case .spanish:    return "es-ES"
        case .portuguese: return "pt-BR"
        case .arabic:     return "ar-SA"
        }
    }

    /// Static nonisolated lookup — callable from any isolation context.
    nonisolated static func localized(_ key: String) -> String {
        let lang = _language.withLock { $0 }
        let dict = lang.strings

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

    // MARK: - Pluralization

    /// Returns the pluralized string for a key and count.
    ///
    /// Looks up `"key.zero"`, `"key.one"`, `"key.two"`, `"key.few"`, `"key.many"`, `"key.other"`
    /// based on CLDR plural rules for the current language.
    /// Falls back to base key if the plural variant is not found.
    nonisolated static func pluralized(_ key: String, count: Int) -> String {
        let lang = _language.withLock { $0 }
        let category = lang.pluralCategory(for: count)
        let pluralKey = "\(key).\(category)"
        let dict = lang.strings

        // Try plural-specific key first
        if let value = dict[pluralKey] {
            return String(format: value, count)
        }
        // Fall back to base key
        if let value = dict[key] {
            return String(format: value, count)
        }
        // Fall back to English plural variant
        if lang != .english {
            let enCategory = AppLanguage.english.pluralCategory(for: count)
            let enPluralKey = "\(key).\(enCategory)"
            if let value = EnglishStrings.all[enPluralKey] {
                return String(format: value, count)
            }
            if let value = EnglishStrings.all[key] {
                return String(format: value, count)
            }
        }
        return key
    }
}
