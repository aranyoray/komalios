//
//  SimpleWebView.swift
//  Komalios
//
//  WKWebView wrapper with child-safety navigation policy,
//  safe-search enforcement, image filtering, and viewport monitoring.
//
//  Uses UIViewControllerRepresentable (not UIViewRepresentable) so the
//  WKWebView has a proper UIViewController context for keyboard/responder
//  chain management — fixes text input on the iOS Simulator.
//

import SwiftUI
import ObjectiveC

#if os(iOS)
@preconcurrency import WebKit

// MARK: - Safari Browser Navigator

@MainActor
class SafariBrowserNavigator: ObservableObject {
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var currentDisplayURL: URL?
    @Published var pageTitle: String?
    @Published var estimatedProgress: Double = 0

    private var observations: [NSKeyValueObservation] = []

    weak var webView: WKWebView? {
        didSet {
            observations.removeAll()
            guard let webView else { return }

            observations.append(webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] wv, _ in
                DispatchQueue.main.async { self?.canGoBack = wv.canGoBack }
            })
            observations.append(webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] wv, _ in
                DispatchQueue.main.async { self?.canGoForward = wv.canGoForward }
            })
            observations.append(webView.observe(\.url, options: [.initial, .new]) { [weak self] wv, _ in
                DispatchQueue.main.async { self?.currentDisplayURL = wv.url }
            })
            observations.append(webView.observe(\.title, options: [.initial, .new]) { [weak self] wv, _ in
                DispatchQueue.main.async { self?.pageTitle = wv.title }
            })
            observations.append(webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] wv, _ in
                DispatchQueue.main.async { self?.estimatedProgress = wv.estimatedProgress }
            })
        }
    }

    func goBack()      { webView?.goBack() }
    func goForward()   { webView?.goForward() }
    func reload()      { webView?.reload() }
    func stopLoading() { webView?.stopLoading() }
}

// MARK: - WKWebView Keyboard Fix

/// Swizzles WKContentView's _elementDidFocus to force `userIsInteracting = true`,
/// ensuring the keyboard appears when a text field inside WKWebView is tapped.
/// Tries multiple selector variants for iOS 12.2–18.x compatibility.
private var wkKeyboardSwizzleApplied = false

private func applyWKWebViewKeyboardFix() {
    guard !wkKeyboardSwizzleApplied else { return }
    wkKeyboardSwizzleApplied = true

    guard let WKContentView: AnyClass = NSClassFromString("WKContentView") else {
        print("⌨️ KEYBOARD-FIX: WKContentView class NOT found")
        return
    }
    print("⌨️ KEYBOARD-FIX: WKContentView class found")

    // Try selectors from newest to oldest
    let selectors = [
        "_elementDidFocus:userIsInteracting:blurPreviousNode:activityStateChanges:userObject:",
        "_elementDidFocus:userIsInteracting:blurPreviousNode:changingActivityState:userObject:",
        "_startAssistingNode:userIsInteracting:blurPreviousNode:changingActivityState:userObject:",
        "_startAssistingNode:userIsInteracting:blurPreviousNode:userObject:"
    ]

    for selName in selectors {
        let sel = sel_getUid(selName)
        guard let method = class_getInstanceMethod(WKContentView, sel) else {
            print("⌨️ KEYBOARD-FIX: Selector NOT found: \(selName)")
            continue
        }
        print("⌨️ KEYBOARD-FIX: ✅ Matched selector: \(selName)")

        typealias Fn = @convention(c) (Any, Selector, UnsafeRawPointer, Bool, Bool, Bool, Any?) -> Void
        let originalImp = method_getImplementation(method)
        let original: Fn = unsafeBitCast(originalImp, to: Fn.self)

        let block: @convention(block) (Any, UnsafeRawPointer, Bool, Bool, Bool, Any?) -> Void = {
            (me, arg0, _, arg2, arg3, arg4) in
            original(me, sel, arg0, true, arg2, arg3, arg4)
        }

        method_setImplementation(method, imp_implementationWithBlock(block))
        print("⌨️ KEYBOARD-FIX: Swizzle applied successfully")
        return
    }

    print("⌨️ KEYBOARD-FIX: ⚠️ No matching selector found for this iOS version")
}

// MARK: - WebView ViewController

/// Hosts the WKWebView inside a UIViewController so it has a proper
/// responder chain context for keyboard input (especially on Simulator).
final class SimpleWebViewController: UIViewController {
    var webView: WKWebView!

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        applyWKWebViewKeyboardFix()
        guard let webView else { return }
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        webView?.becomeFirstResponder()
    }
}

// MARK: - SimpleWebView

struct SimpleWebView: UIViewControllerRepresentable {
    let url: URL
    @Binding var loading: Bool
    var contentFilterPreferences: ContentFilterPreferences
    var parentSettings: ParentSettings
    var onInappropriateContent: ((KomalInterventionTrigger, URL) -> Void)?
    var onPageFinished: ((URL, String?) -> Void)?
    var onSearchNeedsScan: ((String, URL) -> Void)?
    var navigator: SafariBrowserNavigator?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            loading: $loading,
            contentFilterPreferences: contentFilterPreferences,
            parentSettings: parentSettings,
            onInappropriateContent: onInappropriateContent,
            onPageFinished: onPageFinished,
            onSearchNeedsScan: onSearchNeedsScan
        )
    }

    func makeUIViewController(context: Context) -> SimpleWebViewController {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.defaultWebpagePreferences.preferredContentMode = .mobile

        EngagementTracker.shared.configureMessageHandlers(
            for: config.userContentController,
            handler: context.coordinator
        )

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = false
        webView.scrollView.keyboardDismissMode = .none

        let vc = SimpleWebViewController()
        vc.webView = webView

        context.coordinator.targetURL = url
        context.coordinator.webView = webView
        navigator?.webView = webView

        webView.load(URLRequest(url: url))
        return vc
    }

    func updateUIViewController(_ uiViewController: SimpleWebViewController, context: Context) {
        guard let webView = uiViewController.webView else { return }

        if navigator?.webView !== webView {
            navigator?.webView = webView
        }

        context.coordinator.onInappropriateContent = onInappropriateContent
        context.coordinator.onPageFinished = onPageFinished
        context.coordinator.onSearchNeedsScan = onSearchNeedsScan
        context.coordinator.updatePreferences(
            contentFilter: contentFilterPreferences,
            parent: parentSettings
        )

        // Only reload when URL genuinely changed (both checks prevent loops)
        if webView.url != url && context.coordinator.targetURL != url {
            context.coordinator.targetURL = url
            webView.load(URLRequest(url: url))
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        @Binding var loading: Bool
        var targetURL: URL?
        weak var webView: WKWebView?

        var onInappropriateContent: ((KomalInterventionTrigger, URL) -> Void)?
        var onPageFinished: ((URL, String?) -> Void)?
        var onSearchNeedsScan: ((String, URL) -> Void)?

        private var currentNavigation: WKNavigation?
        private let historyService = BrowsingHistoryService.shared
        private let engagementTracker = EngagementTracker.shared
        private let imageFilterService = ImageFilterService.shared

        private(set) var contentFilterPreferences: ContentFilterPreferences
        private(set) var parentSettings: ParentSettings

        func updatePreferences(contentFilter: ContentFilterPreferences, parent: ParentSettings) {
            contentFilterPreferences = contentFilter
            parentSettings = parent
        }

        init(
            loading: Binding<Bool>,
            contentFilterPreferences: ContentFilterPreferences,
            parentSettings: ParentSettings,
            onInappropriateContent: ((KomalInterventionTrigger, URL) -> Void)?,
            onPageFinished: ((URL, String?) -> Void)?,
            onSearchNeedsScan: ((String, URL) -> Void)?
        ) {
            _loading = loading
            self.contentFilterPreferences = contentFilterPreferences
            self.parentSettings = parentSettings
            self.onInappropriateContent = onInappropriateContent
            self.onPageFinished = onPageFinished
            self.onSearchNeedsScan = onSearchNeedsScan
        }

        // MARK: WKScriptMessageHandler

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            switch message.name {
            case "komalEngagement":
                if let data = message.body as? [String: Any] {
                    let scrollDepth = data["scrollDepthPercent"] as? Int ?? 0
                    let scrollEvents = data["scrollEvents"] as? Int ?? 0
                    engagementTracker.updateEngagement(scrollDepth: scrollDepth, scrollEvents: scrollEvents)
                }

            case "komalImageScanner":
                handleImageScannerMessage(message.body)

            case "komalViewport":
                handleViewportMessage(message.body)

            default:
                break
            }
        }

        // MARK: Viewport Monitoring

        private func handleViewportMessage(_ body: Any) {
            guard let data = body as? [String: Any],
                  let messageType = data["type"] as? String else { return }

            // DEBUG: Handle tap diagnostic messages
            if messageType == "tapdiag" {
                if let msg = data["data"] as? String {
                    print("🔎 TAP-DIAG: \(msg)")
                }
                return
            }

            guard messageType == "snapshot",
                  let snapshot = data["data"] as? [String: Any] else { return }

            let pageUrlString = snapshot["pageUrl"] as? String ?? ""
            guard let pageURL = URL(string: pageUrlString) else { return }

            // Trusted domains skip viewport monitoring entirely
            if Constants.isTrustedDomain(pageURL) { return }

            // 1. JS-flagged keywords (from viewport_tracker.js word-boundary regex)
            if let flaggedKeywords = snapshot["flaggedKeywords"] as? [String],
               let first = flaggedKeywords.first {
                print("🛡️ VIEWPORT FLAGGED CONTENT: \(flaggedKeywords)")
                historyService.logBlocked(url: pageURL, category: "Content Filter", reason: "Viewport content: \(first)")
                DispatchQueue.main.async { [weak self] in
                    self?.onInappropriateContent?(.pageContent(first), pageURL)
                }
                return
            }

            // 2. Visible text checked against BrowserState keyword list
            if let visibleContent = snapshot["visibleContent"] as? [[String: Any]] {
                for item in visibleContent {
                    guard let text = item["text"] as? String, !text.isEmpty else { continue }
                    if let flagged = BrowserState.checkForInappropriateContent(text, isSearchQuery: false) {
                        print("🛡️ VIEWPORT TEXT FLAGGED: \(flagged)")
                        historyService.logBlocked(url: pageURL, category: "Content Filter", reason: "Page content: \(flagged)")
                        DispatchQueue.main.async { [weak self] in
                            self?.onInappropriateContent?(.pageContent(flagged), pageURL)
                        }
                        return
                    }
                }
            }

            // 3. Primary content
            if let primary = snapshot["primaryContent"] as? String, !primary.isEmpty {
                if let flagged = BrowserState.checkForInappropriateContent(primary, isSearchQuery: false) {
                    print("🛡️ PRIMARY CONTENT FLAGGED: \(flagged)")
                    historyService.logBlocked(url: pageURL, category: "Content Filter", reason: "Primary content: \(flagged)")
                    DispatchQueue.main.async { [weak self] in
                        self?.onInappropriateContent?(.pageContent(flagged), pageURL)
                    }
                }
            }
        }

        // MARK: Image Scanning

        private func handleImageScannerMessage(_ body: Any) {
            guard let data = body as? [String: Any],
                  (data["type"] as? String) == "scan" else { return }
            handleImageScanRequest(data)
        }

        private func handleImageScanRequest(_ data: [String: Any]) {
            guard let images = data["images"] as? [[String: Any]],
                  let pageUrlString = data["pageUrl"] as? String,
                  URL(string: pageUrlString) != nil else { return }

            let preferences = contentFilterPreferences

            Task {
                await withTaskGroup(of: Void.self) { group in
                    for imageData in images {
                        guard let imageId = imageData["id"] as? String,
                              let imageSrc = imageData["src"] as? String else { continue }

                        group.addTask { [weak self] in
                            guard let self else { return }

                            guard let imageURL = URL(string: imageSrc) else {
                                await MainActor.run {
                                    self.replaceImageInWebView(imageId: imageId, category: "unknown")
                                }
                                return
                            }

                            let result = await self.imageFilterService.analyzeImage(
                                url: imageURL, preferences: preferences
                            )

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
            }
        }

        private func escapeJSString(_ str: String) -> String {
            str.replacingOccurrences(of: "\\", with: "\\\\")
               .replacingOccurrences(of: "'", with: "\\'")
               .replacingOccurrences(of: "\n", with: "\\n")
               .replacingOccurrences(of: "\r", with: "\\r")
        }

        private func replaceImageInWebView(imageId: String, category: String) {
            let safeId = escapeJSString(imageId)
            let safeCat = escapeJSString(category)
            let js = "window.komalImageScanner && window.komalImageScanner.replaceImage('\(safeId)', '\(safeCat)');"
            webView?.evaluateJavaScript(js) { _, error in
                #if DEBUG
                if let error { print("🛡️ JS bridge replaceImage error: \(error)") }
                #endif
            }
        }

        private func markImageSafe(imageId: String) {
            let safeId = escapeJSString(imageId)
            let js = "window.komalImageScanner && window.komalImageScanner.markSafe('\(safeId)');"
            webView?.evaluateJavaScript(js) { _, error in
                #if DEBUG
                if let error { print("🛡️ JS bridge markSafe error: \(error)") }
                #endif
            }
        }

        // MARK: Navigation Policy

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            // Back/forward: allow without rewrites
            if navigationAction.navigationType == .backForward {
                decisionHandler(.allow)
                return
            }

            // --- Trusted domains ---
            if Constants.isTrustedDomain(url) {
                // Still check search keywords on trusted domains
                if let query = BrowserState.extractSearchQuery(from: url) {
                    if let flagged = BrowserState.checkForInappropriateContent(query, isSearchQuery: true) {
                        print("🛡️ SimpleWebView: Blocked search on trusted domain: \(flagged)")
                        historyService.logBlocked(url: url, category: "Content Filter", reason: "Search query: \(flagged)")
                        DispatchQueue.main.async { [weak self] in
                            self?.onInappropriateContent?(.searchQuery(flagged), url)
                        }
                        decisionHandler(.cancel)
                        return
                    }

                    // User-initiated searches: background cloud scan while SafeSearch loads
                    if navigationAction.navigationType == .formSubmitted ||
                       navigationAction.navigationType == .linkActivated {
                        print("🔍 SimpleWebView: Background cloud scan for search: \(query)")
                        DispatchQueue.main.async { [weak self] in
                            self?.onSearchNeedsScan?(query, url)
                        }
                    }
                }
                print("✅ SimpleWebView: Trusted domain - skipping content check: \(url.host ?? "")")
                decisionHandler(.allow)
                return
            }

            // --- Blocked platforms ---
            if Constants.isBlockedPlatform(url) {
                let host = url.host ?? "unknown"
                let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true

                if isMainFrame {
                    print("🛡️ SimpleWebView blocked platform: \(host)")
                    historyService.logBlocked(url: url, category: "Platform Block", reason: "Blocked platform: \(host)")
                    DispatchQueue.main.async { [weak self] in
                        self?.onInappropriateContent?(.urlKeyword(host), url)
                    }
                } else {
                    print("🛡️ SimpleWebView silently blocked subframe from: \(host)")
                }

                decisionHandler(.cancel)
                return
            }

            // --- BrowserState keyword / host check ---
            let contentCheck = BrowserState.checkURL(url, parentSettings: parentSettings)
            if contentCheck.shouldIntervene, let trigger = contentCheck.trigger {
                print("🛡️ SimpleWebView blocked navigation: \(trigger.searchTerm)")
                historyService.logBlocked(url: url, category: "Content Filter", reason: "Inappropriate: \(trigger.searchTerm)")
                DispatchQueue.main.async { [weak self] in
                    self?.onInappropriateContent?(trigger, url)
                }
                decisionHandler(.cancel)
                return
            }

            // --- Safe search rewrite ---
            if let rewritten = rewriteForSafeSearch(url: url) {
                webView.load(URLRequest(url: rewritten))
                decisionHandler(.cancel)
                return
            }

            // --- New-window requests (target frame nil) ---
            if navigationAction.targetFrame == nil {
                webView.load(URLRequest(url: url))
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        // MARK: Safe Search

        private func rewriteForSafeSearch(url: URL) -> URL? {
            guard parentSettings.safeSearchEnabled else { return nil }
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }

            let host = components.host?.lowercased() ?? ""
            let paramName: String
            let paramValue: String

            if host.contains("google.") {
                paramName = "safe"; paramValue = "active"
            } else if host.contains("bing.com") {
                paramName = "adlt"; paramValue = "strict"
            } else if host.contains("duckduckgo.com") {
                paramName = "kp"; paramValue = "1"
            } else {
                return nil
            }

            // Already correct — no rewrite needed
            if let existing = components.queryItems?.first(where: { $0.name == paramName }),
               existing.value == paramValue {
                return nil
            }

            var items = components.queryItems ?? []
            if let idx = items.firstIndex(where: { $0.name == paramName }) {
                items[idx].value = paramValue
            } else {
                items.append(URLQueryItem(name: paramName, value: paramValue))
            }
            components.queryItems = items
            return components.url
        }

        // MARK: Navigation Lifecycle

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            if currentNavigation == nil || currentNavigation != navigation {
                currentNavigation = navigation
                DispatchQueue.main.async { [weak self] in
                    guard let self, !self.loading else { return }
                    self.loading = true
                    print("🌐 WebView started loading")
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard currentNavigation == navigation else {
                print("⚠️ Ignoring didFinish for old navigation")
                return
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.currentNavigation = nil
                self.loading = false
                print("🌐 WebView finished loading - setting loading to false")

                // Nudge responder chain so WKWebView can accept keyboard input
                webView.becomeFirstResponder()

                if let url = webView.url {
                    self.historyService.logPageLoad(url: url, title: webView.title)
                    self.engagementTracker.startEngagement(url: url, pageTitle: webView.title)
                    self.onPageFinished?(url, webView.title)
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code == NSURLErrorCancelled {
                print("⚠️ Navigation cancelled (ignoring)")
                return
            }
            guard currentNavigation == navigation else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.currentNavigation = nil
                self.loading = false
                print("❌ WebView failed to load - setting loading to false: \(error.localizedDescription)")
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code == NSURLErrorCancelled {
                print("⚠️ Provisional navigation cancelled (ignoring)")
                return
            }
            guard currentNavigation == navigation else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.currentNavigation = nil
                self.loading = false
                print("❌ WebView provisional navigation failed - setting loading to false: \(error.localizedDescription)")
            }
        }
    }
}
#endif
