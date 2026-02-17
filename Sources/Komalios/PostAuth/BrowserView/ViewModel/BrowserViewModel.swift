//
//  BrowserViewModel.swift
//  Komalios
//
//  Created by Amit Kumar on 18/01/26.
//
import Combine
import Foundation

enum BrowserHandleState {
    case notRunning
    case loading
    case success
    case failure(String)
}

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

final class BrowserState: ObservableObject {
    @Published var urlString = "https://www.google.com"
    @Published var currentURL: URL?
    @Published var category: ContentCategory = .unknown
    @Published var blockReason: String = ""
    @Published var showGate = false
    @Published var showBlocked = false
    @Published var loading = false
    @Published var tabHistory: [URL] = []
    @Published var showPastTabs = false
    @Published var browserHandleState: BrowserHandleState = .notRunning
    
    // MARK: - Komal Intervention System
    @Published var showKomalIntervention = false
    @Published var interventionTrigger: KomalInterventionTrigger?
    @Published var pendingURL: URL?  // URL that triggered intervention
    
    // MARK: - Comprehensive Inappropriate Keywords
    // These are strict keywords - block even as part of domains/URLs
    static let strictKeywords: Set<String> = [
        // Explicit adult sites
        "pornhub", "xvideos", "xnxx", "redtube", "brazzers", "onlyfans", "hentai",
        "xhamster", "youporn", "tube8", "spankbang", "chaturbate",

        // Explicit terms (unlikely in legitimate URLs)
        "xxx", "nsfw", "milf", "blowjob", "handjob", "orgasm",
        "stripper", "prostitut", "hooker", "slut", "whore",

        // Violence extremes
        "beheading", "dismember", "decapitat", "gore",

        // Hate groups
        "nazi", "kkk", "white supremac"
    ]

    // These keywords only trigger on search queries (not URLs)
    // because they can appear in legitimate URLs
    static let searchOnlyKeywords: Set<String> = [
        // Sexual / Adult content
        "porn", "pornography", "pornographic",
        "sex", "sexual", "sexually",
        "nude", "nudes", "nudity", "naked",
        "adult content", "adult video", "adult film",
        "boobs", "tits", "pussy", "dick", "penis", "vagina",
        "erotic", "erotica", "sexy", "horny",
        "fetish", "kink", "bdsm", "bondage",
        "escort", "cam girl", "cam boy",
        "r rated", "x rated", "18+",

        // Violence terms
        "murder", "suicide", "self harm", "torture",
        "violence", "violent", "kill", "killing",
        "weapon", "weapons", "gun", "guns",

        // Drug terms
        "weed", "marijuana", "cannabis", "cocaine", "heroin", "meth",
        "drug", "drugs",

        // Gambling
        "gambling", "casino", "poker", "betting"
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
        
        // Only check search-only keywords if this is a search query
        if isSearchQuery {
            for keyword in searchOnlyKeywords {
                if matchesAsWord(keyword, in: lowercased) {
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
            // Fallback to simple contains if regex fails
            return text.contains(keyword)
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

    func addToHistory(_ url: URL) {
        if !tabHistory.contains(url) {
            tabHistory.insert(url, at: 0)
            if tabHistory.count > 20 {
                tabHistory.removeLast()
            }
        }
    }
    
    func triggerIntervention(for trigger: KomalInterventionTrigger, pendingURL: URL?) {
        self.interventionTrigger = trigger
        self.pendingURL = pendingURL
        self.showKomalIntervention = true
    }
    
    func clearIntervention() {
        showKomalIntervention = false
        interventionTrigger = nil
        pendingURL = nil
    }
}
