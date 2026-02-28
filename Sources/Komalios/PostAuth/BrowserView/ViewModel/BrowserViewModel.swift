//
//  BrowserViewModel.swift
//  Komalios
//
//  Created by Amit Kumar on 18/01/26.
//
import Combine
import Foundation
 
/// Type of content trigger for Komal intervention
enum KomalInterventionTrigger: Equatable {
    case searchQuery(String)           // They searched for something
    case urlKeyword(String)            // URL contains keyword
    case imageContent(String)          // Image was flagged
    case pageContent(String)           // Page content was flagged
    
    var searchTerm: String {
        switch self {
        case .searchQuery(let term): return term
        case .urlKeyword(let keyword): return keyword
        case .imageContent(let category): return category
        case .pageContent(let content): return content
        }
    }
    
    var isSearchRelated: Bool {
        switch self {
        case .searchQuery, .urlKeyword: return true
        default: return false
        }
    }
}

@MainActor
final class BrowserState: ObservableObject {
    @Published var tabHistory: [URL] = []
    
    // MARK: - Comprehensive Inappropriate Keywords
    // These are strict keywords - block even as part of domains/URLs
    static let strictKeywords: Set<String> = [
        // Explicit adult sites & platforms
        "pornhub", "xvideos", "xnxx", "redtube", "brazzers", "onlyfans", "hentai",
        "xhamster", "youporn", "tube8", "spankbang", "chaturbate", "livejasmin",
        "stripchat", "bongacams", "cam4", "myfreecams", "flirt4free",
        "realitykings", "bangbros", "naughtyamerica", "mofos", "fakehub",
        "blacked", "tushy", "vixen", "deeper", "sexart", "metart",
        "manyvids", "clips4sale", "fansly", "justforfans", "porntrex",
        "eporner", "tnaflix", "motherless", "xtube", "porntube",
        "4chan", "8chan", "8kun", "theync", "bestgore", "efukt",

        // Explicit terms (unlikely in legitimate URLs)
        "xxx", "nsfw", "milf", "blowjob", "handjob", "orgasm",
        "stripper", "hooker", "slut", "whore",
        "cuckold", "creampie", "gangbang", "threesome", "foursome",
        "deepthroat", "cumshot", "facial cum", "bukkake", "squirt",
        "dildo", "vibrator", "fleshlight", "buttplug", "cockring",
        "camgirl", "camboy", "webcam sex", "sexcam", "livesex",
        "stepmom", "stepdad", "stepsister", "stepbrother", "stepson", "stepdaughter",
        "incest", "taboo sex", "jailbait",
        "dominatrix", "femdom", "findom", "shibari",
        "ahegao", "futanari", "lolicon", "shotacon", "rule34",
        "doujinshi", "nhentai", "hanime", "hentaihaven",
        "fap", "fapping", "jackoff", "jerkoff", "wank",
        "sexting", "dickpic", "nympho", "gigolo",
        "swinger", "hotwife", "cuck",
        "asshole", "anus", "anal", "analsex",
        "porno",

        // Violence extremes
        "beheading", "gore", "snuff",
        "livegore", "deathvideo", "watchpeopledie",

        // Hate groups
        "nazi", "kkk", "neonazi", "neo-nazi",

        // Child exploitation (instant block)
        "childporn", "kidporn", "pedo", "preteen",
        "csam", "child exploitation", "child abuse",
        "child trafficking", "child grooming"
    ]

    /// Prefix keywords checked against both URLs and search queries.
    /// Uses leading word-boundary only (\bkeyword) to catch all suffixed forms.
    static let strictPrefixKeywords: Set<String> = [
        // Explicit content
        "prostitut", "pornog", "masturbat",

        // Violence
        "decapitat", "dismember",

        // Hate groups
        "white supremac",

        // Child exploitation
        "pedophil", "childexploit", "childtraffick"
    ]

    // These keywords only trigger on search queries (not URLs)
    // because they can appear in legitimate URLs
    static let searchOnlyKeywords: Set<String> = [
        // Sexual / Adult content - core terms
        "porn", "pornography", "pornographic",
        "sex", "sexual", "sexually", "sex video", "sex tape",
        "nude", "nudes", "nudity", "naked", "topless", "bottomless",
        "adult content", "adult video", "adult film", "adult movie",
        "boobs", "tits", "titties", "pussy", "dick", "penis", "vagina",
        "clitoris", "scrotum", "testicle", "genital", "genitals",
        "breast", "nipple", "areola",
        "erotic", "erotica", "sexy", "horny", "aroused", "arousal",
        "fetish", "kink", "kinky", "bdsm", "bondage", "sadomasochism",
        "escort", "cam girl", "cam boy", "sugar daddy", "sugar baby",
        "r rated", "x rated", "18+", "adults only",
        "intercourse", "copulation", "fornication",
        "lap dance", "pole dance", "striptease", "strip club",
        "lingerie model", "playboy", "playmate", "centerfold",
        "upskirt", "downblouse", "voyeur",
        "grope", "groping",
        "one night stand", "booty call", "hookup sex", "friends with benefits",
        "hot girls", "hot babes", "sexy girls", "sexy women",
        "hot pics", "hot photos", "hot pictures", "hot images", "hot videos",
        "hot models", "hot actress", "hot body",
        "sexy pics", "sexy photos", "sexy pictures", "sexy images", "sexy videos",
        "leaked photos", "leaked pics", "leaked pictures", "leaked video", "leaked videos",
        "leaked nudes", "leaked images",
        "nip slip", "wardrobe malfunction",
        "see through dress", "see through clothes",
        "no clothes", "without clothes", "unclothed",
        "dirty talk", "phone sex", "cybersex",
        "viagra", "cialis", "erectile", "libido",
        "sensual massage", "happy ending", "body rub",
        "call girl", "brothel", "red light district",
        "explicit content", "explicit video", "explicit image",

        // Violence terms
        "self harm", "self-harm",
        "violence", "violent", "kill", "killing",
        "weapon", "weapons", "gun", "guns",
        "how to make a bomb", "how to kill", "how to poison",
        "mass shooting", "school shooting",
        "cutting myself", "want to die", "end my life",
        "stab", "stabbing", "assault",
        "terrorism", "terrorist",

        // Drug terms
        "weed", "marijuana", "cannabis", "cocaine", "heroin", "meth",
        "drug", "drugs", "mdma", "ecstasy", "lsd", "acid trip",
        "fentanyl", "opioid", "crack cocaine", "ketamine",
        "buy drugs", "drug dealer",

        // Gambling
        "gambling", "casino", "poker", "betting",
        "slot machine", "sports betting", "online gambling",

        // Profanity / slurs (commonly searched by kids)
        "fuck", "fucking", "fucker",
        "shit", "bullshit",
        "bitch", "bastard", "cunt",
        "ass", "asses",
        "damn", "damnit",
        "cock",
        "racial slur", "n word",

        // Hate groups
        "hate group", "hate groups",
        "neo nazi", "white power", "aryan"
    ]

    /// Prefix keywords checked only in search queries.
    /// Uses leading word-boundary only to catch all suffixed forms.
    static let searchOnlyPrefixKeywords: Set<String> = [
        "sexualiz", "objectif",
        "motherfuck", "cocksuck", "molest",
        "murder", "suicid", "tortur",
        "antisemit"
    ]
    
    // MARK: - Search Query Extraction
    static func extractSearchQuery(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else { return nil }
        
        let host = url.host?.lowercased() ?? ""
        
        // Google
        if host.contains("google") {
            return queryItems.first(where: { $0.name == "q" })?.value
        }
        
        // Bing
        if host.contains("bing") {
            return queryItems.first(where: { $0.name == "q" })?.value
        }
        
        // Yahoo
        if host.contains("yahoo") {
            return queryItems.first(where: { $0.name == "p" })?.value
        }
        
        // DuckDuckGo
        if host.contains("duckduckgo") {
            return queryItems.first(where: { $0.name == "q" })?.value
        }

        return nil
    }
    
    // MARK: - Content Checking with Word Boundaries
    
    /// Check if text contains inappropriate content as a whole word
    /// Uses word boundary matching to avoid false positives (e.g., "class" matching "ass")
    static func checkForInappropriateContent(_ text: String, isSearchQuery: Bool = true) -> String? {
        let lowercased = text.lowercased()

        // Always check strict keywords (site names, explicit terms)
        for keyword in strictKeywords {
            if matchesAsWord(keyword, in: lowercased) {
                return keyword
            }
        }

        // Always check strict prefix keywords
        for keyword in strictPrefixKeywords {
            if matchesAsPrefix(keyword, in: lowercased) {
                return keyword
            }
        }

        // Only check search-only keywords if this is a search query
        if isSearchQuery {
            for keyword in searchOnlyKeywords {
                if matchesAsWord(keyword, in: lowercased) {
                    return keyword
                }
            }
            for keyword in searchOnlyPrefixKeywords {
                if matchesAsPrefix(keyword, in: lowercased) {
                    return keyword
                }
            }
        }

        return nil
    }

    /// Check if keyword appears as a word (not part of another word)
    private static func matchesAsWord(_ keyword: String, in text: String) -> Bool {
        // Use regex with word boundaries
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: keyword))\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            // Fail closed: if regex can't be created, treat as match (block)
            return true
        }

        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }

    /// Check if keyword appears as a prefix (word boundary at start only).
    /// Catches all suffixed forms, e.g. "pedophil" matches "pedophile", "pedophilia".
    private static func matchesAsPrefix(_ keyword: String, in text: String) -> Bool {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: keyword))"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return true // fail closed
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
    
    static func checkURL(_ url: URL, parentSettings: ParentSettings) -> (shouldIntervene: Bool, trigger: KomalInterventionTrigger?) {
        // Check search queries first (use full keyword list)
        if let searchQuery = extractSearchQuery(from: url) {
            if let flaggedKeyword = checkForInappropriateContent(searchQuery, isSearchQuery: true) {
                return (true, .searchQuery(flaggedKeyword))
            }
            
            // Check parent's custom blocked keywords in search
            for keyword in parentSettings.blockedKeywords {
                if matchesAsWord(keyword.lowercased(), in: searchQuery.lowercased()) {
                    return (true, .searchQuery(keyword))
                }
            }
        }
        
        // Check URL itself (only strict keywords to avoid false positives)
        let urlString = url.absoluteString.lowercased()
        if let flaggedKeyword = checkForInappropriateContent(urlString, isSearchQuery: false) {
            return (true, .urlKeyword(flaggedKeyword))
        }
        
        // Check parent's blocked hosts
        if let host = url.host?.lowercased() {
            for blockedHost in parentSettings.blockedHosts {
                if host.contains(blockedHost.lowercased()) {
                    return (true, .urlKeyword(blockedHost))
                }
            }
        }
        
        // Check parent's blocked keywords in URL (word boundary)
        for keyword in parentSettings.blockedKeywords {
            if matchesAsWord(keyword.lowercased(), in: urlString) {
                return (true, .urlKeyword(keyword))
            }
        }
        
        return (false, nil)
    }

    /// Returns true if the keyword is in the strictKeywords set (explicit sites, child exploitation, self-harm).
    /// Used to decide between hard-blocking (strict) vs letting Gemini redirect naturally (softer terms).
    static func isStrictKeyword(_ keyword: String) -> Bool {
        let lowered = keyword.lowercased()
        return strictKeywords.contains(lowered) || strictPrefixKeywords.contains(where: { lowered.hasPrefix($0) })
    }

    // MARK: - Child Exploitation Detection (safety-critical hard-block subset)

    private static let childExploitationKeywords: Set<String> = [
        "childporn", "kidporn", "pedo", "preteen", "csam",
        "child exploitation", "child abuse", "child trafficking", "child grooming",
        "jailbait", "lolicon", "shotacon"
    ]

    private static let childExploitationPrefixes: Set<String> = [
        "pedophil", "childexploit", "childtraffick"
    ]

    /// Returns true only for child exploitation keywords — the safety-critical subset
    /// that must always be hard-blocked (no Gemini routing).
    static func isChildExploitationKeyword(_ keyword: String) -> Bool {
        let lowered = keyword.lowercased()
        return childExploitationKeywords.contains(lowered) ||
            childExploitationPrefixes.contains(where: { lowered.hasPrefix($0) })
    }

    // MARK: - Pre-compiled Word Filter Regexes (shared cache)

    /// Pre-compiled regex patterns for all inappropriate keywords. Used by ChatWordFilter
    /// and AudioPlaybackManager to censor words for display and TTS without re-compiling per call.
    static let wordFilterRegexes: [NSRegularExpression] = {
        var regexes: [NSRegularExpression] = []
        let allKeywords = strictKeywords.union(searchOnlyKeywords)
        for keyword in allKeywords {
            let pattern = "(?i)\\b\(NSRegularExpression.escapedPattern(for: keyword))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                regexes.append(regex)
            }
        }
        let allPrefixes = strictPrefixKeywords.union(searchOnlyPrefixKeywords)
        for prefix in allPrefixes {
            let pattern = "(?i)\\b\(NSRegularExpression.escapedPattern(for: prefix))\\w*"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                regexes.append(regex)
            }
        }
        return regexes
    }()

    /// Censor inappropriate words for display (replaces with "...").
    static func censorForDisplay(_ text: String) -> String {
        var result = text
        for regex in wordFilterRegexes {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "...")
        }
        return result
    }

    /// Strip inappropriate words for TTS (replaces with empty string for silence).
    static func stripForTTS(_ text: String) -> String {
        var result = text
        for regex in wordFilterRegexes {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func addToHistory(_ url: URL) {
        if !tabHistory.contains(url) {
            tabHistory.insert(url, at: 0)
            if tabHistory.count > 20 {
                tabHistory.removeLast()
            }
        }
    }
    
}
