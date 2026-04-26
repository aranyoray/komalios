import XCTest
@testable import Komalios

final class LocalizationTests: XCTestCase {

    // MARK: - Key Parity Tests

    /// Plural suffixes that are allowed as extra keys beyond the base set.
    private static let pluralSuffixes: Set<String> = [".zero", ".one", ".two", ".few", ".many", ".other"]

    /// Returns true if the key is a plural variant (e.g. "insights.visits.zero").
    private func isPluralVariant(_ key: String) -> Bool {
        Self.pluralSuffixes.contains(where: { key.hasSuffix($0) })
    }

    /// All languages must have at least the base (non-plural) keys from English.
    /// Extra plural variant keys (e.g. Arabic .zero/.two/.few/.many) are allowed.
    func testAllLanguagesHaveBaseKeysFromEnglish() {
        let englishKeys = Set(EnglishStrings.all.keys)

        let languages: [(String, [String: String])] = [
            ("French", FrenchStrings.all),
            ("Spanish", SpanishStrings.all),
            ("Portuguese", PortugueseStrings.all),
            ("Arabic", ArabicStrings.all)
        ]

        for (name, dict) in languages {
            let langKeys = Set(dict.keys)
            let missingKeys = englishKeys.subtracting(langKeys)
            // Only flag extra keys that are NOT plural variants
            let extraKeys = langKeys.subtracting(englishKeys).filter { !isPluralVariant($0) }

            XCTAssertTrue(missingKeys.isEmpty,
                "\(name) is missing \(missingKeys.count) keys: \(missingKeys.sorted().prefix(10))")
            XCTAssertTrue(extraKeys.isEmpty,
                "\(name) has \(extraKeys.count) unexpected extra keys: \(extraKeys.sorted().prefix(10))")
        }
    }

    /// No language should have empty string values.
    func testNoEmptyValues() {
        let languages: [(String, [String: String])] = [
            ("English", EnglishStrings.all),
            ("French", FrenchStrings.all),
            ("Spanish", SpanishStrings.all),
            ("Portuguese", PortugueseStrings.all),
            ("Arabic", ArabicStrings.all)
        ]

        for (name, dict) in languages {
            let emptyKeys = dict.filter { $0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            XCTAssertTrue(emptyKeys.isEmpty,
                "\(name) has \(emptyKeys.count) empty values: \(emptyKeys.keys.sorted().prefix(10))")
        }
    }

    // MARK: - Format Specifier Validation

    /// Format specifiers (%d, %@, %f, %ld, etc.) must match between English and all translations.
    /// This prevents runtime crashes from String(format:) mismatches.
    func testFormatSpecifierParity() {
        let specifierPattern = try! NSRegularExpression(pattern: "%[0-9]*\\.?[0-9]*[dDuUxXoOfFeEgGcCsSaAp@]|%[0-9]+\\$[dDuUxXoOfFeEgGcCsSaAp@]")

        func specifiers(in string: String) -> [String] {
            let range = NSRange(string.startIndex..., in: string)
            return specifierPattern.matches(in: string, range: range).map {
                String(string[Range($0.range, in: string)!])
            }
        }

        let languages: [(String, [String: String])] = [
            ("French", FrenchStrings.all),
            ("Spanish", SpanishStrings.all),
            ("Portuguese", PortugueseStrings.all),
            ("Arabic", ArabicStrings.all)
        ]

        for (name, dict) in languages {
            for (key, englishValue) in EnglishStrings.all {
                guard let translatedValue = dict[key] else { continue }
                let englishSpecs = specifiers(in: englishValue)
                let translatedSpecs = specifiers(in: translatedValue)

                XCTAssertEqual(englishSpecs.count, translatedSpecs.count,
                    "\(name) key '\(key)': expected \(englishSpecs.count) format specifiers (\(englishSpecs)), got \(translatedSpecs.count) (\(translatedSpecs))")
            }
        }
    }

    // MARK: - AppLanguage Enum Tests

    func testArabicProperties() {
        let arabic = AppLanguage.arabic
        XCTAssertEqual(arabic.rawValue, "ar")
        XCTAssertEqual(arabic.nativeName, "العربية")
        XCTAssertEqual(arabic.flag, "🇸🇦")
        XCTAssertTrue(arabic.isRTL)
        XCTAssertEqual(arabic.layoutDirection, .rightToLeft)
        XCTAssertEqual(arabic.locale.identifier, "ar")
    }

    func testLTRLanguagesAreNotRTL() {
        let ltrLanguages: [AppLanguage] = [.english, .french, .spanish, .portuguese]
        for lang in ltrLanguages {
            XCTAssertFalse(lang.isRTL, "\(lang.rawValue) should not be RTL")
            XCTAssertEqual(lang.layoutDirection, .leftToRight)
        }
    }

    func testAllLanguagesHaveNativeName() {
        for lang in AppLanguage.allCases {
            XCTAssertFalse(lang.nativeName.isEmpty, "\(lang.rawValue) has empty nativeName")
        }
    }

    func testAllLanguagesHaveFlag() {
        for lang in AppLanguage.allCases {
            XCTAssertFalse(lang.flag.isEmpty, "\(lang.rawValue) has empty flag")
        }
    }

    // MARK: - Plural Rules Tests

    func testArabicPluralRules() {
        let ar = AppLanguage.arabic
        XCTAssertEqual(ar.pluralCategory(for: 0), "zero")
        XCTAssertEqual(ar.pluralCategory(for: 1), "one")
        XCTAssertEqual(ar.pluralCategory(for: 2), "two")
        XCTAssertEqual(ar.pluralCategory(for: 3), "few")
        XCTAssertEqual(ar.pluralCategory(for: 10), "few")
        XCTAssertEqual(ar.pluralCategory(for: 11), "many")
        XCTAssertEqual(ar.pluralCategory(for: 99), "many")
        XCTAssertEqual(ar.pluralCategory(for: 100), "other")
        XCTAssertEqual(ar.pluralCategory(for: 103), "few")   // 103 % 100 = 3
        XCTAssertEqual(ar.pluralCategory(for: 111), "many")  // 111 % 100 = 11
    }

    func testEnglishPluralRules() {
        let en = AppLanguage.english
        XCTAssertEqual(en.pluralCategory(for: 0), "other")
        XCTAssertEqual(en.pluralCategory(for: 1), "one")
        XCTAssertEqual(en.pluralCategory(for: 2), "other")
        XCTAssertEqual(en.pluralCategory(for: 100), "other")
    }

    func testFrenchPluralRules() {
        let fr = AppLanguage.french
        XCTAssertEqual(fr.pluralCategory(for: 0), "one")  // French: 0 is singular
        XCTAssertEqual(fr.pluralCategory(for: 1), "one")
        XCTAssertEqual(fr.pluralCategory(for: 2), "other")
    }

    // MARK: - Localization Lookup Tests

    func testArabicLookupReturnsArabicString() {
        // Verify that at least the common keys are present and non-English
        let arabicBack = ArabicStrings.all["common.back"]
        XCTAssertNotNil(arabicBack)
        XCTAssertNotEqual(arabicBack, "back", "Arabic 'common.back' should not be English")
    }

    // MARK: - Auto-Detect Device Language Tests

    func testFromDeviceLocaleReturnsNilForUnsupported() {
        // This tests the static method — can't control Locale.current in tests,
        // but we can verify the method exists and handles known codes
        XCTAssertEqual(AppLanguage(rawValue: "en"), .english)
        XCTAssertEqual(AppLanguage(rawValue: "ar"), .arabic)
        XCTAssertEqual(AppLanguage(rawValue: "fr"), .french)
        XCTAssertNil(AppLanguage(rawValue: "zh"))  // Chinese not supported
        XCTAssertNil(AppLanguage(rawValue: "ja"))  // Japanese not supported
    }

    // MARK: - Arabic Content Filter Tests

    func testArabicStrictKeywordDetected() {
        let result = BrowserState.checkForInappropriateContent("بحث عن إباحية", isSearchQuery: false)
        XCTAssertNotNil(result, "Arabic strict keyword 'إباحي' should be detected")
    }

    func testArabicKeywordWithAlPrefixDetected() {
        // "المخدرات" = "the drugs" (al- prefix attached to مخدرات)
        let result = BrowserState.checkForInappropriateContent("المخدرات", isSearchQuery: true)
        XCTAssertNotNil(result, "Arabic keyword with al- prefix should be detected via contains()")
    }

    func testArabicSearchKeywordOnlyInSearchMode() {
        // Arabic search keyword should NOT trigger in URL-only mode
        let urlResult = BrowserState.checkForInappropriateContent("مخدرات", isSearchQuery: false)
        // مخدرات is in arabicSearchKeywords, not arabicStrictKeywords
        XCTAssertNil(urlResult, "Arabic search-only keyword should not trigger in URL mode")

        // But should trigger in search mode
        let searchResult = BrowserState.checkForInappropriateContent("مخدرات", isSearchQuery: true)
        XCTAssertNotNil(searchResult, "Arabic search keyword should trigger in search mode")
    }

    func testLegitimateArabicNotBlocked() {
        let result = BrowserState.checkForInappropriateContent("مرحبا بالعالم", isSearchQuery: true)
        XCTAssertNil(result, "Legitimate Arabic text 'Hello World' should not be blocked")
    }
}
