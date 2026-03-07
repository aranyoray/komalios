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
        #if DEBUG
        print("⌨️ KEYBOARD-FIX: WKContentView class NOT found")
        #endif
        return
    }
    #if DEBUG
    print("⌨️ KEYBOARD-FIX: WKContentView class found")
    #endif

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
            #if DEBUG
            print("⌨️ KEYBOARD-FIX: Selector NOT found: \(selName)")
            #endif
            continue
        }
        #if DEBUG
        print("⌨️ KEYBOARD-FIX: ✅ Matched selector: \(selName)")
        #endif

        typealias Fn = @convention(c) (Any, Selector, UnsafeRawPointer, Bool, Bool, Bool, Any?) -> Void
        let originalImp = method_getImplementation(method)
        let original: Fn = unsafeBitCast(originalImp, to: Fn.self)

        let block: @convention(block) (Any, UnsafeRawPointer, Bool, Bool, Bool, Any?) -> Void = {
            (me, arg0, _, arg2, arg3, arg4) in
            original(me, sel, arg0, true, arg2, arg3, arg4)
        }

        method_setImplementation(method, imp_implementationWithBlock(block))
        #if DEBUG
        print("⌨️ KEYBOARD-FIX: Swizzle applied successfully")
        #endif
        return
    }

    #if DEBUG
    print("⌨️ KEYBOARD-FIX: ⚠️ No matching selector found for this iOS version")
    #endif
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
    var ageGroup: AgeGroup = .under10
    var onInappropriateContent: ((KomalInterventionTrigger, URL) -> Void)?
    var onPageFinished: ((URL, String?) -> Void)?
    var onSearchNeedsScan: ((String, URL) -> Void)?
    var navigator: SafariBrowserNavigator?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            loading: $loading,
            contentFilterPreferences: contentFilterPreferences,
            parentSettings: parentSettings,
            ageGroup: ageGroup,
            onInappropriateContent: onInappropriateContent,
            onPageFinished: onPageFinished,
            onSearchNeedsScan: onSearchNeedsScan
        )
    }

    func makeUIViewController(context: Context) -> SimpleWebViewController {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        // Require user gesture to play audio/video — prevents autoplay of unscanned media
        config.mediaTypesRequiringUserActionForPlayback = .all
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

        // Inject YouTube restricted mode cookie
        // Do NOT set HttpOnly — the JS enforcer in youtube_scanner.js needs
        // to read this cookie via document.cookie to maintain restricted mode.
        let ytCookie = HTTPCookie(properties: [
            .domain: ".youtube.com",
            .path: "/",
            .name: "PREF",
            .value: "f2=8000000",
            .secure: "TRUE",
            .expires: Date.distantFuture
        ])
        if let ytCookie {
            webView.configuration.websiteDataStore.httpCookieStore.setCookie(ytCookie)
        }

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
            parent: parentSettings,
            age: ageGroup
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
        private(set) var ageGroup: AgeGroup

        func updatePreferences(contentFilter: ContentFilterPreferences, parent: ParentSettings, age: AgeGroup) {
            contentFilterPreferences = contentFilter
            parentSettings = parent
            ageGroup = age
        }

        init(
            loading: Binding<Bool>,
            contentFilterPreferences: ContentFilterPreferences,
            parentSettings: ParentSettings,
            ageGroup: AgeGroup = .under10,
            onInappropriateContent: ((KomalInterventionTrigger, URL) -> Void)?,
            onPageFinished: ((URL, String?) -> Void)?,
            onSearchNeedsScan: ((String, URL) -> Void)?
        ) {
            _loading = loading
            self.contentFilterPreferences = contentFilterPreferences
            self.parentSettings = parentSettings
            self.ageGroup = ageGroup
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

            case "komalYouTubeScanner":
                handleYouTubeScannerMessage(message.body)

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
                    #if DEBUG
                    print("🔎 TAP-DIAG: \(msg)")
                    #endif
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
                #if DEBUG
                print("🛡️ VIEWPORT FLAGGED CONTENT: \(flaggedKeywords)")
                #endif
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
                        #if DEBUG
                        print("🛡️ VIEWPORT TEXT FLAGGED: \(flagged)")
                        #endif
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
                    #if DEBUG
                    print("🛡️ PRIMARY CONTENT FLAGGED: \(flagged)")
                    #endif
                    historyService.logBlocked(url: pageURL, category: "Content Filter", reason: "Primary content: \(flagged)")
                    DispatchQueue.main.async { [weak self] in
                        self?.onInappropriateContent?(.pageContent(flagged), pageURL)
                    }
                }
            }
        }

        // MARK: YouTube Video Scanning

        private func handleYouTubeScannerMessage(_ body: Any) {
            guard let data = body as? [String: Any],
                  let messageType = data["type"] as? String,
                  messageType == "videoDetected" else { return }

            guard let videoId = data["videoId"] as? String, !videoId.isEmpty,
                  videoId.range(of: "^[a-zA-Z0-9_-]{6,20}$", options: .regularExpression) != nil else { return }

            // Truncate all untrusted string inputs to prevent memory pressure
            let title = String((data["title"] as? String ?? "").prefix(500))
            let description = String((data["description"] as? String ?? "").prefix(5000))
            let channelName = String((data["channelName"] as? String ?? "").prefix(200))
            let thumbnailUrl = String((data["thumbnailUrl"] as? String ?? "").prefix(500))
            let pageUrl = String((data["pageUrl"] as? String ?? "").prefix(500))

            #if DEBUG
            print("🎬 YouTube video detected: \(videoId) - \(title)")
            #endif

            let metadata = YouTubeContentAnalyzer.VideoMetadata(
                videoId: videoId,
                title: title,
                description: description,
                channelName: channelName,
                thumbnailUrl: thumbnailUrl
            )

            let currentAgeGroup = ageGroup
            let currentParentSettings = parentSettings
            let currentFilterPreferences = contentFilterPreferences

            Task { [weak self] in
                guard let self else { return }

                let decision = await YouTubeContentAnalyzer.shared.analyzeVideo(
                    metadata,
                    ageGroup: currentAgeGroup,
                    parentSettings: currentParentSettings,
                    filterPreferences: currentFilterPreferences
                )

                await MainActor.run {
                    let nonce = self.escapeJSString(EngagementTracker.shared.youtubeNonce)

                    switch decision {
                    case .allow:
                        #if DEBUG
                        print("✅ YouTube video allowed: \(videoId)")
                        #endif
                        let js = "window.komalYouTubeScanner && window.komalYouTubeScanner.allowVideo('\(self.escapeJSString(videoId))', '\(nonce)');"
                        self.webView?.evaluateJavaScript(js)

                    case .block(let reason, let category):
                        #if DEBUG
                        print("🛡️ YouTube video blocked: \(videoId) - \(reason)")
                        #endif
                        let safeReason = self.escapeJSString(reason)
                        let js = "window.komalYouTubeScanner && window.komalYouTubeScanner.blockVideo('\(self.escapeJSString(videoId))', '\(safeReason)', '\(nonce)');"
                        self.webView?.evaluateJavaScript(js)

                        // Log the block (but don't trigger onInappropriateContent — the JS
                        // scanner handles the UX by showing a blocked overlay and navigating
                        // back within YouTube. Calling onInappropriateContent would destroy
                        // the WebView and conflict with the JS-side history.back().)
                        if let videoURL = URL(string: pageUrl.isEmpty ? "https://www.youtube.com/watch?v=\(videoId)" : pageUrl) {
                            self.historyService.logBlocked(url: videoURL, category: category, reason: reason)
                        }
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

            Task { [weak self] in
                guard let self else { return }
                let maxConcurrent = 5
                for batch in stride(from: 0, to: images.count, by: maxConcurrent) {
                    let batchEnd = min(batch + maxConcurrent, images.count)
                    let batchImages = Array(images[batch..<batchEnd])

                    await withTaskGroup(of: Void.self) { group in
                        for imageData in batchImages {
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

                                // Timeout: fail-closed after 5s (v2 §4)
                                let result = await withTaskGroup(of: ImageAnalysisResult?.self) { tg -> ImageAnalysisResult? in
                                    tg.addTask {
                                        await self.imageFilterService.analyzeImage(url: imageURL, preferences: preferences)
                                    }
                                    tg.addTask {
                                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                                        return nil
                                    }
                                    let first = await tg.next() ?? nil
                                    tg.cancelAll()
                                    return first
                                }

                                if let result, !result.shouldFilter {
                                    await MainActor.run {
                                        self.markImageSafe(imageId: imageId)
                                    }
                                } else {
                                    let cat = result?.category.rawValue ?? "timeout"
                                    await MainActor.run {
                                        self.replaceImageInWebView(imageId: imageId, category: cat)
                                    }
                                    if let result {
                                        #if DEBUG
                                        print("🛡️ Filtered image: \(imageId) - \(result.category.displayName)")
                                        #endif
                                    } else {
                                        #if DEBUG
                                        print("🛡️ Image scan timeout (fail-closed): \(imageId)")
                                        #endif
                                    }
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
               .replacingOccurrences(of: "\"", with: "\\\"")
               .replacingOccurrences(of: "`", with: "\\`")
               .replacingOccurrences(of: "\n", with: "\\n")
               .replacingOccurrences(of: "\r", with: "\\r")
               .replacingOccurrences(of: "\0", with: "")
               .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
               .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
        }

        private func replaceImageInWebView(imageId: String, category: String) {
            let safeId = escapeJSString(imageId)
            let safeCat = escapeJSString(category)
            let nonce = escapeJSString(EngagementTracker.shared.imageScannerNonce)
            let js = "window.komalImageScanner && window.komalImageScanner.replaceImage('\(safeId)', '\(safeCat)', '\(nonce)');"
            webView?.evaluateJavaScript(js) { _, error in
                #if DEBUG
                if let error { print("🛡️ JS bridge replaceImage error: \(error)") }
                #endif
            }
        }

        private func markImageSafe(imageId: String) {
            let safeId = escapeJSString(imageId)
            let nonce = escapeJSString(EngagementTracker.shared.imageScannerNonce)
            let js = "window.komalImageScanner && window.komalImageScanner.markSafe('\(safeId)', '\(nonce)');"
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

            // --- Scheme allowlist: only allow http/https ---
            // Blocks javascript:, data:text/html, blob: navigations that bypass content filtering
            guard let scheme = url.scheme?.lowercased(), ["https", "http"].contains(scheme) else {
                #if DEBUG
                print("🛡️ SimpleWebView: Blocked non-http(s) scheme: \(url.scheme ?? "nil")")
                #endif
                decisionHandler(.cancel)
                return
            }

            // Back/forward: apply blocked platform and keyword checks
            if navigationAction.navigationType == .backForward {
                if Constants.isBlockedPlatform(url) {
                    let host = url.host ?? "unknown"
                    #if DEBUG
                    print("🛡️ SimpleWebView: Blocked back/forward to: \(host)")
                    #endif
                    historyService.logBlocked(url: url, category: "Platform Block", reason: "Back/forward to blocked platform: \(host)")
                    DispatchQueue.main.async { [weak self] in
                        self?.onInappropriateContent?(.urlKeyword(host), url)
                    }
                    decisionHandler(.cancel)
                    return
                }
                let contentCheck = BrowserState.checkURL(url, parentSettings: parentSettings)
                if contentCheck.shouldIntervene, let trigger = contentCheck.trigger {
                    #if DEBUG
                    print("🛡️ SimpleWebView: Blocked back/forward navigation: \(trigger.searchTerm)")
                    #endif
                    historyService.logBlocked(url: url, category: "Content Filter", reason: "Back/forward: \(trigger.searchTerm)")
                    DispatchQueue.main.async { [weak self] in
                        self?.onInappropriateContent?(trigger, url)
                    }
                    decisionHandler(.cancel)
                    return
                }
                decisionHandler(.allow)
                return
            }

            // --- Trusted domains ---
            if Constants.isTrustedDomain(url) {
                // Still check search keywords on trusted domains
                if let query = BrowserState.extractSearchQuery(from: url) {
                    if let flagged = BrowserState.checkForInappropriateContent(query, isSearchQuery: true) {
                        #if DEBUG
                        print("🛡️ SimpleWebView: Blocked search on trusted domain: \(flagged)")
                        #endif
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
                        #if DEBUG
                        print("🔍 SimpleWebView: Background cloud scan for search: \(query)")
                        #endif
                        DispatchQueue.main.async { [weak self] in
                            self?.onSearchNeedsScan?(query, url)
                        }
                    }
                }
                #if DEBUG
                print("✅ SimpleWebView: Trusted domain - skipping content check: \(url.host ?? "")")
                #endif
                decisionHandler(.allow)
                return
            }

            // --- YouTube: allow navigation, per-video analysis handled by JS scanner ---
            if Constants.isYouTubeDomain(url) {
                // Still check search keywords
                if let query = BrowserState.extractSearchQuery(from: url) {
                    if let flagged = BrowserState.checkForInappropriateContent(query, isSearchQuery: true) {
                        #if DEBUG
                        print("🛡️ SimpleWebView: Blocked YouTube search: \(flagged)")
                        #endif
                        historyService.logBlocked(url: url, category: "Content Filter", reason: "YouTube search: \(flagged)")
                        DispatchQueue.main.async { [weak self] in
                            self?.onInappropriateContent?(.searchQuery(flagged), url)
                        }
                        decisionHandler(.cancel)
                        return
                    }
                }
                // Re-inject restricted mode cookie on each YouTube navigation
                // (YouTube may overwrite the PREF cookie during browsing)
                self.reinjectYouTubeRestrictedModeCookie(webView)
                #if DEBUG
                print("✅ SimpleWebView: YouTube domain - per-video JS analysis: \(url.host ?? "")")
                #endif
                decisionHandler(.allow)
                return
            }

            // --- Blocked platforms ---
            if Constants.isBlockedPlatform(url) {
                let host = url.host ?? "unknown"
                let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true

                if isMainFrame {
                    #if DEBUG
                    print("🛡️ SimpleWebView blocked platform: \(host)")
                    #endif
                    historyService.logBlocked(url: url, category: "Platform Block", reason: "Blocked platform: \(host)")
                    DispatchQueue.main.async { [weak self] in
                        self?.onInappropriateContent?(.urlKeyword(host), url)
                    }
                } else {
                    #if DEBUG
                    print("🛡️ SimpleWebView silently blocked subframe from: \(host)")
                    #endif
                }

                decisionHandler(.cancel)
                return
            }

            // --- BrowserState keyword / host check ---
            let contentCheck = BrowserState.checkURL(url, parentSettings: parentSettings)
            if contentCheck.shouldIntervene, let trigger = contentCheck.trigger {
                #if DEBUG
                print("🛡️ SimpleWebView blocked navigation: \(trigger.searchTerm)")
                #endif
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
            // Apply content checks — window.open() must not bypass filtering
            if navigationAction.targetFrame == nil {
                if Constants.isBlockedPlatform(url) {
                    let host = url.host ?? "unknown"
                    #if DEBUG
                    print("🛡️ SimpleWebView: Blocked new-window to: \(host)")
                    #endif
                    historyService.logBlocked(url: url, category: "Platform Block", reason: "New window to blocked platform: \(host)")
                    DispatchQueue.main.async { [weak self] in
                        self?.onInappropriateContent?(.urlKeyword(host), url)
                    }
                    decisionHandler(.cancel)
                    return
                }
                let newWinCheck = BrowserState.checkURL(url, parentSettings: parentSettings)
                if newWinCheck.shouldIntervene, let trigger = newWinCheck.trigger {
                    #if DEBUG
                    print("🛡️ SimpleWebView: Blocked new-window navigation: \(trigger.searchTerm)")
                    #endif
                    historyService.logBlocked(url: url, category: "Content Filter", reason: "New window: \(trigger.searchTerm)")
                    DispatchQueue.main.async { [weak self] in
                        self?.onInappropriateContent?(trigger, url)
                    }
                    decisionHandler(.cancel)
                    return
                }
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
                // YouTube restricted mode is cookie-based (PREF cookie), not URL param
                // so we don't add safe=active for YouTube — it has no effect
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

        // MARK: YouTube Restricted Mode

        private func reinjectYouTubeRestrictedModeCookie(_ webView: WKWebView) {
            let cookie = HTTPCookie(properties: [
                .domain: ".youtube.com",
                .path: "/",
                .name: "PREF",
                .value: "f2=8000000",
                .secure: "TRUE",
                .expires: Date.distantFuture
            ])
            if let cookie {
                webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
            }
        }

        // MARK: Navigation Lifecycle

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            if currentNavigation == nil || currentNavigation != navigation {
                currentNavigation = navigation
                DispatchQueue.main.async { [weak self] in
                    guard let self, !self.loading else { return }
                    self.loading = true
                    #if DEBUG
                    print("🌐 WebView started loading")
                    #endif
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard currentNavigation == navigation else {
                #if DEBUG
                print("⚠️ Ignoring didFinish for old navigation")
                #endif
                return
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.currentNavigation = nil
                self.loading = false
                #if DEBUG
                print("🌐 WebView finished loading - setting loading to false")
                #endif

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
                #if DEBUG
                print("⚠️ Navigation cancelled (ignoring)")
                #endif
                return
            }
            guard currentNavigation == navigation else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.currentNavigation = nil
                self.loading = false
                #if DEBUG
                print("❌ WebView failed to load - setting loading to false: \(error.localizedDescription)")
                #endif
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code == NSURLErrorCancelled {
                #if DEBUG
                print("⚠️ Provisional navigation cancelled (ignoring)")
                #endif
                return
            }
            guard currentNavigation == navigation else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.currentNavigation = nil
                self.loading = false
                #if DEBUG
                print("❌ WebView provisional navigation failed - setting loading to false: \(error.localizedDescription)")
                #endif
            }
        }
    }
}
#endif
