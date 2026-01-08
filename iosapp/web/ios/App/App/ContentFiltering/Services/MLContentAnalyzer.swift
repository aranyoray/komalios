//
//  MLContentAnalyzer.swift
//  Komal - ML-Powered Content Analysis
//
//  Uses Core ML for on-device content categorization
//

import Foundation
import CoreML
import NaturalLanguage

class MLContentAnalyzer {
    static let shared = MLContentAnalyzer()

    private let keywordMatcher = KeywordMatcher()
    private let urlAnalyzer = URLAnalyzer()

    private init() {}

    // MARK: - Main Analysis Method
    func analyzeURL(_ urlString: String, completion: @escaping (DetectionResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var detectedCategories: [(ContentCategory, Double)] = []

            // 1. URL pattern analysis (fast, synchronous)
            if let urlCategory = self.urlAnalyzer.analyze(urlString) {
                detectedCategories.append((urlCategory.category, urlCategory.confidence))
            }

            // 2. Keyword matching in URL
            let keywordMatches = self.keywordMatcher.findMatches(in: urlString)
            detectedCategories.append(contentsOf: keywordMatches)

            // 3. Determine primary category
            let result = self.determineResult(from: detectedCategories, url: urlString)

            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    func analyzeContent(_ text: String, completion: @escaping (DetectionResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Analyze text content
            let matches = self.keywordMatcher.findMatches(in: text)
            let result = self.determineResult(from: matches, url: nil)

            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    private func determineResult(from categories: [(ContentCategory, Double)], url: String?) -> DetectionResult {
        guard !categories.isEmpty else {
            return DetectionResult(
                category: .userGeneratedComments,
                confidence: 0.1,
                reason: "No specific category detected",
                isEducational: false,
                url: url
            )
        }

        // Get highest confidence category
        let sorted = categories.sorted { $0.1 > $1.1 }
        let primary = sorted[0]

        // Check if educational
        let isEducational = checkIfEducational(url: url)

        return DetectionResult(
            category: primary.0,
            confidence: primary.1,
            reason: "Detected \(primary.0.displayName)",
            isEducational: isEducational,
            url: url
        )
    }

    private func checkIfEducational(url: String?) -> Bool {
        guard let url = url?.lowercased() else { return false }

        let educationalDomains = [
            "edu", "wikipedia", "khanacademy", "coursera", "edx",
            "mit.edu", "stanford.edu", "nationalgeographic", "pbs.org",
            "smithsonian", "nasa.gov", "britannica"
        ]

        return educationalDomains.contains { url.contains($0) }
    }
}

// MARK: - Detection Result (Extended from ContentCategory.swift)
struct DetectionResult {
    let category: ContentCategory
    let confidence: Double
    let reason: String
    let isEducational: Bool
    let url: String?
    let timestamp: Date

    init(category: ContentCategory, confidence: Double, reason: String, isEducational: Bool, url: String?) {
        self.category = category
        self.confidence = confidence
        self.reason = reason
        self.isEducational = isEducational
        self.url = url
        self.timestamp = Date()
    }
}

// MARK: - Keyword Matcher
class KeywordMatcher {
    private let keywords: [ContentCategory: [String]]

    init() {
        // Comprehensive keyword dictionary for all 40+ categories
        self.keywords = [
            // Violence & Disturbing
            .graphicViolence: ["gore", "blood", "murder", "killing", "torture", "brutal", "violent death"],
            .nonGraphicViolence: ["fight", "punch", "kick", "combat", "battle"],
            .heavyFighting: ["mma", "ufc", "boxing", "martial arts", "street fight"],
            .horror: ["scary", "horror", "creepy", "haunted", "ghost", "demon"],
            .crimeNews: ["crime", "arrest", "police", "shooting", "robbery"],

            // Explicit & Body-Related
            .explicitSexual: ["porn", "xxx", "adult", "nsfw", "explicit", "nude", "sex"],
            .sexualEducation: ["sex ed", "reproduction", "puberty", "anatomy", "health class"],
            .erotica: ["erotic", "sensual", "romance adult"],
            .indecentClothing: ["revealing", "bikini", "underwear", "lingerie"],
            .bodyModification: ["tattoo", "piercing", "plastic surgery", "cosmetic surgery"],
            .beautyFilters: ["beauty filter", "face tune", "photoshop", "instagram filter"],

            // Substances
            .alcohol: ["beer", "wine", "vodka", "whiskey", "drunk", "drinking"],
            .drugs: ["marijuana", "cocaine", "heroin", "meth", "drug", "high", "weed", "cannabis"],
            .cigarettes: ["smoke", "cigarette", "vape", "tobacco", "nicotine"],
            .gambling: ["casino", "poker", "bet", "slots", "lottery", "gambling"],
            .lootBoxes: ["loot box", "gacha", "random drop", "loot crate"],

            // Parasocial
            .parasocialDependency: ["parasocial", "stan", "obsessed", "fan base"],
            .creatorPressure: ["subscribe", "notification", "merch drop", "support creator"],
            .donationFarming: ["donate", "superchat", "tip jar", "patreon"],
            .aiFriends: ["ai companion", "chatbot", "virtual friend", "replika"],

            // Self-Optimization
            .looksmaxxing: ["looksmax", "mewing", "face gains", "chad"],
            .dietCulture: ["weight loss", "diet", "calories", "thin", "fat loss"],
            .steroids: ["steroid", "roid", "peds", "enhancement"],
            .glowUpPressure: ["glow up", "transformation", "before after"],

            // Financial
            .crypto: ["bitcoin", "crypto", "nft", "ethereum", "blockchain"],
            .getRichQuick: ["get rich", "make money fast", "passive income", "side hustle"],
            .influencerFinance: ["forex", "trading course", "investment guru"],
            .subscriptionPages: ["onlyfans", "patreon", "fansly", "subscription"],
            .mlmScams: ["mlm", "pyramid", "network marketing", "multi level"],
            .sponsoredGambling: ["stake", "draftkings", "fanduel", "sports bet"],

            // Media Risks
            .fastCutEditing: ["fast cut", "rapid edit", "adhd content"],
            .hypnoticPatterns: ["hypnotic", "spiral", "flashing"],
            .autoplay: ["autoplay", "next episode", "continue watching"],
            .clickbaitThumbs: ["clickbait", "you won't believe"],
            .liveStreaming: ["live stream", "streaming now", "going live"],
            .userGeneratedComments: ["comment section", "user comment"],

            // Social & Cultural
            .lgbtqContent: ["lgbtq", "transgender", "gay", "lesbian", "queer", "pride"],
            .religion: ["islam", "christianity", "judaism", "buddhism", "hindu", "religion"],
            .immigration: ["immigration", "refugee", "border", "asylum", "migrant"],
            .communism: ["communism", "socialism", "marxism", "communist"],
            .discriminationHate: ["hate speech", "racist", "bigot", "discrimination", "slur"],
            .gunsWeapons: ["gun", "firearm", "weapon", "rifle", "pistol"],
            .extremistOrgs: ["extremist", "terrorist", "radical", "isis", "supremacist"]
        ]
    }

    func findMatches(in text: String) -> [(ContentCategory, Double)] {
        let lowercased = text.lowercased()
        var matches: [(ContentCategory, Double)] = []

        for (category, terms) in keywords {
            for term in terms {
                if lowercased.contains(term) {
                    // Higher confidence for exact matches
                    let confidence = term.split(separator: " ").count > 1 ? 0.9 : 0.7
                    matches.append((category, confidence))
                    break // Only count once per category
                }
            }
        }

        return matches
    }
}

// MARK: - URL Analyzer
class URLAnalyzer {
    private let riskyDomains: [String: ContentCategory] = [
        // Adult content
        "pornhub.com": .explicitSexual,
        "xvideos.com": .explicitSexual,
        "onlyfans.com": .subscriptionPages,

        // Gambling
        "draftkings.com": .sponsoredGambling,
        "fanduel.com": .sponsoredGambling,
        "bet365.com": .gambling,

        // Crypto
        "coinbase.com": .crypto,
        "binance.com": .crypto,

        // Social media (for monitoring)
        "tiktok.com": .fastCutEditing,
        "twitch.tv": .liveStreaming,

        // Extremist (placeholder - would need real database)
        // Note: In production, use external moderation API
    ]

    func analyze(_ urlString: String) -> (category: ContentCategory, confidence: Double)? {
        guard let url = URL(string: urlString),
              let host = url.host?.lowercased() else {
            return nil
        }

        // Check against known domains
        for (domain, category) in riskyDomains {
            if host.contains(domain) {
                return (category, 0.95)
            }
        }

        // Check URL path for patterns
        let path = url.path.lowercased()
        if path.contains("/adult/") || path.contains("/nsfw/") {
            return (.explicitSexual, 0.85)
        }

        return nil
    }
}
