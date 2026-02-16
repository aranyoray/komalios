//
//  KomalSafetyScannerViewModel.swift
//  Komalios
//
//  Created on 18/01/26.
//

import Foundation
import Combine

#if canImport(SwiftUI)
import SwiftUI
#endif

@MainActor
final class KomalSafetyScannerViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var urlInput: String = "google.com"
    @Published var currentURL: URL? = URL(string: "https://www.google.com")
    @Published var pendingURL: URL?
    @Published var showGate = false
    @Published var showBlocked = false
    @Published var showKomalCheckIn = false
    @Published var showKomalIntervention = false  // NEW: Caring intervention
    @Published var interventionTrigger: KomalInterventionTrigger?  // NEW: What triggered it
    @Published var category: ContentCategory = .unknown
    @Published var blockReason: String = ""
    @Published var loading = false
    @Published var scanResult: ScanResponse?
    @Published var error: Error?
    
    // MARK: - Dependencies
    private let networkService = ScanNetworkService()
    private let historyService = BrowsingHistoryService.shared
    private let contentAnalysisService = ContentAnalysisService.shared
    private let appHistoryService = AppHistoryService.shared
    var appState: AppState

    // MARK: - Emoji Check-In State
    @Published var pagesLoadedSinceLastEmoji: Int = 0
    @Published var showEmojiCheckIn = false
    @Published var showBlockedEmojiPopup = false
    @Published var currentSubcategory: String = ""
    @Published var lastLoggedDocumentId: String?
    @Published var gateAvatarIndex: Int = Int.random(in: 1...11)
    private var lastSafeURL: URL?
    
    // MARK: - Unified Decision (new system)
    @Published var unifiedDecision: UnifiedDecisionResponse?
    
    // MARK: - Known Kid-Friendly Sites (skip scanning)
    private let trustedDomains: Set<String> = [
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
        "typing.com", "www.typing.com"
    ]
    
    // MARK: - Blocked Platforms (not appropriate for children)
    private let blockedPlatforms: Set<String> = [
        "youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be",
        "tiktok.com", "www.tiktok.com",
        "instagram.com", "www.instagram.com",
        "twitter.com", "www.twitter.com", "x.com", "www.x.com",
        "facebook.com", "www.facebook.com", "m.facebook.com",
        "reddit.com", "www.reddit.com", "old.reddit.com",
        "snapchat.com", "www.snapchat.com",
        "discord.com", "www.discord.com",
        "twitch.tv", "www.twitch.tv"
    ]

    private func isBlockedPlatform(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return blockedPlatforms.contains(host)
    }

    // MARK: - Search Tracking
    private var searchCount: Int = 0
    private var nextCheckInAt: Int = 0 // Dynamic check-in interval (3-4 searches)
    
    private func updateNextCheckIn() {
        // Randomize between 3 and 4 searches for natural feel
        nextCheckInAt = searchCount + Int.random(in: 3...4)
    }
    
    // MARK: - Initialization
    init(appState: AppState) {
        self.appState = appState
    }
    
    /// Update appState reference (called from view onAppear)
    func updateAppState(_ appState: AppState) {
        self.appState = appState
    }
    
    // MARK: - Public Methods
    
    /// Handle URL submission - scans URL and determines action
    func handleUrlSubmit() async {
        guard !urlInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        debugLogLine("[DEBUG-SCAN] Starting URL scan for: \(urlInput)")
        
        // DIGITAL GUARDIAN: Check raw input FIRST before ANY processing
        // Only check as search query if it doesn't look like a URL
        let trimmedInput = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let looksLikeURL = trimmedInput.contains(".") && !trimmedInput.contains(" ")
        
        // For search-like input, check with full keyword list
        // For URL-like input, only check strict keywords (avoid false positives)
        if let flaggedKeyword = BrowserState.checkForInappropriateContent(trimmedInput, isSearchQuery: !looksLikeURL) {
            debugLogLine("[DEBUG-SCAN] RAW INPUT FLAGGED: \(flaggedKeyword)")

            // Reset ALL states first to dismiss any stale fullScreenCovers
            resetStates()
            self.currentURL = nil  // Ensure no URL loads
            self.interventionTrigger = looksLikeURL ? .urlKeyword(flaggedKeyword) : .searchQuery(flaggedKeyword)
            self.showKomalIntervention = true
            self.loading = false
            
            // Log for local + Firebase history
            historyService.logBlocked(
                url: URL(string: "blocked://\(urlInput)") ?? URL(string: "about:blank")!,
                category: "Content Filter",
                reason: "Searched for: \(flaggedKeyword)"
            )
            Task {
                await appHistoryService.logEvent(
                    url: trimmedInput,
                    searchQuery: trimmedInput,
                    action: "BLOCK",
                    category: "Content Filter",
                    subcategory: flaggedKeyword,
                    childName: appState.activeProfile.name,
                    ageGroup: appState.activeProfile.ageGroup.rawValue
                )
            }
            return
        }
        
        // Reset states only after passing initial content check
        resetStates()
        loading = true
        
        // Increment search count
        searchCount += 1
        
        // Initialize next check-in on first search
        if nextCheckInAt == 0 {
            updateNextCheckIn()
        }
        
        // Check if it's time for Komal check-in
        let shouldCheckIn = searchCount >= nextCheckInAt
        
        // Normalize URL
        let normalizedURL = normalizeURL(urlInput)
        debugLogLine("[DEBUG-SCAN] Normalized URL: \(normalizedURL)")
        
        // Secondary check on the normalized URL
        if let url = URL(string: normalizedURL) {
            // Check URL for inappropriate content
            let contentCheck = BrowserState.checkURL(url, parentSettings: appState.parentSettings)
            if contentCheck.shouldIntervene, let trigger = contentCheck.trigger {
                debugLogLine("[DEBUG-SCAN] URL content check triggered: \(trigger.searchTerm)")
                historyService.logBlocked(url: url, category: "Content Filter", reason: "Intervention: \(trigger.searchTerm)")
                Task {
                    await appHistoryService.logEvent(
                        url: normalizedURL,
                        searchQuery: urlInput,
                        action: "BLOCK",
                        category: "Content Filter",
                        subcategory: trigger.searchTerm,
                        childName: appState.activeProfile.name,
                        ageGroup: appState.activeProfile.ageGroup.rawValue
                    )
                }

                // Reset all states to prevent competing fullScreenCovers
                showGate = false
                showBlocked = false
                showKomalCheckIn = false
                self.currentURL = nil
                self.interventionTrigger = trigger
                self.showKomalIntervention = true
                self.loading = false
                return
            }
            
            // Log typed URL event for history tracking
            historyService.logTypedURL(url: url)
        }
        
        // Block social media and video platforms
        if let url = URL(string: normalizedURL), isBlockedPlatform(url) {
            let host = url.host ?? "unknown"
            debugLogLine("[DEBUG-SCAN] Blocked platform: \(host)")
            historyService.logBlocked(url: url, category: "Platform Block", reason: "Blocked platform: \(host)")

            // Log to Firebase
            Task {
                await appHistoryService.logEvent(
                    url: normalizedURL,
                    action: "BLOCK",
                    category: "Platform Block",
                    subcategory: host,
                    childName: appState.activeProfile.name,
                    ageGroup: appState.activeProfile.ageGroup.rawValue
                )
            }

            self.currentURL = nil
            self.interventionTrigger = .urlKeyword(host)
            self.showKomalIntervention = true
            self.loading = false
            return
        }

        // Check if this is a trusted kid-friendly domain (skip scanning)
        // Only skip for direct URL inputs, NOT for search queries converted to Google URLs
        if looksLikeURL, let url = URL(string: normalizedURL), isTrustedDomain(url) {
            debugLogLine("[DEBUG-SCAN] Trusted domain (direct URL) - skipping scan: \(url.host ?? "")")
            lastSafeURL = url
            currentURL = url
            historyService.logEvent(url: url, type: .allowed, category: "Trusted Site", action: .allow)
            loading = false

            // Log to Firebase
            Task {
                await appHistoryService.logEvent(
                    url: normalizedURL,
                    action: "ALLOW",
                    category: "Trusted Site",
                    childName: appState.activeProfile.name,
                    ageGroup: appState.activeProfile.ageGroup.rawValue
                )
            }

            // Still show check-in if it's time
            if shouldCheckIn {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.showKomalCheckIn = true
                    self.updateNextCheckIn()
                }
            }
            return
        }
        
        // Send ALL non-trusted domains to server for analysis
        // Server decides gate/block/allow based on URL + raw search input
        do {
            let rawSearchInput = trimmedInput
            debugLogLine("[DEBUG-SCAN] Sending to server - URL: \(normalizedURL), searchQuery: \(rawSearchInput)")

            let apiResult = try await networkService.scanURLWithFormat(normalizedURL, searchQuery: rawSearchInput)

            switch apiResult {
            case .unified(let decision):
                debugLogLine("[DEBUG-SCAN] Processing UNIFIED decision")
                unifiedDecision = decision
                await processUnifiedDecision(normalizedURL: normalizedURL, decision: decision)
            case .legacy(let response):
                debugLogLine("[DEBUG-SCAN] Processing LEGACY scan result")
                scanResult = response
                await processScanResult(normalizedURL: normalizedURL)
            }

            // Show check-in after successful search (if it's time)
            if shouldCheckIn && !showBlocked && !showBlockedEmojiPopup && !showGate && !showKomalIntervention {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.showKomalCheckIn = true
                    self.updateNextCheckIn()
                }
            }
        } catch {
            debugLogLine("[DEBUG-SCAN] Server scan failed: \(error.localizedDescription)")
            self.error = error
            loading = false

            // Fail-closed: block untrusted URLs when server is unavailable
            if let url = URL(string: normalizedURL) {
                let finalCheck = BrowserState.checkURL(url, parentSettings: appState.parentSettings)
                if finalCheck.shouldIntervene, let trigger = finalCheck.trigger {
                    self.interventionTrigger = trigger
                    self.showKomalIntervention = true
                    self.currentURL = nil
                    Task {
                        await appHistoryService.logEvent(
                            url: normalizedURL,
                            searchQuery: urlInput,
                            action: "BLOCK",
                            category: "Content Filter",
                            subcategory: trigger.searchTerm,
                            childName: appState.activeProfile.name,
                            ageGroup: appState.activeProfile.ageGroup.rawValue
                        )
                    }
                    return
                }

                debugLogLine("[DEBUG-SCAN] Blocking untrusted URL (server unavailable): \(url)")
                self.blockReason = "We couldn't verify this content is safe right now. Let's try something else!"
                self.category = .unknown
                self.currentURL = nil
                self.showBlocked = true

                historyService.logBlocked(
                    url: url,
                    category: "Safety Check Failed",
                    reason: "Server analysis unavailable"
                )
                Task {
                    await appHistoryService.logEvent(
                        url: normalizedURL,
                        searchQuery: urlInput,
                        action: "BLOCK",
                        category: "Safety Check Failed",
                        childName: appState.activeProfile.name,
                        ageGroup: appState.activeProfile.ageGroup.rawValue
                    )
                }
            }
        }
    }
    
    /// Handle gate dismissal - load gated URL after emoji collected
    func handleGateDismissed() {
        guard let url = pendingURL else { return }
        pendingURL = nil
        lastSafeURL = url
        urlInput = url.host ?? url.absoluteString
        // Small delay to let the sheet dismiss animation complete before loading WebView
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.currentURL = url
            self?.loading = true
        }
    }
    
    /// Handle blocked view dismissal - redirect to previous safe page
    func handleBlockedDismissed() {
        // Don't redirect if a new scan is already in progress (resetStates triggered this)
        guard !loading else { return }
        if let safeURL = lastSafeURL {
            urlInput = safeURL.host ?? safeURL.absoluteString
            currentURL = safeURL
        } else {
            urlInput = "google.com"
            currentURL = URL(string: "https://www.google.com")
        }
        pendingURL = nil
    }
    
    /// Update loading state from WebView
    func updateLoading(_ isLoading: Bool) {
        loading = isLoading
    }
    
    // MARK: - Private Methods
    
    private func resetStates() {
        showGate = false
        showBlocked = false
        showBlockedEmojiPopup = false
        showEmojiCheckIn = false
        showKomalCheckIn = false
        showKomalIntervention = false
        interventionTrigger = nil
        currentURL = nil
        pendingURL = nil
        error = nil
    }
    
    /// Handle intervention dismissal - redirect to safe page
    func handleInterventionDismissed(allowContinue: Bool = false) {
        showKomalIntervention = false
        interventionTrigger = nil

        if allowContinue, let url = pendingURL {
            currentURL = url
            pendingURL = nil
        } else {
            // Redirect to previous safe page
            if let safeURL = lastSafeURL {
                urlInput = safeURL.host ?? safeURL.absoluteString
                currentURL = safeURL
            } else {
                urlInput = "google.com"
                currentURL = URL(string: "https://www.google.com")
            }
            pendingURL = nil
        }
    }
    
    /// Check if URL contains inappropriate keywords
    private func containsInappropriateContent(_ urlString: String) -> Bool {
        let lowercased = urlString.lowercased()
        
        // List of inappropriate keywords (can be expanded)
        let inappropriateKeywords = [
            "weed", "marijuana", "cannabis", "drug", "cocaine", "heroin",
            "porn", "xxx", "adult", "sex", "nude", "naked",
            "violence", "kill", "murder", "weapon", "gun",
            "gambling", "casino", "bet", "poker"
        ]
        
        // Check if any keyword appears in the URL
        for keyword in inappropriateKeywords {
            if lowercased.contains(keyword) {
                return true
            }
        }
        
        // Also check against custom blocked keywords from settings
        for blockedKeyword in appState.parentSettings.blockedKeywords {
            if lowercased.contains(blockedKeyword.lowercased()) {
                return true
            }
        }
        
        // Check against custom blocked hosts
        if let host = URL(string: urlString)?.host {
            let hostLower = host.lowercased()
            for blockedHost in appState.parentSettings.blockedHosts {
                if hostLower.contains(blockedHost.lowercased()) {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Check if URL is from a trusted kid-friendly domain
    private func isTrustedDomain(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        
        // Check exact match
        if trustedDomains.contains(host) {
            return true
        }
        
        // Check if it's a subdomain of a trusted domain
        for trustedDomain in trustedDomains {
            if host.hasSuffix(".\(trustedDomain)") {
                return true
            }
        }
        
        return false
    }
    
    private func normalizeURL(_ input: String) -> String {
        var normalized = input.trimmingCharacters(in: .whitespaces)
        
        // Check if it looks like a URL (has domain-like structure)
        let looksLikeUrl = normalized.contains(".") &&
                          !normalized.contains(" ") &&
                          (normalized.hasPrefix("http://") ||
                           normalized.hasPrefix("https://") ||
                           normalized.contains(".com") ||
                           normalized.contains(".org") ||
                           normalized.contains(".net") ||
                           normalized.contains(".edu") ||
                           normalized.contains(".io") ||
                           normalized.contains(".co"))
        
        if looksLikeUrl {
            if !normalized.hasPrefix("http://") && !normalized.hasPrefix("https://") {
                normalized = "https://" + normalized
            }
            return normalized
        }
        
        // Not a URL - convert to Google Safe Search
        // This ensures searches go through Google with safe mode enabled
        let encodedQuery = normalized.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? normalized
        return "https://www.google.com/search?q=\(encodedQuery)&safe=active"
    }
    
    // MARK: - Content Analysis Helpers
    
    /// Build ContentAnalysisInput from URL (basic version - can be enhanced later with WebView extraction)
    private func buildContentAnalysisInput(url: String) -> ContentAnalysisInput {
        return ContentAnalysisInput(
            url: url,
            htmlText: nil, // Will be extracted from WebView later
            media: nil,    // Will be extracted from WebView later
            structuralMetadata: StructuralMetadata(
                pageType: detectPageType(from: url),
                platform: detectPlatform(from: url)
            ),
            extraMetadata: ExtraMetadata(
                creator: nil,
                sponsors: [],
                links: []
            )
        )
    }
    
    /// Detect page type from URL patterns
    private func detectPageType(from urlString: String) -> PageType {
        let lowercased = urlString.lowercased()
        
        if lowercased.contains("/watch") || lowercased.contains("/v/") {
            return .videoPlayer
        } else if lowercased.contains("/shorts/") || lowercased.contains("tiktok.com") {
            return .shortFormVideo
        } else if lowercased.contains("/live") || lowercased.contains("stream") {
            return .liveStream
        } else if lowercased.contains("/product/") || lowercased.contains("/shop/") {
            return .productPage
        } else if lowercased.contains("/search") {
            return .searchResults
        } else if lowercased.contains("/article/") || lowercased.contains("/post/") {
            return .article
        }
        
        return .generic
    }
    
    /// Detect platform from URL
    private func detectPlatform(from urlString: String) -> String? {
        let lowercased = urlString.lowercased()
        
        if lowercased.contains("youtube.com") || lowercased.contains("youtu.be") {
            return "YouTube"
        } else if lowercased.contains("tiktok.com") {
            return "TikTok"
        } else if lowercased.contains("instagram.com") {
            return "Instagram"
        } else if lowercased.contains("discord.com") {
            return "Discord"
        } else if lowercased.contains("twitter.com") || lowercased.contains("x.com") {
            return "Twitter"
        } else if lowercased.contains("facebook.com") {
            return "Facebook"
        } else if lowercased.contains("reddit.com") {
            return "Reddit"
        }
        
        return nil
    }
    
    /// Process unified decision response
    private func processUnifiedDecision(normalizedURL: String, decision: UnifiedDecisionResponse) async {
        let ageBand = appState.activeProfile.ageGroup.toAgeBand()

        // Look up age action with fallback key formats
        // AgeBand raw values use underscores ("10_13") but server may use hyphens ("10-13") or other formats
        let ageAction: AgeAction? = resolveAgeAction(ageBand: ageBand, from: decision.ageActions)

        guard let ageAction = ageAction else {
            // Fallback: use most restrictive action from any age band
            debugLogLine("[DEBUG-SCAN] No action found for age band \(ageBand.rawValue), checking fallback")
            if let fallback = getMostRestrictiveUnifiedAction(from: decision.ageActions) {
                debugLogLine("[DEBUG-SCAN] Using most restrictive fallback: \(fallback.action.rawValue)")
                // Continue processing with fallback action
                await processUnifiedWithAction(normalizedURL: normalizedURL, decision: decision, ageAction: fallback)
                return
            }
            debugLogLine("[DEBUG-SCAN] No actions available at all, allowing by default")
            loading = false
            if let url = URL(string: normalizedURL) {
                lastSafeURL = url
                currentURL = url
            }
            return
        }
        
        await processUnifiedWithAction(normalizedURL: normalizedURL, decision: decision, ageAction: ageAction)
    }

    /// Shared processing for unified decisions once the age action is resolved
    private func processUnifiedWithAction(normalizedURL: String, decision: UnifiedDecisionResponse, ageAction: AgeAction) async {
        let ageBand = appState.activeProfile.ageGroup.toAgeBand()

        debugLogLine("[DEBUG-SCAN] Action determined: \(ageAction.action.rawValue) (score: \(ageAction.score))")

        // Determine category from major categories
        if let firstMajor = decision.majorCategories.first {
            category = ContentCategory(label: firstMajor.name)
            debugLogLine("[DEBUG-SCAN] Category: \(firstMajor.name) (probability: \(firstMajor.probability))")
        }

        blockReason = ageAction.reason ?? "Content filtered for safety"

        // Log to history with categorization
        if let url = URL(string: normalizedURL) {
            historyService.logUnifiedDecision(
                url: url,
                decision: decision,
                ageBand: ageBand
            )
        }

        // Extract subcategory for emoji system
        if let firstSub = decision.subcategories.first {
            currentSubcategory = firstSub.name
        }

        // Handle action
        handleUnifiedAction(ageAction.action, decision: decision)

        // Log to Firebase
        let searchQuery = urlInput
        Task {
            let docId = await appHistoryService.logEvent(
                url: decision.url,
                searchQuery: searchQuery,
                action: ageAction.action.rawValue,
                category: decision.majorCategories.first?.name,
                subcategory: decision.subcategories.first?.name,
                childName: appState.activeProfile.name,
                ageGroup: appState.activeProfile.ageGroup.rawValue
            )
            if let docId = docId {
                await MainActor.run { self.lastLoggedDocumentId = docId }
            }
        }
    }

    /// Resolve age action from unified response, trying multiple key formats
    private func resolveAgeAction(ageBand: AgeBand, from ageActions: [String: AgeAction]) -> AgeAction? {
        // Try exact match with enum raw value (e.g., "10_13")
        if let action = ageActions[ageBand.rawValue] {
            debugLogLine("[DEBUG-SCAN] Exact ageBand match: '\(ageBand.rawValue)'")
            return action
        }

        // Try hyphen format (e.g., "10-13") — server commonly uses this
        let hyphenKey = ageBand.rawValue.replacingOccurrences(of: "_", with: "-")
        if let action = ageActions[hyphenKey] {
            debugLogLine("[DEBUG-SCAN] Hyphen key match: '\(hyphenKey)'")
            return action
        }

        // Try server legacy-style keys (e.g., "<10", "10-13", "13-16", "16+")
        let legacyKey: String
        switch ageBand {
        case .below10: legacyKey = "<10"
        case .age10_13: legacyKey = "10-13"
        case .age13_16: legacyKey = "13-16"
        case .age16_18: legacyKey = "16+"
        }
        if let action = ageActions[legacyKey] {
            debugLogLine("[DEBUG-SCAN] Legacy key match: '\(legacyKey)'")
            return action
        }

        // Try partial match as last resort
        for (key, value) in ageActions {
            let normalizedKey = key.replacingOccurrences(of: "-", with: "_")
            if normalizedKey == ageBand.rawValue {
                debugLogLine("[DEBUG-SCAN] Normalized key match: '\(key)'")
                return value
            }
        }

        debugLogLine("[DEBUG-SCAN] No match for ageBand '\(ageBand.rawValue)' in keys: \(Array(ageActions.keys))")
        return nil
    }

    /// Get the most restrictive action from any age band (fallback)
    private func getMostRestrictiveUnifiedAction(from ageActions: [String: AgeAction]) -> AgeAction? {
        guard !ageActions.isEmpty else { return nil }
        let allActions = Array(ageActions.values)
        if let block = allActions.first(where: { $0.action == .block }) { return block }
        if let gate = allActions.first(where: { $0.action == .gate }) { return gate }
        return allActions.first
    }
    
    /// Handle action from unified decision
    private func handleUnifiedAction(_ action: Action, decision: UnifiedDecisionResponse) {
        switch action {
        case .block:
            debugLogLine("[DEBUG-SCAN] BLOCK action for URL: \(decision.url)")
            currentURL = nil
            showGate = false
            showKomalCheckIn = false
            loading = false
            showBlockedEmojiPopup = true

        case .gate:
            debugLogLine("[DEBUG-SCAN] GATE action for URL: \(decision.url)")
            if let url = URL(string: decision.url) {
                pendingURL = url
            }
            currentURL = nil
            showBlocked = false
            showKomalCheckIn = false
            loading = false
            gateAvatarIndex = Int.random(in: 1...11)
            showGate = true

        case .allow:
            debugLogLine("[DEBUG-SCAN] ALLOW action - Loading: \(decision.url)")
            showGate = false
            showBlocked = false
            if let url = URL(string: decision.url) {
                lastSafeURL = url
                currentURL = url
                loading = true // WebView will set to false when done

                // Emoji check-in tracking
                pagesLoadedSinceLastEmoji += 1
                if pagesLoadedSinceLastEmoji >= 5 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        self?.showEmojiCheckIn = true
                    }
                    pagesLoadedSinceLastEmoji = 0
                }
            } else {
                loading = false
            }
        }
    }
    
    private func processScanResult(normalizedURL: String) async {
        guard let result = scanResult else {
            loading = false
            if let url = URL(string: normalizedURL) {
                currentURL = url
            }
            return
        }
        
        let ageGroupString = appState.activeProfile.ageGroup.rawValue
        debugLogLine("[DEBUG-SCAN] User age group: '\(ageGroupString)'")

        // Debug: Print all available age group keys
        debugLogLine("[DEBUG-SCAN] Available age group keys in scan result:")
        for (key, value) in result.ageGroupScores {
            debugLogLine("[DEBUG-SCAN]    Key: '\(key)' -> Action: \(value.action.rawValue)")
        }
        
        // Determine action for user's age group
        guard let action = determineAction(for: ageGroupString, from: result) else {
            // Fallback: allow by default
            debugLogLine("[DEBUG-SCAN] No action found, allowing by default")
            loading = false
            if let url = URL(string: result.url) {
                currentURL = url
            }
            return
        }
        
        debugLogLine("[DEBUG-SCAN] Legacy action determined: \(action.rawValue)")

        // Determine category and reason
        let (determinedCategory, determinedReason) = determineCategoryAndReason(
            from: result,
            ageGroup: ageGroupString
        )
        
        category = determinedCategory
        blockReason = determinedReason
        
        // Extract subcategory for emoji system
        if let firstRisk = result.childSafetyAnalysis.riskCategories.first {
            currentSubcategory = firstRisk.category
        }

        // Handle action
        handleAction(action, result: result)

        // Log to Firebase
        let searchQuery = urlInput
        Task {
            let docId = await appHistoryService.logEvent(
                url: result.url,
                searchQuery: searchQuery,
                action: action.rawValue,
                category: category.label,
                subcategory: currentSubcategory.isEmpty ? nil : currentSubcategory,
                childName: appState.activeProfile.name,
                ageGroup: appState.activeProfile.ageGroup.rawValue
            )
            if let docId = docId {
                await MainActor.run { self.lastLoggedDocumentId = docId }
            }
        }
    }
    
    /// Map app AgeGroup rawValue to server age group key
    /// App: "< 10", "10–13", "13–16", "16–18", "18+"
    /// Server: "<10", "10-13", "13-16", "16+"
    private func serverAgeGroupKey(for ageGroup: String) -> String {
        switch ageGroup {
        case "< 10":
            return "<10"
        case "10–13":
            return "10-13"
        case "13–16":
            return "13-16"
        case "16–18", "18+":
            return "16+"
        default:
            // Fallback: normalize em-dash to hyphen, strip spaces
            return ageGroup
                .replacingOccurrences(of: "–", with: "-")
                .replacingOccurrences(of: " ", with: "")
        }
    }

    private func determineAction(for ageGroup: String, from result: ScanResponse) -> Action? {
        // Try exact match first
        if let action = result.ageGroupScores[ageGroup]?.action {
            debugLogLine("[DEBUG-SCAN] Exact match for '\(ageGroup)' -> \(action.rawValue)")
            return action
        }

        // Map to server key format
        let serverKey = serverAgeGroupKey(for: ageGroup)
        debugLogLine("[DEBUG-SCAN] Mapped '\(ageGroup)' -> server key '\(serverKey)'")
        if let action = result.ageGroupScores[serverKey]?.action {
            debugLogLine("[DEBUG-SCAN] Found action via server key: '\(serverKey)' -> \(action.rawValue)")
            return action
        }

        // Try partial match as last resort
        for (key, value) in result.ageGroupScores {
            if key.contains(ageGroup) || ageGroup.contains(key) {
                debugLogLine("[DEBUG-SCAN] Found action by partial match: '\(key)' -> \(value.action.rawValue)")
                return value.action
            }
        }

        // Use fallback: most restrictive action
        return getFallbackAction(from: result)
    }
    
    private func getFallbackAction(from result: ScanResponse) -> Action? {
        guard !result.ageGroupScores.isEmpty else { return nil }
        
        debugLogLine("[DEBUG-SCAN] No exact match found, using fallback")
        let allActions = result.ageGroupScores.values.map { $0.action }

        if allActions.contains(.block) {
            debugLogLine("[DEBUG-SCAN] Using BLOCK as fallback (most restrictive)")
            return .block
        } else if allActions.contains(.gate) {
            debugLogLine("[DEBUG-SCAN] Using GATE as fallback")
            return .gate
        } else if let firstAction = allActions.first {
            debugLogLine("[DEBUG-SCAN] Using first available action: \(firstAction.rawValue)")
            return firstAction
        }
        
        return nil
    }
    
    private func determineCategoryAndReason(from result: ScanResponse, ageGroup: String) -> (ContentCategory, String) {
        if !result.childSafetyAnalysis.riskCategories.isEmpty {
            let firstRisk = result.childSafetyAnalysis.riskCategories.first!
            let category = ContentCategory(label: firstRisk.category)
            let reason = getReason(for: ageGroup, from: result) ?? firstRisk.category
            debugLogLine("[DEBUG-SCAN] Category from risk: \(firstRisk.category)")
            return (category, reason)
        } else {
            // Fallback: determine category from overall risk level
            let category: ContentCategory
            switch result.childSafetyAnalysis.overallRisk {
            case .dangerous:
                category = .violence
            case .unsafe:
                category = .explicitContent
            case .caution:
                category = .platformRisks
            case .safe:
                category = .unknown
            }
            let reason = getReason(for: ageGroup, from: result) ?? "Content blocked for safety reasons"
            debugLogLine("[DEBUG-SCAN] Category from overall risk: \(result.childSafetyAnalysis.overallRisk.rawValue)")
            return (category, reason)
        }
    }
    
    private func getReason(for ageGroup: String, from result: ScanResponse) -> String? {
        // Try exact match
        if let reason = result.ageGroupScores[ageGroup]?.reason {
            return reason
        }

        // Try server key format
        let serverKey = serverAgeGroupKey(for: ageGroup)
        if let reason = result.ageGroupScores[serverKey]?.reason {
            return reason
        }

        return nil
    }
    
    private func handleAction(_ action: Action, result: ScanResponse) {
        // Determine category string for logging
        let categoryString = result.childSafetyAnalysis.riskCategories.first?.category ?? category.label

        switch action {
        case .block:
            debugLogLine("[DEBUG-SCAN] Legacy BLOCK for: \(result.url)")
            // Log blocked event for history tracking
            if let url = URL(string: result.url) {
                historyService.logBlocked(url: url, category: categoryString, reason: blockReason)
            }
            currentURL = nil
            showGate = false
            showKomalCheckIn = false
            loading = false
            showBlockedEmojiPopup = true

        case .gate:
            debugLogLine("[DEBUG-SCAN] Legacy GATE for: \(result.url)")
            if let url = URL(string: result.url) {
                pendingURL = url
                // Log gated event for history tracking
                historyService.logGated(url: url, category: categoryString)
            }
            currentURL = nil
            showBlocked = false
            showKomalCheckIn = false
            loading = false
            gateAvatarIndex = Int.random(in: 1...11)
            showGate = true

        case .allow:
            debugLogLine("[DEBUG-SCAN] Legacy ALLOW - Loading: \(result.url)")
            showGate = false
            showBlocked = false
            if let url = URL(string: result.url) {
                lastSafeURL = url
                currentURL = url
                // Log allowed event for history tracking
                historyService.logEvent(url: url, type: .allowed, category: categoryString, action: .allow)
                loading = true // WebView will set to false when done
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
                    self?.loading = false
                }

                // Emoji check-in tracking
                pagesLoadedSinceLastEmoji += 1
                if pagesLoadedSinceLastEmoji >= 5 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        self?.showEmojiCheckIn = true
                    }
                    pagesLoadedSinceLastEmoji = 0
                }
            } else {
                loading = false
            }
        }
    }

    // MARK: - Emoji Response Handler

    func handleEmojiResponse(emoji: String, forDocumentId documentId: String?) {
        showEmojiCheckIn = false
        // Note: Do NOT set showBlockedEmojiPopup = false here.
        // The BlockedEmojiPopup has its own countdown + voice chat flow.
        // It dismisses itself via onDismiss callback when countdown finishes.
        guard let docId = documentId else { return }
        Task {
            await appHistoryService.updateEmojiResponse(documentId: docId, emoji: emoji)
        }
    }
}
