//
//  SimpleWebView.swift
//  Komalios
//
//  Created on 18/01/26.
//

import SwiftUI

#if canImport(WebKit)
import WebKit

struct SimpleWebView: UIViewRepresentable {
    let url: URL
    @Binding var loading: Bool
    var contentFilterPreferences: ContentFilterPreferences
    var parentSettings: ParentSettings
    var onInappropriateContent: ((KomalInterventionTrigger, URL) -> Void)?  // Callback for intervention
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.defaultWebpagePreferences.preferredContentMode = .mobile
        
        // DIGITAL GUARDIAN: Add content controller for JavaScript injection
        let contentController = config.userContentController
        EngagementTracker.shared.configureMessageHandlers(for: contentController, handler: context.coordinator)
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = false
        context.coordinator.targetURL = url
        context.coordinator.webView = webView
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Only reload if URL actually changed
        let currentURLString = uiView.url?.absoluteString ?? ""
        let targetURLString = url.absoluteString
        
        // Check if URL changed and we're not already loading this URL
        if currentURLString != targetURLString && context.coordinator.targetURL?.absoluteString != targetURLString {
            context.coordinator.targetURL = url
            // Don't set isLoading here - let the navigation delegate handle it
            uiView.load(URLRequest(url: url))
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            loading: $loading,
            contentFilterPreferences: contentFilterPreferences,
            parentSettings: parentSettings,
            onInappropriateContent: onInappropriateContent
        )
    }
    
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        @Binding var loading: Bool
        var targetURL: URL? // Track the URL we're trying to load
        weak var webView: WKWebView?
        private var currentNavigation: WKNavigation? // Track current navigation to avoid duplicate callbacks
        private let historyService = BrowsingHistoryService.shared
        private let engagementTracker = EngagementTracker.shared
        private let imageFilterService = ImageFilterService.shared
        var onInappropriateContent: ((KomalInterventionTrigger, URL) -> Void)?
        
        // Store preferences and settings
        private var contentFilterPreferences: ContentFilterPreferences
        private var parentSettings: ParentSettings
        
        init(
            loading: Binding<Bool>,
            contentFilterPreferences: ContentFilterPreferences,
            parentSettings: ParentSettings,
            onInappropriateContent: ((KomalInterventionTrigger, URL) -> Void)?
        ) {
            _loading = loading
            self.contentFilterPreferences = contentFilterPreferences
            self.parentSettings = parentSettings
            self.onInappropriateContent = onInappropriateContent
        }
        
        // MARK: - WKScriptMessageHandler
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "komalEngagement":
                // Handle engagement tracking
                if let data = message.body as? [String: Any] {
                    let scrollDepth = data["scrollDepthPercent"] as? Int ?? 0
                    let scrollEvents = data["scrollEvents"] as? Int ?? 0
                    engagementTracker.updateEngagement(scrollDepth: scrollDepth, scrollEvents: scrollEvents)
                }
            case "komalImageScanner":
                handleImageScannerMessage(message.body)
            case "komalViewport":
                // DIGITAL GUARDIAN: Check viewport content on every scroll
                handleViewportMessage(message.body)
            default:
                break
            }
        }
        
        // MARK: - Viewport Content Monitoring (Scroll Detection)
        
        private func handleViewportMessage(_ body: Any) {
            guard let data = body as? [String: Any],
                  let messageType = data["type"] as? String,
                  messageType == "snapshot",
                  let snapshotData = data["data"] as? [String: Any] else { return }
            
            // Get page URL first to check if it's a trusted domain
            let pageUrlString = snapshotData["pageUrl"] as? String ?? ""
            guard let pageURL = URL(string: pageUrlString) else { return }
            
            // Skip viewport monitoring for trusted domains
            if isTrustedDomain(pageURL) {
                return
            }
            
            // Check for flagged keywords found by JS
            if let flaggedKeywords = snapshotData["flaggedKeywords"] as? [String], !flaggedKeywords.isEmpty {
                print("🛡️ VIEWPORT FLAGGED CONTENT: \(flaggedKeywords)")
                
                // Trigger intervention for first flagged keyword
                if let firstKeyword = flaggedKeywords.first {
                    historyService.logBlocked(url: pageURL, category: "Content Filter", reason: "Viewport content: \(firstKeyword)")
                    
                    DispatchQueue.main.async { [weak self] in
                        self?.onInappropriateContent?(.pageContent(firstKeyword), pageURL)
                    }
                }
                return
            }
            
            // Also scan visible text content for bad keywords
            if let visibleContent = snapshotData["visibleContent"] as? [[String: Any]] {
                for content in visibleContent {
                    if let text = content["text"] as? String, !text.isEmpty {
                        // Check text against our keyword list
                        if let flaggedKeyword = BrowserState.checkForInappropriateContent(text) {
                            print("🛡️ VIEWPORT TEXT FLAGGED: \(flaggedKeyword)")
                            
                            historyService.logBlocked(url: pageURL, category: "Content Filter", reason: "Page content: \(flaggedKeyword)")
                            
                            DispatchQueue.main.async { [weak self] in
                                self?.onInappropriateContent?(.pageContent(flaggedKeyword), pageURL)
                            }
                            return
                        }
                    }
                }
            }
            
            // Check primary content too
            if let primaryContent = snapshotData["primaryContent"] as? String, !primaryContent.isEmpty {
                if let flaggedKeyword = BrowserState.checkForInappropriateContent(primaryContent) {
                    print("🛡️ PRIMARY CONTENT FLAGGED: \(flaggedKeyword)")
                    
                    historyService.logBlocked(url: pageURL, category: "Content Filter", reason: "Primary content: \(flaggedKeyword)")
                    
                    DispatchQueue.main.async { [weak self] in
                        self?.onInappropriateContent?(.pageContent(flaggedKeyword), pageURL)
                    }
                }
            }
        }
        
        private func handleImageScannerMessage(_ body: Any) {
            guard let data = body as? [String: Any],
                  let messageType = data["type"] as? String else { return }
            
            if messageType == "scan" {
                handleImageScanRequest(data)
            }
        }
        
        private func handleImageScanRequest(_ data: [String: Any]) {
            guard let images = data["images"] as? [[String: Any]],
                  let pageUrlString = data["pageUrl"] as? String,
                  URL(string: pageUrlString) != nil else { return }
            
            // Use actual content filter preferences from app state
            let preferences = contentFilterPreferences
            
            Task {
                for imageData in images {
                    guard let imageId = imageData["id"] as? String,
                          let imageSrc = imageData["src"] as? String,
                          let imageURL = URL(string: imageSrc) else { continue }
                    
                    if imageURL.scheme == "data" { continue }
                    
                    let result = await imageFilterService.analyzeImage(url: imageURL, preferences: preferences)
                    
                    if result.shouldFilter {
                        await MainActor.run {
                            self.replaceImageInWebView(imageId: imageId, category: result.category.rawValue)
                        }
                        print("🛡️ Filtered image: \(imageId) - \(result.category.displayName)")
                    } else {
                        await MainActor.run {
                            self.markImageSafe(imageId: imageId)
                        }
                    }
                }
            }
        }
        
        private func replaceImageInWebView(imageId: String, category: String) {
            let script = "window.komalImageScanner && window.komalImageScanner.replaceImage('\(imageId)', '\(category)');"
            webView?.evaluateJavaScript(script, completionHandler: nil)
        }
        
        private func markImageSafe(imageId: String) {
            let script = "window.komalImageScanner && window.komalImageScanner.markSafe('\(imageId)');"
            webView?.evaluateJavaScript(script, completionHandler: nil)
        }
        
        // MARK: - WKNavigationDelegate
        
        // Trusted kid-friendly domains (skip content checks)
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
        
        private func isTrustedDomain(_ url: URL) -> Bool {
            guard let host = url.host?.lowercased() else { return false }
            return trustedDomains.contains(host)
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            
            // Skip content checks for trusted kid-friendly domains
            if isTrustedDomain(url) {
                print("✅ SimpleWebView: Trusted domain - skipping content check: \(url.host ?? "")")
                decisionHandler(.allow)
                return
            }
            
            // DIGITAL GUARDIAN: Check ALL navigations for inappropriate content
            let contentCheck = BrowserState.checkURL(url, parentSettings: parentSettings)
            if contentCheck.shouldIntervene, let trigger = contentCheck.trigger {
                print("🛡️ SimpleWebView blocked navigation: \(trigger.searchTerm)")
                
                // Log the block
                historyService.logBlocked(url: url, category: "Content Filter", reason: "Inappropriate: \(trigger.searchTerm)")
                
                // Notify parent view to show intervention
                DispatchQueue.main.async { [weak self] in
                    self?.onInappropriateContent?(trigger, url)
                }
                
                decisionHandler(.cancel)
                return
            }
            
            // Enable safe search on supported engines
            if let rewritten = rewriteForSafeSearch(url: url), rewritten != url {
                webView.load(URLRequest(url: rewritten))
                decisionHandler(.cancel)
                return
            }
            
            // Handle new window requests
            if navigationAction.targetFrame == nil {
                webView.load(URLRequest(url: url))
                decisionHandler(.cancel)
                return
            }
            
            decisionHandler(.allow)
        }
        
        private func rewriteForSafeSearch(url: URL) -> URL? {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
            let host = components.host?.lowercased() ?? ""
            
            if host.contains("google.") {
                components.queryItems = upsertQueryItem(name: "safe", value: "active", items: components.queryItems)
                return components.url
            }
            
            if host.contains("bing.com") {
                components.queryItems = upsertQueryItem(name: "adlt", value: "strict", items: components.queryItems)
                return components.url
            }
            
            if host.contains("youtube.com") {
                components.queryItems = upsertQueryItem(name: "safe", value: "active", items: components.queryItems)
                return components.url
            }
            
            if host.contains("duckduckgo.com") {
                components.queryItems = upsertQueryItem(name: "kp", value: "1", items: components.queryItems)
                return components.url
            }
            
            return nil
        }
        
        private func upsertQueryItem(name: String, value: String, items: [URLQueryItem]?) -> [URLQueryItem] {
            var updated = items ?? []
            if let index = updated.firstIndex(where: { $0.name == name }) {
                updated[index].value = value
            } else {
                updated.append(URLQueryItem(name: name, value: value))
            }
            return updated
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            // Only update loading if this is a new navigation
            if currentNavigation == nil || currentNavigation != navigation {
                currentNavigation = navigation
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    // Only set to true if not already loading (prevent flickering)
                    if !self.loading {
                        self.loading = true
                        print("🌐 WebView started loading")
                    }
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Only process if this is the navigation we're tracking
            guard currentNavigation == navigation else {
                print("⚠️ Ignoring didFinish for old navigation")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.currentNavigation = nil
                self.loading = false
                print("🌐 WebView finished loading - setting loading to false")
                
                // Log page load event for history tracking
                if let url = webView.url {
                    self.historyService.logPageLoad(url: url, title: webView.title)
                    
                    // Start engagement tracking
                    self.engagementTracker.startEngagement(url: url, pageTitle: webView.title)
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            // Ignore cancelled errors (-999) as they're usually from navigation being cancelled
            if nsError.code == NSURLErrorCancelled {
                print("⚠️ Navigation cancelled (ignoring)")
                return
            }
            
            // Only process if this is the navigation we're tracking
            guard currentNavigation == navigation else {
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.currentNavigation = nil
                self.loading = false
                print("❌ WebView failed to load - setting loading to false: \(error.localizedDescription)")
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            // Ignore cancelled errors (-999) as they're usually from navigation being cancelled
            if nsError.code == NSURLErrorCancelled {
                print("⚠️ Provisional navigation cancelled (ignoring)")
                return
            }
            
            // Only process if this is the navigation we're tracking
            guard currentNavigation == navigation else {
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.currentNavigation = nil
                self.loading = false
                print("❌ WebView provisional navigation failed - setting loading to false: \(error.localizedDescription)")
            }
        }
    }
}
#endif
