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
    @Published var urlInput: String = ""
    @Published var currentURL: URL?
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
    var appState: AppState
    
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
        
        // Check for inappropriate keywords first (before API call)
        if containsInappropriateContent(normalizedURL) {
            print("🚫 Inappropriate content detected - showing Komal blocked view")
            category = .explicitContent
            blockReason = "Content not available"
            showBlocked = true
            loading = false
            return
        }
        
        // Scan URL
        do {
            scanResult = try await networkService.scanURL(normalizedURL)
            print("✅ Scan completed. Result: Success")
            
            // Process scan result
            await processScanResult(normalizedURL: normalizedURL)
            
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
            print("❌ Scan Error: \(error.localizedDescription)")
            self.error = error
            loading = false
            
            // If scan failed, try to load URL anyway
            if let url = URL(string: normalizedURL) {
                currentURL = url
                
                // Still show check-in if it's time
                if shouldCheckIn {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.showKomalCheckIn = true
                        // Schedule next check-in
                        self.updateNextCheckIn()
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
        switch action {
        case .block:
            print("🚫 BLOCK action - Setting showBlocked = true")
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
