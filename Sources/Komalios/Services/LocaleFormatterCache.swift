#if os(iOS)
import Foundation

// MARK: - Locale Formatter Cache

/// Provides cached `DateFormatter` and `NumberFormatter` instances keyed by locale
/// and style/format, avoiding repeated allocations of expensive formatter objects.
///
/// Usage:
/// ```
/// // Uses current app language locale automatically
/// let df = LocaleFormatterCache.dateFormatter(style: .medium)
///
/// // Explicit locale
/// let nf = LocaleFormatterCache.numberFormatter(style: .decimal, locale: Locale(identifier: "ar"))
/// ```
enum LocaleFormatterCache {

    // MARK: - Internal Types

    /// Wrapper to let us use `String` keys inside `NSCache`.
    private final class CacheKey: NSObject {
        let key: String
        init(_ key: String) { self.key = key }
        override var hash: Int { key.hashValue }
        override func isEqual(_ object: Any?) -> Bool {
            (object as? CacheKey)?.key == key
        }
    }

    /// Box to store formatter values inside `NSCache`.
    private final class FormatterBox: NSObject {
        let formatter: Formatter
        init(_ formatter: Formatter) { self.formatter = formatter }
    }

    // MARK: - Storage

    private static let cache = NSCache<CacheKey, FormatterBox>()
    private static let lock = NSLock()

    // MARK: - Date Formatter (by style)

    /// Returns a cached `DateFormatter` configured with the given date and time style
    /// for the specified locale.
    static func dateFormatter(
        style dateStyle: DateFormatter.Style,
        timeStyle: DateFormatter.Style = .none,
        locale: Locale
    ) -> DateFormatter {
        let key = "date-style-\(dateStyle.rawValue)-\(timeStyle.rawValue)-\(locale.identifier)"
        return cached(key: key) {
            let f = DateFormatter()
            f.dateStyle = dateStyle
            f.timeStyle = timeStyle
            f.locale = locale
            return f
        }
    }

    /// Convenience that uses the current app language locale.
    static func dateFormatter(
        style dateStyle: DateFormatter.Style,
        timeStyle: DateFormatter.Style = .none
    ) -> DateFormatter {
        dateFormatter(style: dateStyle, timeStyle: timeStyle, locale: currentLocale)
    }

    // MARK: - Date Formatter (by format string)

    /// Returns a cached `DateFormatter` configured with a custom format string
    /// for the specified locale.
    static func dateFormatter(format: String, locale: Locale) -> DateFormatter {
        let key = "date-fmt-\(format)-\(locale.identifier)"
        return cached(key: key) {
            let f = DateFormatter()
            f.dateFormat = format
            f.locale = locale
            return f
        }
    }

    /// Convenience that uses the current app language locale.
    static func dateFormatter(format: String) -> DateFormatter {
        dateFormatter(format: format, locale: currentLocale)
    }

    // MARK: - Number Formatter

    /// Returns a cached `NumberFormatter` configured with the given style
    /// for the specified locale.
    static func numberFormatter(
        style: NumberFormatter.Style,
        locale: Locale
    ) -> NumberFormatter {
        let key = "number-\(style.rawValue)-\(locale.identifier)"
        return cached(key: key) {
            let f = NumberFormatter()
            f.numberStyle = style
            f.locale = locale
            return f
        }
    }

    /// Convenience that uses the current app language locale.
    static func numberFormatter(style: NumberFormatter.Style) -> NumberFormatter {
        numberFormatter(style: style, locale: currentLocale)
    }

    // MARK: - BiDi Sanitization

    /// Removes Unicode Bidirectional control characters from a string.
    ///
    /// Useful for sanitizing URLs or paths that may have been contaminated with
    /// invisible BiDi overrides (e.g., when displaying URLs in an RTL context).
    ///
    /// Stripped characters:
    /// - U+200E  LEFT-TO-RIGHT MARK
    /// - U+200F  RIGHT-TO-LEFT MARK
    /// - U+202A  LEFT-TO-RIGHT EMBEDDING
    /// - U+202B  RIGHT-TO-LEFT EMBEDDING
    /// - U+202C  POP DIRECTIONAL FORMATTING
    /// - U+202D  LEFT-TO-RIGHT OVERRIDE
    /// - U+202E  RIGHT-TO-LEFT OVERRIDE
    /// - U+2066  LEFT-TO-RIGHT ISOLATE
    /// - U+2067  RIGHT-TO-LEFT ISOLATE
    /// - U+2068  FIRST STRONG ISOLATE
    /// - U+2069  POP DIRECTIONAL ISOLATE
    static func stripBiDiOverrides(_ string: String) -> String {
        let bidiScalars: Set<Unicode.Scalar> = [
            "\u{200E}", "\u{200F}",
            "\u{202A}", "\u{202B}", "\u{202C}", "\u{202D}", "\u{202E}",
            "\u{2066}", "\u{2067}", "\u{2068}", "\u{2069}",
        ]
        return String(string.unicodeScalars.filter { !bidiScalars.contains($0) })
    }

    // MARK: - Private Helpers

    /// Resolves the current app language locale.
    /// Reads from UserDefaults (same source as LanguageManager) to stay nonisolated.
    private static var currentLocale: Locale {
        if let saved = UserDefaults.standard.string(forKey: "komal.selectedLanguage"),
           let lang = AppLanguage(rawValue: saved) {
            return lang.locale
        }
        return Locale(identifier: "en")
    }

    /// Thread-safe lookup-or-create in the NSCache.
    ///
    /// Although `NSCache` itself is thread-safe for individual get/set operations,
    /// the check-then-create pattern requires external synchronization to avoid
    /// redundant allocations.
    private static func cached<T: Formatter>(key: String, create: () -> T) -> T {
        let cacheKey = CacheKey(key)

        lock.lock()
        defer { lock.unlock() }

        if let box = cache.object(forKey: cacheKey), let formatter = box.formatter as? T {
            return formatter
        }

        let formatter = create()
        cache.setObject(FormatterBox(formatter), forKey: cacheKey)
        return formatter
    }
}
#endif
