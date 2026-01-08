//
//  ContentFilterPlugin.swift
//  Komal - Capacitor Plugin Bridge
//
//  Exposes content filtering to React/JavaScript layer
//

import Foundation
import Capacitor

@objc(ContentFilterPlugin)
public class ContentFilterPlugin: CAPPlugin {

    private let filterService = ContentFilterService.shared
    private let parentControl = ParentControlService.shared
    private let browserService = BrowserService.shared

    // MARK: - Initialization
    @objc func initialize(_ call: CAPPluginCall) {
        // Check if onboarding is needed
        let needsOnboarding = !parentControl.isOnboardingCompleted

        call.resolve([
            "needsOnboarding": needsOnboarding,
            "childAge": parentControl.childAge,
            "biometricsEnabled": parentControl.useBiometrics
        ])
    }

    // MARK: - Onboarding
    @objc func showOnboarding(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            let onboardingVC = OnboardingViewController()
            onboardingVC.onComplete = {
                call.resolve(["success": true])
            }

            guard let viewController = self.bridge?.viewController else {
                call.reject("No view controller available")
                return
            }

            let navController = UINavigationController(rootViewController: onboardingVC)
            navController.modalPresentationStyle = .fullScreen
            viewController.present(navController, animated: true)
        }
    }

    // MARK: - Filter Check
    @objc func checkURL(_ call: CAPPluginCall) {
        guard let url = call.getString("url") else {
            call.reject("URL required")
            return
        }

        filterService.shouldAllowURL(url) { decision in
            call.resolve([
                "shouldAllow": decision.shouldAllow,
                "action": decision.action.rawValue,
                "category": decision.category.rawValue,
                "reason": decision.reason ?? "",
                "confidence": decision.confidence ?? 0.0
            ])
        }
    }

    // MARK: - Batch Check
    @objc func checkURLBatch(_ call: CAPPluginCall) {
        guard let urls = call.getArray("urls", String.self) else {
            call.reject("URLs array required")
            return
        }

        filterService.analyzeBatch(urls) { results in
            var response: [[String: Any]] = []

            for (url, decision) in results {
                response.append([
                    "url": url,
                    "shouldAllow": decision.shouldAllow,
                    "action": decision.action.rawValue,
                    "category": decision.category.rawValue
                ])
            }

            call.resolve(["results": response])
        }
    }

    // MARK: - Parent Dashboard
    @objc func showParentDashboard(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            let dashboardVC = ParentDashboardViewController()

            guard let viewController = self.bridge?.viewController else {
                call.reject("No view controller available")
                return
            }

            let navController = UINavigationController(rootViewController: dashboardVC)
            viewController.present(navController, animated: true) {
                call.resolve(["success": true])
            }
        }
    }

    // MARK: - Protected Browser
    @objc func openProtectedBrowser(_ call: CAPPluginCall) {
        let url = call.getString("url") ?? "https://www.google.com"

        DispatchQueue.main.async {
            let browserVC = ProtectedBrowserViewController()

            guard let viewController = self.bridge?.viewController else {
                call.reject("No view controller available")
                return
            }

            let navController = UINavigationController(rootViewController: browserVC)
            navController.modalPresentationStyle = .fullScreen
            viewController.present(navController, animated: true) {
                // Navigate to URL after presenting
                self.browserService.navigate(to: url)
                call.resolve(["success": true])
            }
        }
    }

    // MARK: - Statistics
    @objc func getStats(_ call: CAPPluginCall) {
        let stats = filterService.getFilteringStats()

        var categoryBreakdown: [[String: Any]] = []
        for (category, count) in stats.categoryBreakdown {
            categoryBreakdown.append([
                "category": category.rawValue,
                "displayName": category.displayName,
                "count": count
            ])
        }

        call.resolve([
            "totalRequests": stats.totalRequests,
            "blocked": stats.blocked,
            "gated": stats.gated,
            "allowed": stats.allowed,
            "blockRate": stats.blockRate,
            "cacheSize": stats.cacheSize,
            "categoryBreakdown": categoryBreakdown
        ])
    }

    // MARK: - Activity Logs
    @objc func getActivityLogs(_ call: CAPPluginCall) {
        let limit = call.getInt("limit") ?? 50
        let logs = parentControl.getActivityLogs(limit: limit)

        let response = logs.map { log in
            return [
                "id": log.id.uuidString,
                "timestamp": ISO8601DateFormatter().string(from: log.timestamp),
                "url": log.url,
                "category": log.category.rawValue,
                "action": log.action.rawValue,
                "wasBlocked": log.wasBlocked,
                "reason": log.reason ?? ""
            ]
        }

        call.resolve(["logs": response])
    }

    // MARK: - Settings
    @objc func getSettings(_ call: CAPPluginCall) {
        let settings = parentControl.getSettingsSummary()
        call.resolve(settings)
    }

    @objc func updateChildAge(_ call: CAPPluginCall) {
        guard let age = call.getInt("age") else {
            call.reject("Age required")
            return
        }

        parentControl.childAge = age
        filterService.clearCache() // Clear cache to apply new age rules

        call.resolve(["success": true])
    }

    @objc func setCustomRule(_ call: CAPPluginCall) {
        guard let categoryRaw = call.getString("category"),
              let actionRaw = call.getString("action"),
              let category = ContentCategory(rawValue: categoryRaw),
              let action = FilterAction(rawValue: actionRaw) else {
            call.reject("Invalid category or action")
            return
        }

        parentControl.setCustomRule(for: category, action: action)
        filterService.clearCache()

        call.resolve(["success": true])
    }

    // MARK: - Export
    @objc func exportSettings(_ call: CAPPluginCall) {
        guard let json = parentControl.exportSettingsAsJSON() else {
            call.reject("Failed to export settings")
            return
        }

        call.resolve(["json": json])
    }

    @objc func exportLogs(_ call: CAPPluginCall) {
        let csv = ContentLogger.shared.exportAsCSV()
        call.resolve(["csv": csv])
    }

    // MARK: - Cache Management
    @objc func clearCache(_ call: CAPPluginCall) {
        filterService.clearCache()
        call.resolve(["success": true])
    }
}
