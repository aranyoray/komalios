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
    @Published var category: ContentCategory = .unknown
    @Published var blockReason: String = ""
    @Published var loading = false
    @Published var scanResult: ScanResponse?
    @Published var error: Error?
    
    // MARK: - Dependencies
    private let networkService = ScanNetworkService()
    private let historyService = BrowsingHistoryService.shared
    private let contentAnalysisService = ContentAnalysisService.shared
    var appState: AppState
    
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
        
        print("🔍 Starting URL scan...")
        
        // Reset states
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
        print("📡 Scanning URL: \(normalizedURL)")
        
        // Log typed URL event for history tracking
        if let url = URL(string: normalizedURL) {
            historyService.logTypedURL(url: url)
        }
        
        // Check for inappropriate keywords first (before API call)
        if containsInappropriateContent(normalizedURL) {
            print("🚫 Inappropriate content detected - showing Komal blocked view")
            category = .explicitContent
            blockReason = "Content not available"
            // Log blocked event for history tracking
            if let url = URL(string: normalizedURL) {
                historyService.logBlocked(url: url, category: "Explicit & Body Content", reason: blockReason)
            }
            showBlocked = true
            loading = false
            return
        }
        
        // Check if this is a trusted kid-friendly domain (skip scanning)
        if let url = URL(string: normalizedURL), isTrustedDomain(url) {
            print("✅ Trusted domain - skipping scan: \(url.host ?? "")")
            currentURL = url
            historyService.logEvent(url: url, type: .allowed, category: "Trusted Site", action: .allow)
            loading = false
            
            // Still show check-in if it's time
            if shouldCheckIn {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.showKomalCheckIn = true
                    self.updateNextCheckIn()
                }
            }
            return
        }
        
        // Analyze content using unified system (on-device first, cloud fallback)
        do {
            let ageBand = appState.activeProfile.ageGroup.toAgeBand()
            let input = buildContentAnalysisInput(url: normalizedURL)
            
            let decision = try await contentAnalysisService.analyzeContent(
                url: normalizedURL,
                input: input,
                ageBand: ageBand,
                customBlockedKeywords: appState.parentSettings.blockedKeywords,
                customBlockedHosts: appState.parentSettings.blockedHosts,
                filterPreferences: appState.contentFilterPreferences
            )
            
            print("✅ Content analysis completed")
            unifiedDecision = decision
            
            // Process unified decision
            await processUnifiedDecision(normalizedURL: normalizedURL, decision: decision)
            
            // Show check-in after successful search (if it's time)
            if shouldCheckIn && !showBlocked && !showGate {
                // Delay check-in slightly so user sees the page loaded
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.showKomalCheckIn = true
                    // Schedule next check-in
                    self.updateNextCheckIn()
                }
            }
        } catch {
            print("❌ Analysis Error: \(error.localizedDescription)")
            // Fallback: try existing API
            do {
                scanResult = try await networkService.scanURL(normalizedURL)
                print("✅ Fallback scan completed")
                await processScanResult(normalizedURL: normalizedURL)
                
                // Show check-in if it's time
                if shouldCheckIn && !showBlocked && !showGate {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.showKomalCheckIn = true
                        self.updateNextCheckIn()
                    }
                }
            } catch {
                self.error = error
                loading = false
                
                // If both fail, try to load URL anyway
                if let url = URL(string: normalizedURL) {
                    currentURL = url
                    
                    // Still show check-in if it's time
                    if shouldCheckIn {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.showKomalCheckIn = true
                            self.updateNextCheckIn()
                        }
                    }
                }
            }
        }
    }
    
    /// Handle gate dismissal - load pending URL if approved
    func handleGateDismissed() {
        if let url = pendingURL {
            currentURL = url
            pendingURL = nil
            loading = true
        }
    }
    
    /// Handle blocked view dismissal - reset states
    func handleBlockedDismissed() {
        currentURL = nil
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
        showKomalCheckIn = false
        currentURL = nil
        pendingURL = nil
        error = nil
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
        let looksLikeUrl = normalized.contains(".") ||
                          normalized.hasPrefix("http://") ||
                          normalized.hasPrefix("https://")
        
        if looksLikeUrl && !normalized.hasPrefix("http://") && !normalized.hasPrefix("https://") {
            normalized = "https://" + normalized
        }
        
        return normalized
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
        guard let ageAction = decision.ageActions[ageBand.rawValue] else {
            // Fallback: allow
            print("⚠️ No action found for age band, allowing by default")
            loading = false
            if let url = URL(string: normalizedURL) {
                currentURL = url
            }
            return
        }
        
        print("🎯 Action determined: \(ageAction.action.rawValue) (score: \(ageAction.score))")
        
        // Determine category from major categories
        if let firstMajor = decision.majorCategories.first {
            category = ContentCategory(label: firstMajor.name)
            print("📋 Category: \(firstMajor.name) (probability: \(firstMajor.probability))")
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
        
        // Handle action
        handleUnifiedAction(ageAction.action, decision: decision)
    }
    
    /// Handle action from unified decision
    private func handleUnifiedAction(_ action: Action, decision: UnifiedDecisionResponse) {
        switch action {
        case .block:
            print("🚫 BLOCK action - Setting showBlocked = true")
            currentURL = nil
            showGate = false
            showKomalCheckIn = false
            loading = false
            showBlocked = true
            print("🚫 State updated - showBlocked: \(showBlocked)")
            
        case .gate:
            print("🚧 GATE action - Setting showGate = true")
            if let url = URL(string: decision.url) {
                pendingURL = url
            }
            currentURL = nil
            showBlocked = false
            showKomalCheckIn = false
            loading = false
            showGate = true
            print("🚧 State updated - showGate: \(showGate)")
            
        case .allow:
            print("✅ ALLOW action - Loading website")
            showGate = false
            showBlocked = false
            if let url = URL(string: decision.url) {
                currentURL = url
                loading = true // WebView will set to false when done
                print("✅ URL set: \(url), loading: \(loading)")
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
        print("👤 User age group: '\(ageGroupString)'")
        
        // Debug: Print all available age group keys
        print("📊 Available age group keys in scan result:")
        for (key, value) in result.ageGroupScores {
            print("   - Key: '\(key)' -> Action: \(value.action.rawValue)")
        }
        
        // Determine action for user's age group
        guard let action = determineAction(for: ageGroupString, from: result) else {
            // Fallback: allow by default
            print("⚠️ No action found, allowing by default")
            loading = false
            if let url = URL(string: result.url) {
                currentURL = url
            }
            return
        }
        
        print("🎯 Action determined: \(action.rawValue)")
        
        // Determine category and reason
        let (determinedCategory, determinedReason) = determineCategoryAndReason(
            from: result,
            ageGroup: ageGroupString
        )
        
        category = determinedCategory
        blockReason = determinedReason
        
        // Handle action
        handleAction(action, result: result)
    }
    
    private func determineAction(for ageGroup: String, from result: ScanResponse) -> Action? {
        // Try exact match first
        if let action = result.ageGroupScores[ageGroup]?.action {
            return action
        }
        
        // Try alternative formats
        print("🔍 Trying alternative key formats...")
        let alternatives = [
            ageGroup.replacingOccurrences(of: "–", with: "-"),
            ageGroup.replacingOccurrences(of: "–", with: " to "),
            ageGroup.lowercased(),
            ageGroup.uppercased()
        ]
        
        for alt in alternatives {
            if let action = result.ageGroupScores[alt]?.action {
                print("✅ Found action using alternative format: '\(alt)' -> \(action.rawValue)")
                return action
            }
        }
        
        // Try partial match
        for (key, value) in result.ageGroupScores {
            if key.contains(ageGroup) || ageGroup.contains(key) {
                print("✅ Found action by partial match: '\(key)' -> \(value.action.rawValue)")
                return value.action
            }
        }
        
        // Use fallback: most restrictive action
        return getFallbackAction(from: result)
    }
    
    private func getFallbackAction(from result: ScanResponse) -> Action? {
        guard !result.ageGroupScores.isEmpty else { return nil }
        
        print("⚠️ No exact match found, using fallback")
        let allActions = result.ageGroupScores.values.map { $0.action }
        
        if allActions.contains(.block) {
            print("⚠️ Using BLOCK as fallback (most restrictive)")
            return .block
        } else if allActions.contains(.gate) {
            print("⚠️ Using GATE as fallback")
            return .gate
        } else if let firstAction = allActions.first {
            print("⚠️ Using first available action: \(firstAction.rawValue)")
            return firstAction
        }
        
        return nil
    }
    
    private func determineCategoryAndReason(from result: ScanResponse, ageGroup: String) -> (ContentCategory, String) {
        if !result.childSafetyAnalysis.riskCategories.isEmpty {
            let firstRisk = result.childSafetyAnalysis.riskCategories.first!
            let category = ContentCategory(label: firstRisk.category)
            let reason = getReason(for: ageGroup, from: result) ?? firstRisk.category
            print("📋 Category from risk: \(firstRisk.category)")
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
            print("📋 Category from overall risk: \(result.childSafetyAnalysis.overallRisk.rawValue)")
            return (category, reason)
        }
    }
    
    private func getReason(for ageGroup: String, from result: ScanResponse) -> String? {
        // Try exact match
        if let reason = result.ageGroupScores[ageGroup]?.reason {
            return reason
        }
        
        // Try alternative formats
        let alternatives = [
            ageGroup.replacingOccurrences(of: "–", with: "-"),
            ageGroup.replacingOccurrences(of: "–", with: " to "),
            ageGroup.lowercased(),
            ageGroup.uppercased()
        ]
        
        for alt in alternatives {
            if let reason = result.ageGroupScores[alt]?.reason {
                return reason
            }
        }
        
        return nil
    }
    
    private func handleAction(_ action: Action, result: ScanResponse) {
        // Determine category string for logging
        let categoryString = result.childSafetyAnalysis.riskCategories.first?.category ?? category.label
        
        switch action {
        case .block:
            print("🚫 BLOCK action - Setting showBlocked = true")
            // Log blocked event for history tracking
            if let url = URL(string: result.url) {
                historyService.logBlocked(url: url, category: categoryString, reason: blockReason)
            }
            currentURL = nil
            showGate = false
            showKomalCheckIn = false
            loading = false
            showBlocked = true
            print("🚫 State updated - showBlocked: \(showBlocked), showGate: \(showGate), loading: \(loading)")
            
        case .gate:
            print("🚧 GATE action - Setting showGate = true")
            if let url = URL(string: result.url) {
                pendingURL = url
                // Log gated event for history tracking
                historyService.logGated(url: url, category: categoryString)
            }
            currentURL = nil
            showBlocked = false
            showKomalCheckIn = false
            loading = false
            showGate = true
            print("🚧 State updated - showGate: \(showGate), showBlocked: \(showBlocked), loading: \(loading)")
            
        case .allow:
            print("✅ ALLOW action - Loading website")
            showGate = false
            showBlocked = false
            if let url = URL(string: result.url) {
                currentURL = url
                // Log allowed event for history tracking
                historyService.logEvent(url: url, type: .allowed, category: categoryString, action: .allow)
                loading = true // WebView will set to false when done
                print("✅ URL set: \(url), loading: \(loading)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
                    self?.loading = false
                }
            } else {
                loading = false
            }
        }
    }
}
