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
    @Published var urlString = "https://www.khanacademy.org"
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
    static let inappropriateKeywords: Set<String> = [
        // Sexual/Adult content
        "porn", "pornhub", "xvideos", "xxx", "sex", "nude", "naked", "boobs", "tits", "ass",
        "pussy", "dick", "penis", "vagina", "breast", "nsfw", "onlyfans", "hentai", "erotic",
        "milf", "lesbian", "gay porn", "anal", "blowjob", "handjob", "orgasm", "masturbat",
        "stripper", "prostitut", "escort", "hooker", "sexy", "horny", "slut", "whore",
        "bikini model", "lingerie", "playboy", "penthouse", "brazzers", "xnxx", "redtube",
        
        // Violence/Gore
        "gore", "murder", "kill", "death", "suicide", "self harm", "cutting", "blood",
        "torture", "brutal", "violent", "massacre", "shooting", "stab", "decapitat",
        "execution", "beheading", "dismember", "mutilat",
        
        // Drugs/Substances
        "weed", "marijuana", "cannabis", "cocaine", "heroin", "meth", "drug", "lsd",
        "ecstasy", "mdma", "crack", "opioid", "fentanyl", "ketamine", "shrooms",
        "mushrooms", "acid", "molly", "xanax", "adderall", "vape", "juul", "smoking",
        "alcohol", "beer", "vodka", "whiskey", "drunk", "hangover",
        
        // Weapons
        "gun", "rifle", "pistol", "weapon", "bomb", "explosive", "grenade", "knife attack",
        "assault rifle", "ammunition", "firearm", "ak47", "ar15", "shooting range",
        
        // Gambling
        "gambling", "casino", "poker", "slots", "betting", "bet365", "draftkings",
        "fanduel", "sportsbet", "blackjack", "roulette",
        
        // Hate/Extremism  
        "nazi", "kkk", "white supremac", "racist", "terrorism", "isis", "al qaeda",
        "extremist", "hate speech", "antisemit",
        
        // Eating disorders/Self-harm
        "anorexia", "bulimia", "pro ana", "thinspo", "cutting", "self injury",
        
        // Cyberbullying/Harmful
        "cyberbully", "doxxing", "swatting", "harassment"
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
        
        // YouTube
        if host.contains("youtube") {
            return queryItems.first(where: { $0.name == "search_query" })?.value
        }
        
        return nil
    }
    
    // MARK: - Content Checking
    static func checkForInappropriateContent(_ text: String) -> String? {
        let lowercased = text.lowercased()
        
        for keyword in inappropriateKeywords {
            if lowercased.contains(keyword) {
                return keyword
            }
        }
        return nil
    }
    
    static func checkURL(_ url: URL, parentSettings: ParentSettings) -> (shouldIntervene: Bool, trigger: KomalInterventionTrigger?) {
        let urlString = url.absoluteString.lowercased()
        
        // Check search queries first
        if let searchQuery = extractSearchQuery(from: url) {
            if let flaggedKeyword = checkForInappropriateContent(searchQuery) {
                return (true, .searchQuery(flaggedKeyword))
            }
            
            // Check parent's custom blocked keywords in search
            for keyword in parentSettings.blockedKeywords {
                if searchQuery.lowercased().contains(keyword.lowercased()) {
                    return (true, .searchQuery(keyword))
                }
            }
        }
        
        // Check URL itself
        if let flaggedKeyword = checkForInappropriateContent(urlString) {
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
        
        // Check parent's blocked keywords in URL
        for keyword in parentSettings.blockedKeywords {
            if urlString.contains(keyword.lowercased()) {
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
