//
//  KomalSafetyScannerViewModel.swift
//  Komalios
//
//  URL scanning orchestration, tab management, and overlay state
//  for the child-safe browser.
//

import Foundation
import Combine

#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Browser Tab Model

struct BrowserTab: Identifiable {
    let id = UUID()
    var url: URL?
    var title: String
    var urlInput: String
    var timestamp: Date = Date()

    var displayDomain: String {
        guard let host = url?.host else { return "New Tab" }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

// MARK: - ViewModel

@MainActor
final class KomalSafetyScannerViewModel: ObservableObject {

    // MARK: Published — Core Navigation

    @Published var urlInput: String = "google.com"
    @Published var currentURL: URL? = URL(string: "https://www.google.com")
    @Published var pendingURL: URL?
    @Published var loading = false
    @Published var error: Error?

    // MARK: Published — Overlay Flags

    @Published var showGate = false
    @Published var showBlocked = false
    @Published var showKomalIntervention = false
    @Published var interventionTrigger: KomalInterventionTrigger?
    @Published var category: ContentCategory = .unknown
    @Published var blockReason: String = ""

    // MARK: Published — Tabs

    @Published var tabs: [BrowserTab] = [
        BrowserTab(url: URL(string: "https://www.google.com"), title: "Google", urlInput: "google.com")
    ]
    @Published var activeTabIndex: Int = 0

    var tabCount: Int { tabs.count }

    // MARK: Published — Emoji / Intervention

    @Published var showEmojiCheckIn = false
    @Published var showBlockedEmojiPopup = false
    @Published var currentSubcategory: String = ""
    @Published var lastLoggedDocumentId: String?
    @Published var gateAvatarIndex: Int = 1

    // MARK: Published — Unified Decision

    @Published var unifiedDecision: UnifiedDecisionResponse?

    // MARK: Private State

    var pagesLoadedSinceLastEmoji: Int = 0
    private var lastSafeURL: URL?
    private var lastCountedPageURL: URL?

    private(set) var blockedEmojiPopupCount: Int = 0
    var shouldShowTalkFeature: Bool { blockedEmojiPopupCount > 0 && blockedEmojiPopupCount % 4 == 0 }

    private var blockedPopupRecentlyDismissed = false
    private var gateDismissTask: Task<Void, Never>?

    deinit {
        gateDismissTask?.cancel()
    }

    // MARK: Dependencies

    private let networkService = ScanNetworkService()
    private let historyService = BrowsingHistoryService.shared
    private let contentAnalysisService = ContentAnalysisService.shared
    private let appHistoryService = AppHistoryService.shared
    var appState: AppState

    // MARK: Init

    init(appState: AppState) {
        self.appState = appState
        self.gateAvatarIndex = appState.activeProfile.selectedAvatarIndex
    }

    func updateAppState(_ appState: AppState) {
        self.appState = appState
    }

    /// Navigate to a URL programmatically (e.g. from browsing history).
    /// Populates the omnibox and runs the same pipeline as manual submission.
    func navigateToURL(_ url: URL) async {
        urlInput = LocaleFormatterCache.stripBiDiOverrides(url.absoluteString)
        await handleUrlSubmit()
    }

    // MARK: - URL Submission

    func handleUrlSubmit() async {
        let trimmed = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // New user-initiated navigation clears the dismiss-suppression flag
        // so blocked content shows a fresh popup instead of silently redirecting.
        blockedPopupRecentlyDismissed = false

        debugLogLine("[DEBUG-SCAN] Starting URL scan for: \(urlInput)")

        let looksLikeURL = trimmed.contains(".") && !trimmed.contains(" ")

        // Pre-scan raw input for keywords
        if let flagged = BrowserState.checkForInappropriateContent(trimmed, isSearchQuery: !looksLikeURL) {
            debugLogLine("[DEBUG-SCAN] RAW INPUT FLAGGED: \(flagged)")
            resetStates()
            currentURL = nil
            interventionTrigger = looksLikeURL ? .urlKeyword(flagged) : .searchQuery(flagged)
            currentSubcategory = flagged
            triggerBlockedEmojiPopup()
            loading = false
            historyService.logBlocked(
                url: URL(string: "blocked://\(urlInput.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "unknown")") ?? URL(string: "about:blank")!,
                category: "Content Filter",
                reason: "Searched for: \(flagged)"
            )
            await appHistoryService.logEvent(
                url: trimmed, searchQuery: trimmed,
                action: "BLOCK", category: "Content Filter", subcategory: flagged,
                childName: appState.activeProfile.name,
                ageGroup: appState.activeProfile.ageGroup.rawValue
            )
            return
        }

        resetStates()
        loading = true

        let normalizedURL = normalizeURL(urlInput)
        debugLogLine("[DEBUG-SCAN] Normalized URL: \(normalizedURL)")

        // Secondary check on normalized URL
        if let url = URL(string: normalizedURL) {
            let contentCheck = BrowserState.checkURL(url, parentSettings: appState.parentSettings)
            if contentCheck.shouldIntervene, let trigger = contentCheck.trigger {
                debugLogLine("[DEBUG-SCAN] URL content check triggered: \(trigger.searchTerm)")
                historyService.logBlocked(url: url, category: "Content Filter", reason: "Intervention: \(trigger.searchTerm)")
                await appHistoryService.logEvent(
                    url: normalizedURL, searchQuery: urlInput,
                    action: "BLOCK", category: "Content Filter", subcategory: trigger.searchTerm,
                    childName: appState.activeProfile.name,
                    ageGroup: appState.activeProfile.ageGroup.rawValue
                )
                showGate = false
                showBlocked = false
                currentURL = nil
                interventionTrigger = trigger
                currentSubcategory = trigger.searchTerm
                triggerBlockedEmojiPopup()
                loading = false
                return
            }
            historyService.logTypedURL(url: url)
        }

        // Blocked platform check
        if let url = URL(string: normalizedURL), Constants.isBlockedPlatform(url) {
            let host = url.host ?? "unknown"
            debugLogLine("[DEBUG-SCAN] Blocked platform: \(host)")
            historyService.logBlocked(url: url, category: "Platform Block", reason: "Blocked platform: \(host)")
            await appHistoryService.logEvent(
                url: normalizedURL, action: "BLOCK",
                category: "Platform Block", subcategory: host,
                childName: appState.activeProfile.name,
                ageGroup: appState.activeProfile.ageGroup.rawValue
            )
            resetStates()
            interventionTrigger = .urlKeyword(host)
            currentSubcategory = host
            triggerBlockedEmojiPopup()
            return
        }

        // YouTube — allow navigation, per-video analysis handled by JS scanner
        if let url = URL(string: normalizedURL), Constants.isYouTubeDomain(url) {
            // Still check search keywords in YouTube URLs
            if let query = BrowserState.extractSearchQuery(from: url),
               let flagged = BrowserState.checkForInappropriateContent(query, isSearchQuery: true) {
                debugLogLine("[DEBUG-SCAN] Blocked YouTube search query: \(flagged)")
                historyService.logBlocked(url: url, category: "Content Filter", reason: "YouTube search: \(flagged)")
                await appHistoryService.logEvent(
                    url: normalizedURL, action: "BLOCK",
                    category: "Content Filter", subcategory: flagged,
                    childName: appState.activeProfile.name,
                    ageGroup: appState.activeProfile.ageGroup.rawValue
                )
                resetStates()
                interventionTrigger = .searchQuery(flagged)
                currentSubcategory = flagged
                triggerBlockedEmojiPopup()
                loading = false
                return
            }
            debugLogLine("[DEBUG-SCAN] YouTube domain - per-video JS analysis: \(url.host ?? "")")
            lastSafeURL = url
            currentURL = url
            historyService.logEvent(url: url, type: .allowed, category: "YouTube (Monitored)", action: .allow)
            loading = false
            await appHistoryService.logEvent(
                url: normalizedURL,
                searchQuery: looksLikeURL ? nil : trimmed,
                action: "ALLOW", category: "YouTube (Monitored)",
                childName: appState.activeProfile.name,
                ageGroup: appState.activeProfile.ageGroup.rawValue
            )
            return
        }

        // Trusted domain — skip scanning
        if let url = URL(string: normalizedURL), Constants.isTrustedDomain(url) {
            debugLogLine("[DEBUG-SCAN] Trusted domain - skipping scan: \(url.host ?? "")")
            lastSafeURL = url
            currentURL = url
            historyService.logEvent(url: url, type: .allowed, category: "Trusted Site", action: .allow)
            loading = false
            await appHistoryService.logEvent(
                url: normalizedURL,
                searchQuery: looksLikeURL ? nil : trimmed,
                action: "ALLOW", category: "Trusted Site",
                childName: appState.activeProfile.name,
                ageGroup: appState.activeProfile.ageGroup.rawValue
            )
            return
        }

        // On-device-first analysis with cloud fallback
        do {
            debugLogLine("[DEBUG-SCAN] Starting on-device-first analysis - URL: \(normalizedURL), searchQuery: \(trimmed)")
            let input = buildContentAnalysisInput(url: normalizedURL)
            let decision = try await contentAnalysisService.analyzeContent(
                url: normalizedURL,
                input: input,
                ageBand: appState.activeProfile.ageGroup.toAgeBand(),
                customBlockedKeywords: appState.parentSettings.blockedKeywords,
                customBlockedHosts: appState.parentSettings.blockedHosts,
                filterPreferences: appState.contentFilterPreferences,
                searchQuery: trimmed
            )

            debugLogLine("[DEBUG-SCAN] Processing unified decision from on-device/cloud pipeline")
            unifiedDecision = decision
            await processUnifiedDecision(normalizedURL: normalizedURL, decision: decision)

        } catch {
            debugLogLine("[DEBUG-SCAN] Analysis pipeline failed: \(error.localizedDescription)")
            self.error = error
            loading = false

            // Fail-closed for untrusted URLs
            if let url = URL(string: normalizedURL) {
                let finalCheck = BrowserState.checkURL(url, parentSettings: appState.parentSettings)
                if finalCheck.shouldIntervene, let trigger = finalCheck.trigger {
                    interventionTrigger = trigger
                    currentSubcategory = trigger.searchTerm
                    triggerBlockedEmojiPopup()
                    currentURL = nil
                    await appHistoryService.logEvent(
                        url: normalizedURL, searchQuery: urlInput,
                        action: "BLOCK", category: "Content Filter", subcategory: trigger.searchTerm,
                        childName: appState.activeProfile.name,
                        ageGroup: appState.activeProfile.ageGroup.rawValue
                    )
                    return
                }

                debugLogLine("[DEBUG-SCAN] Blocking untrusted URL (analysis unavailable): \(url)")
                blockReason = LanguageManager.localized("browser.content_unverified")
                category = .unknown
                currentURL = nil
                showBlocked = true

                historyService.logBlocked(url: url, category: "Safety Check Failed", reason: "Analysis pipeline unavailable")
                await appHistoryService.logEvent(
                    url: normalizedURL, searchQuery: urlInput,
                    action: "BLOCK", category: "Safety Check Failed",
                    childName: appState.activeProfile.name,
                    ageGroup: appState.activeProfile.ageGroup.rawValue
                )
            }
        }
    }

    // MARK: - Dismissal Handlers

    func handleGateDismissed() {
        guard let url = pendingURL else { return }
        pendingURL = nil
        blockedPopupRecentlyDismissed = false
        lastSafeURL = url
        urlInput = LocaleFormatterCache.stripBiDiOverrides(url.host ?? url.absoluteString)
        gateDismissTask?.cancel()
        gateDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            self?.loading = true
            self?.currentURL = url
        }
    }

    func handleBlockedDismissed() {
        guard !loading else { return }
        if let safeURL = lastSafeURL {
            urlInput = LocaleFormatterCache.stripBiDiOverrides(safeURL.host ?? safeURL.absoluteString)
            currentURL = safeURL
        } else {
            urlInput = "google.com"
            currentURL = URL(string: "https://www.google.com")
        }
        pendingURL = nil
    }

    func handleInterventionDismissed(allowContinue: Bool = false) {
        showKomalIntervention = false
        showBlockedEmojiPopup = false
        interventionTrigger = nil

        if allowContinue, let url = pendingURL {
            currentURL = url
            pendingURL = nil
        } else {
            blockedPopupRecentlyDismissed = true
            if let safeURL = lastSafeURL {
                urlInput = LocaleFormatterCache.stripBiDiOverrides(safeURL.host ?? safeURL.absoluteString)
                currentURL = safeURL
            } else {
                urlInput = "google.com"
                currentURL = URL(string: "https://www.google.com")
            }
            pendingURL = nil
        }
    }

    // MARK: - Loading

    func updateLoading(_ isLoading: Bool) {
        loading = isLoading
    }

    // MARK: - Blocked Emoji Popup

    func triggerBlockedEmojiPopup() {
        if blockedPopupRecentlyDismissed {
            currentURL = URL(string: "https://www.google.com")
            urlInput = "google.com"
            pendingURL = nil
            loading = false
            return
        }
        blockedEmojiPopupCount += 1
        showBlockedEmojiPopup = true
    }

    func clearLastSafeURLIfMatches(_ url: URL) {
        if lastSafeURL == url { lastSafeURL = nil }
    }

    // MARK: - Tab Management

    func switchToTab(at index: Int) {
        guard index >= 0, index < tabs.count else { return }
        saveCurrentTabState()
        activeTabIndex = index
        let tab = tabs[index]
        urlInput = tab.urlInput
        currentURL = tab.url
    }

    func addNewTab() {
        saveCurrentTabState()
        tabs.append(BrowserTab(url: nil, title: "New Tab", urlInput: ""))
        activeTabIndex = tabs.count - 1
        urlInput = ""
        currentURL = nil
    }

    func closeTab(at index: Int) {
        guard tabs.count > 1 else { return }
        tabs.remove(at: index)
        if activeTabIndex >= tabs.count {
            activeTabIndex = tabs.count - 1
        } else if index < activeTabIndex {
            activeTabIndex -= 1
        } else if index == activeTabIndex {
            activeTabIndex = min(activeTabIndex, tabs.count - 1)
        }
        let tab = tabs[activeTabIndex]
        urlInput = tab.urlInput
        currentURL = tab.url
    }

    func saveCurrentTabState() {
        guard activeTabIndex >= 0, activeTabIndex < tabs.count else { return }
        tabs[activeTabIndex].url = currentURL
        tabs[activeTabIndex].urlInput = urlInput
        if let host = currentURL?.host {
            tabs[activeTabIndex].title = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        }
    }

    // MARK: - Page Finish / Emoji Check-In

    func handlePageFinished(url: URL, title: String?) {
        if url == lastCountedPageURL { return }
        lastCountedPageURL = url
        pagesLoadedSinceLastEmoji += 1
        #if DEBUG
        print("📊 Page finished: \(url.host ?? "?") — pages since last emoji: \(pagesLoadedSinceLastEmoji)")
        #endif

        if pagesLoadedSinceLastEmoji >= 5 {
            guard !showGate, !showBlocked, !showBlockedEmojiPopup,
                  !showKomalIntervention, !showEmojiCheckIn else { return }
            pagesLoadedSinceLastEmoji = 0
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard let self,
                      !self.showGate, !self.showBlocked, !self.showBlockedEmojiPopup,
                      !self.showKomalIntervention, !self.showEmojiCheckIn else { return }
                self.showEmojiCheckIn = true
            }
        }
    }

    func handleEmojiResponse(emoji: String, forDocumentId documentId: String?) {
        showEmojiCheckIn = false
        guard let docId = documentId else { return }
        Task { await appHistoryService.updateEmojiResponse(documentId: docId, emoji: emoji) }
    }

    // MARK: - Background Search Scan

    func backgroundScanSearchQuery(_ searchQuery: String, url: URL) async {
        // Trusted domains (Google, etc.) already have SafeSearch active,
        // keyword filter, image filtering (CoreML), and viewport monitoring.
        // Skip cloud scan to avoid false positives on legitimate searches
        // (e.g. "belly dance", cultural/educational content).
        if Constants.isTrustedDomain(url) {
            #if DEBUG
            print("☁️ Background scan skipped for trusted domain: \(url.host ?? "")")
            #endif
            return
        }
        #if DEBUG
        print("☁️ Background scan starting for query: \(searchQuery)")
        #endif
        do {
            let input = buildContentAnalysisInput(url: url.absoluteString)
            let decision = try await contentAnalysisService.analyzeContent(
                url: url.absoluteString,
                input: input,
                ageBand: appState.activeProfile.ageGroup.toAgeBand(),
                customBlockedKeywords: appState.parentSettings.blockedKeywords,
                customBlockedHosts: appState.parentSettings.blockedHosts,
                filterPreferences: appState.contentFilterPreferences,
                searchQuery: searchQuery
            )

            let ageBand = appState.activeProfile.ageGroup.toAgeBand()
            let ageAction = resolveAgeAction(ageBand: ageBand, from: decision.ageActions)
                ?? getMostRestrictiveAction(from: decision.ageActions)

            guard let ageAction else {
                #if DEBUG
                print("☁️ Background scan: no action found, allowing")
                #endif
                return
            }

            #if DEBUG
            print("☁️ Background scan result: \(ageAction.action.rawValue) (score: \(ageAction.score))")
            #endif

            if ageAction.action == .block || ageAction.action == .gate {
                unifiedDecision = decision
                if let firstSub = decision.subcategories.first {
                    currentSubcategory = firstSub.name
                }
                handleUnifiedAction(ageAction.action, decision: decision, originalURL: url.absoluteString)

                await appHistoryService.logEvent(
                    url: decision.url, searchQuery: searchQuery,
                    action: ageAction.action.rawValue,
                    category: decision.majorCategories.first?.name,
                    subcategory: decision.subcategories.first?.name,
                    childName: appState.activeProfile.name,
                    ageGroup: appState.activeProfile.ageGroup.rawValue
                )
            }
        } catch {
            #if DEBUG
            print("⚠️ Background search scan failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Private Helpers

    private func resetStates() {
        showGate = false
        showBlocked = false
        showBlockedEmojiPopup = false
        showEmojiCheckIn = false
        loading = false
        showKomalIntervention = false
        interventionTrigger = nil
        currentURL = nil
        pendingURL = nil
        error = nil
        // blockedPopupRecentlyDismissed intentionally NOT cleared
    }

    private func normalizeURL(_ input: String) -> String {
        var normalized = input.trimmingCharacters(in: .whitespaces)

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
            // Force HTTPS — never allow plaintext HTTP connections
            if normalized.hasPrefix("http://") {
                normalized = "https://" + normalized.dropFirst(7)
            } else if !normalized.hasPrefix("https://") {
                normalized = "https://" + normalized
            }
            return normalized
        }

        let encoded = normalized.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? normalized
        return "https://www.google.com/search?q=\(encoded)&safe=active"
    }

    // MARK: Content Analysis Helpers

    private func buildContentAnalysisInput(url: String) -> ContentAnalysisInput {
        ContentAnalysisInput(
            url: url,
            htmlText: nil,
            media: nil,
            structuralMetadata: StructuralMetadata(
                pageType: detectPageType(from: url),
                platform: detectPlatform(from: url)
            ),
            extraMetadata: ExtraMetadata(creator: nil, sponsors: [], links: [])
        )
    }

    private func detectPageType(from urlString: String) -> PageType {
        let low = urlString.lowercased()
        if low.contains("/watch") || low.contains("/v/")       { return .videoPlayer }
        if low.contains("/shorts/") || low.contains("tiktok.com") { return .shortFormVideo }
        if low.contains("/live") || low.contains("stream")     { return .liveStream }
        if low.contains("/product/") || low.contains("/shop/") { return .productPage }
        if low.contains("/search")                              { return .searchResults }
        if low.contains("/article/") || low.contains("/post/") { return .article }
        return .generic
    }

    private func detectPlatform(from urlString: String) -> String? {
        let low = urlString.lowercased()
        if low.contains("tiktok.com")   { return "TikTok" }
        if low.contains("instagram.com") { return "Instagram" }
        if low.contains("discord.com")  { return "Discord" }
        if low.contains("twitter.com") || low.contains("x.com") { return "Twitter" }
        if low.contains("facebook.com") { return "Facebook" }
        if low.contains("reddit.com")   { return "Reddit" }
        return nil
    }

    // MARK: Unified Decision Processing

    private func processUnifiedDecision(normalizedURL: String, decision: UnifiedDecisionResponse) async {
        let ageBand = appState.activeProfile.ageGroup.toAgeBand()
        let ageAction = resolveAgeAction(ageBand: ageBand, from: decision.ageActions)

        guard let ageAction else {
            debugLogLine("[DEBUG-SCAN] No action found for age band \(ageBand.rawValue), checking fallback")
            if let fallback = getMostRestrictiveAction(from: decision.ageActions) {
                debugLogLine("[DEBUG-SCAN] Using most restrictive fallback: \(fallback.action.rawValue)")
                await processWithAction(normalizedURL: normalizedURL, decision: decision, ageAction: fallback)
                return
            }
            debugLogLine("[DEBUG-SCAN] No actions available at all, blocking by default (fail-closed)")
            loading = false
            if let url = URL(string: normalizedURL) {
                blockReason = LanguageManager.localized("browser.content_unverified")
                category = .unknown
                currentURL = nil
                showBlocked = true
                historyService.logBlocked(url: url, category: "No Age Actions", reason: "Empty ageActions from decision")
                await appHistoryService.logEvent(
                    url: normalizedURL, action: "BLOCK", category: "No Age Actions",
                    childName: appState.activeProfile.name,
                    ageGroup: appState.activeProfile.ageGroup.rawValue
                )
            }
            return
        }

        await processWithAction(normalizedURL: normalizedURL, decision: decision, ageAction: ageAction)
    }

    private func processWithAction(normalizedURL: String, decision: UnifiedDecisionResponse, ageAction: AgeAction) async {
        let ageBand = appState.activeProfile.ageGroup.toAgeBand()

        debugLogLine("[DEBUG-SCAN] Action determined: \(ageAction.action.rawValue) (score: \(ageAction.score))")

        if let first = decision.majorCategories.first {
            category = ContentCategory(label: first.name)
            debugLogLine("[DEBUG-SCAN] Category: \(first.name) (probability: \(first.probability))")
        }

        blockReason = ageAction.reason ?? LanguageManager.localized("browser.content_filtered")

        if let url = URL(string: normalizedURL) {
            historyService.logUnifiedDecision(url: url, decision: decision, ageBand: ageBand)
        }

        if let firstSub = decision.subcategories.first {
            currentSubcategory = firstSub.name
        }

        handleUnifiedAction(ageAction.action, decision: decision, originalURL: normalizedURL)

        let docId = await appHistoryService.logEvent(
            url: decision.url, searchQuery: urlInput,
            action: ageAction.action.rawValue,
            category: decision.majorCategories.first?.name,
            subcategory: decision.subcategories.first?.name,
            childName: appState.activeProfile.name,
            ageGroup: appState.activeProfile.ageGroup.rawValue
        )
        if let docId { self.lastLoggedDocumentId = docId }
    }

    private func resolveAgeAction(ageBand: AgeBand, from ageActions: [String: AgeAction]) -> AgeAction? {
        if let a = ageActions[ageBand.rawValue] {
            debugLogLine("[DEBUG-SCAN] Exact ageBand match: '\(ageBand.rawValue)'")
            return a
        }
        let hyphen = ageBand.rawValue.replacingOccurrences(of: "_", with: "-")
        if let a = ageActions[hyphen] {
            debugLogLine("[DEBUG-SCAN] Hyphen key match: '\(hyphen)'")
            return a
        }
        let legacy: String
        switch ageBand {
        case .below10:   legacy = "<10"
        case .age10_13:  legacy = "10-13"
        case .age13_16:  legacy = "13-16"
        case .age16_18:  legacy = "16+"
        }
        if let a = ageActions[legacy] {
            debugLogLine("[DEBUG-SCAN] Legacy key match: '\(legacy)'")
            return a
        }
        debugLogLine("[DEBUG-SCAN] No match for ageBand '\(ageBand.rawValue)' in keys: \(Array(ageActions.keys))")
        return nil
    }

    private func getMostRestrictiveAction(from ageActions: [String: AgeAction]) -> AgeAction? {
        guard !ageActions.isEmpty else { return nil }
        let all = Array(ageActions.values)
        if let block = all.first(where: { $0.action == .block }) { return block }
        if let gate = all.first(where: { $0.action == .gate }) { return gate }
        return all.first
    }

    private func handleUnifiedAction(_ action: Action, decision: UnifiedDecisionResponse, originalURL: String) {
        switch action {
        case .block:
            debugLogLine("[DEBUG-SCAN] BLOCK action for URL: \(decision.url)")
            pendingURL = nil
            currentURL = nil
            showGate = false
            loading = false
            triggerBlockedEmojiPopup()

        case .gate:
            debugLogLine("[DEBUG-SCAN] GATE action for URL: \(decision.url)")
            if let url = URL(string: originalURL) { pendingURL = url }
            currentURL = nil
            showBlocked = false
            loading = false
            gateAvatarIndex = appState.activeProfile.selectedAvatarIndex
            showGate = true

        case .allow:
            debugLogLine("[DEBUG-SCAN] ALLOW action - Loading: \(originalURL)")
            showGate = false
            showBlocked = false
            if let url = URL(string: originalURL) {
                lastSafeURL = url
                currentURL = url
                loading = true
            } else {
                loading = false
            }
        }
    }

    private func isBlockedPlatform(_ url: URL) -> Bool {
        Constants.isBlockedPlatform(url)
    }

    private func isTrustedDomain(_ url: URL) -> Bool {
        Constants.isTrustedDomain(url)
    }
}
