//
//  Constants.swift
//  Komalios
//
//  Created by Amit Kumar on 18/01/26.
//

import Foundation

struct Constants {

    // MARK: - REST API Constants
    struct ApiEndpoint {
        static var baseURL: String {
            return "https://www.komalkids.com/"
        }
    }

    // MARK: - Domain Lists (shared across ViewModel & WebView)

    /// Kid-friendly domains that skip content scanning
    static let trustedDomains: Set<String> = [
        "google.com", "www.google.com",
        "khanacademy.org", "www.khanacademy.org",
        "pbskids.org", "www.pbskids.org",
        "nationalgeographic.com", "www.nationalgeographic.com", "kids.nationalgeographic.com",
        "brainpop.com", "www.brainpop.com",
        "coolmathgames.com", "www.coolmathgames.com",
        "funbrain.com", "www.funbrain.com",
        "starfall.com", "www.starfall.com",
        "abcya.com", "www.abcya.com",
        "seussville.com", "www.seussville.com",
        "scholastic.com", "www.scholastic.com",
        "duckduckgo.com", "www.duckduckgo.com",
        "wikipedia.org", "www.wikipedia.org", "en.wikipedia.org",
        "nasa.gov", "www.nasa.gov",
        "weather.com", "www.weather.com",
        "timeanddate.com", "www.timeanddate.com",
        "mathway.com", "www.mathway.com",
        "duolingo.com", "www.duolingo.com",
        "scratch.mit.edu",
        "code.org", "www.code.org",
        "typing.com", "www.typing.com",
        "apple.com", "www.apple.com",
        "disney.com", "www.disney.com",
        "commonsensemedia.org", "www.commonsensemedia.org",
        "kiddle.co", "www.kiddle.co"
    ]

    /// Root domains (no www. prefix) for JavaScript injection.
    /// EngagementTracker injects this into pre-hide CSS and JS scripts
    /// so they can skip scanning on trusted domains.
    static var trustedDomainRootsJSON: String {
        let roots = Set(trustedDomains.map { domain -> String in
            domain.hasPrefix("www.") ? String(domain.dropFirst(4)) : domain
        })
        let sorted = roots.sorted()
        let jsonArray = sorted.map { "'\($0)'" }.joined(separator: ",")
        return "[\(jsonArray)]"
    }

    /// Platforms blocked for child safety
    static let blockedPlatforms: Set<String> = [
        "tiktok.com", "www.tiktok.com",
        "instagram.com", "www.instagram.com",
        "twitter.com", "www.twitter.com", "x.com", "www.x.com",
        "facebook.com", "www.facebook.com", "m.facebook.com",
        "reddit.com", "www.reddit.com", "old.reddit.com",
        "snapchat.com", "www.snapchat.com",
        "discord.com", "www.discord.com",
        "twitch.tv", "www.twitch.tv",
        "youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be", "www.youtu.be",
        "youtubei.googleapis.com"
    ]

    /// Check if a URL host is a trusted kid-friendly domain
    static func isTrustedDomain(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        if trustedDomains.contains(host) { return true }
        // Only do subdomain matching for root domains (those with exactly one dot like "google.com")
        for trustedDomain in trustedDomains where trustedDomain.components(separatedBy: ".").count == 2 {
            if host.hasSuffix(".\(trustedDomain)") { return true }
        }
        return false
    }

    /// Check if a URL host is a blocked platform (exact match + subdomain matching)
    static func isBlockedPlatform(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        if blockedPlatforms.contains(host) { return true }
        // Only do subdomain matching for root domains (those with exactly one dot like "google.com")
        for blockedDomain in blockedPlatforms where blockedDomain.components(separatedBy: ".").count == 2 {
            if host.hasSuffix(".\(blockedDomain)") { return true }
        }
        return false
    }
}
