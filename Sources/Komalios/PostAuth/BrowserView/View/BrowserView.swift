#if os(iOS)
import SwiftUI
@preconcurrency import WebKit

struct BrowserView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var browserState = BrowserState()
    @State private var hasLoadedInitial = false

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: 8) {
                AddressBar(urlString: $browserState.urlString) {
                    // Just navigate - content filtering happens in WKNavigationDelegate
                    browserState.currentURL = normalizedURL(from: browserState.urlString)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                ZStack {
                    WebView(
                        url: browserState.currentURL,
                        browserState: browserState,
                        appState: appState
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    if browserState.loading {
                        PlayfulLoadingView()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            // Start browsing session
            BrowsingHistoryService.shared.startSession()
            
            // Auto-load default URL on first appearance
            if !hasLoadedInitial {
                browserState.currentURL = normalizedURL(from: browserState.urlString)
                hasLoadedInitial = true
            }
        }
        .onDisappear {
            // End browsing session when leaving browser
            BrowsingHistoryService.shared.endSession()
        }
        .sheet(isPresented: $browserState.showGate) {
            GateView(category: browserState.category)
                .environmentObject(appState)
        }
        .fullScreenCover(isPresented: $browserState.showBlocked) {
            BlockedView(category: browserState.category, reason: browserState.blockReason)
        }
        .sheet(isPresented: $browserState.showPastTabs) {
            PastTabsView(browserState: browserState)
        }
        .fullScreenCover(isPresented: $browserState.showKomalIntervention) {
            if let trigger = browserState.interventionTrigger {
                KomalInterventionView(
                    trigger: trigger,
                    onReflectionTime: {
                        // Log the reflection and allow continuing with safe search
                        print("🌸 Child completed reflection time")
                        browserState.clearIntervention()
                        // Redirect to a safe search or home
                        browserState.currentURL = URL(string: "https://www.khanacademy.org")
                    },
                    onGoBack: {
                        print("🌸 Child chose to go back")
                        browserState.clearIntervention()
                        // Go back to safe page
                        browserState.currentURL = URL(string: "https://www.khanacademy.org")
                    },
                    onContinueAnyway: nil  // Don't allow continue for now
                )
            }
        }
    }

    private func normalizedURL(from input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If it looks like a URL (has scheme), use it
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        
        // If it looks like a domain (contains .), treat as URL
        if trimmed.contains(".") && !trimmed.contains(" ") {
            return URL(string: "https://\(trimmed)")
        }
        
        // Otherwise it's a search - create Google search URL
        if let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            return URL(string: "https://www.google.com/search?q=\(encoded)&safe=active")
        }
        
        return URL(string: "https://\(trimmed)")
    }
}

struct AddressBar: View {
    @Binding var urlString: String
    var onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(KomalColors.pearlAqua)

            TextField("Search or enter address", text: $urlString)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .foregroundColor(KomalColors.textPrimary)
                .onSubmit(onSubmit)

            Button(action: onSubmit) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(KomalColors.bubblegumPink)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Capsule().fill(KomalColors.white))
        .overlay(
            Capsule()
                .stroke(KomalColors.bubblegumPink, lineWidth: 2)
        )
    }
}

struct WebView: UIViewRepresentable {
    let url: URL?
    let browserState: BrowserState
    let appState: AppState

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.defaultWebpagePreferences.preferredContentMode = .mobile
        
        // Digital Guardian Enhancement: Configure content controller with scripts
        let contentController = config.userContentController
        EngagementTracker.shared.configureMessageHandlers(for: contentController, handler: context.coordinator)
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = false
        
        // Store webView reference in coordinator for JavaScript calls
        context.coordinator.webView = webView
        
        if let url {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let url else { return }
        if uiView.url != url {
            // Track navigation type
            let isBack = uiView.canGoBack && uiView.backForwardList.backItem?.url == url
            let isForward = uiView.canGoForward && uiView.backForwardList.forwardItem?.url == url
            context.coordinator.pendingNavigationType = (isBack: isBack, isForward: isForward)
            
            uiView.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(browserState: browserState, appState: appState)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        private let blocklist = BlocklistService.shared
        private let historyService = BrowsingHistoryService.shared
        private let engagementTracker = EngagementTracker.shared
        private let imageFilterService = ImageFilterService.shared
        private let contentAnalyzer = ContentAnalyzerService.shared
        private let browserState: BrowserState
        private let appState: AppState
        
        // Digital Guardian Enhancement: Track navigation context
        weak var webView: WKWebView?
        var pendingNavigationType: (isBack: Bool, isForward: Bool) = (false, false)
        private var currentPageURL: URL?
        private var navigationDepth = 0

        init(browserState: BrowserState, appState: AppState) {
            self.browserState = browserState
            self.appState = appState
        }
        
        // MARK: - WKScriptMessageHandler
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "komalEngagement":
                handleEngagementMessage(message.body)
            case "komalImageScanner":
                handleImageScannerMessage(message.body)
            case "komalViewport":
                handleViewportMessage(message.body)
            default:
                break
            }
        }
        
        private func handleEngagementMessage(_ body: Any) {
            guard let data = body as? [String: Any] else { return }
            
            let scrollDepth = data["scrollDepthPercent"] as? Int ?? 0
            let scrollEvents = data["scrollEvents"] as? Int ?? 0
            let dwellTimeMs = data["dwellTimeMs"] as? Int
            
            // Update engagement tracker
            engagementTracker.updateEngagement(
                scrollDepth: scrollDepth,
                scrollEvents: scrollEvents,
                dwellTimeMs: dwellTimeMs
            )
            
            // Update history service
            historyService.updateCurrentEventEngagement(
                scrollDepth: scrollDepth,
                scrollEvents: scrollEvents,
                dwellTimeSeconds: dwellTimeMs.map { TimeInterval($0) / 1000.0 }
            )
            
            print("🛡️ Engagement: \(scrollDepth)% scroll, \(scrollEvents) events")
        }
        
        private func handleImageScannerMessage(_ body: Any) {
            guard let data = body as? [String: Any],
                  let messageType = data["type"] as? String else { return }
            
            switch messageType {
            case "scan":
                handleImageScanRequest(data)
            case "stats":
                handleImageStats(data)
            default:
                break
            }
        }
        
        private func handleImageScanRequest(_ data: [String: Any]) {
            guard let images = data["images"] as? [[String: Any]],
                  let pageUrlString = data["pageUrl"] as? String,
                  let pageURL = URL(string: pageUrlString) else { return }
            
            let preferences = appState.contentFilterPreferences
            
            // Process images asynchronously
            Task {
                for imageData in images {
                    guard let imageId = imageData["id"] as? String,
                          let imageSrc = imageData["src"] as? String,
                          let imageURL = URL(string: imageSrc) else { continue }
                    
                    // Skip data URLs
                    if imageURL.scheme == "data" { continue }
                    
                    // Analyze image
                    let result = await imageFilterService.analyzeImage(url: imageURL, preferences: preferences)
                    
                    // Update engagement tracker
                    engagementTracker.recordScannedImages(count: 1)
                    
                    if result.shouldFilter {
                        // Tell JavaScript to replace the image
                        await MainActor.run {
                            self.replaceImageInWebView(imageId: imageId, category: result.category.rawValue)
                        }
                        
                        // Log filter event
                        let filterEvent = result.toFilterEvent(pageURL: pageURL)
                        historyService.logImageFiltered(event: filterEvent)
                        engagementTracker.recordFilteredImage(category: result.category.rawValue)
                        
                        print("🛡️ Filtered image: \(imageId) - \(result.category.displayName) (\(result.confidencePercentage))")
                    } else {
                        // Mark as safe
                        await MainActor.run {
                            self.markImageSafe(imageId: imageId)
                        }
                    }
                }
            }
        }
        
        private func handleImageStats(_ data: [String: Any]) {
            guard let stats = data["stats"] as? [String: Any] else { return }
            let scanned = stats["scanned"] as? Int ?? 0
            let filtered = stats["filtered"] as? Int ?? 0
            print("🛡️ Image stats - Scanned: \(scanned), Filtered: \(filtered)")
        }
        
        private func handleViewportMessage(_ body: Any) {
            guard let data = body as? [String: Any],
                  let messageType = data["type"] as? String else { return }
            
            switch messageType {
            case "snapshot":
                handleViewportSnapshot(data)
            default:
                break
            }
        }
        
        private func handleViewportSnapshot(_ data: [String: Any]) {
            guard let snapshotData = data["data"] as? [String: Any],
                  let pageUrlString = snapshotData["pageUrl"] as? String,
                  let pageURL = URL(string: pageUrlString) else { return }
            
            // Process viewport snapshot
            contentAnalyzer.processViewportSnapshot(snapshotData, pageURL: pageURL)
            
            // Log if there are flagged keywords
            if let flaggedKeywords = snapshotData["flaggedKeywords"] as? [String], !flaggedKeywords.isEmpty {
                print("🔍 Viewport flagged content: \(flaggedKeywords.joined(separator: ", "))")
            }
            
            // Log visible content summary
            if let visibleContent = snapshotData["visibleContent"] as? [[String: Any]] {
                let headings = visibleContent.filter { ($0["contentType"] as? String) == "heading" }.count
                let paragraphs = visibleContent.filter { ($0["contentType"] as? String) == "paragraph" }.count
                let images = snapshotData["visibleImageCount"] as? Int ?? 0
                let videos = snapshotData["visibleVideoCount"] as? Int ?? 0
                
                if headings > 0 || paragraphs > 0 || images > 0 || videos > 0 {
                    print("🔍 Viewport: \(headings) headings, \(paragraphs) paragraphs, \(images) images, \(videos) videos")
                }
            }
        }
        
        private func replaceImageInWebView(imageId: String, category: String) {
            let script = "window.komalImageScanner && window.komalImageScanner.replaceImage('\(imageId)', '\(category)');"
            webView?.evaluateJavaScript(script) { _, error in
                if let error = error {
                    print("🛡️ Failed to replace image: \(error)")
                }
            }
        }
        
        private func markImageSafe(imageId: String) {
            let script = "window.komalImageScanner && window.komalImageScanner.markSafe('\(imageId)');"
            webView?.evaluateJavaScript(script, completionHandler: nil)
        }
        
        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            browserState.loading = true
            
            // End engagement for previous page
            if currentPageURL != nil {
                engagementTracker.endCurrentEngagement(exitURL: webView.url)
                // Finalize content tracking for previous page
                contentAnalyzer.finalizeCurrentPage()
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            browserState.loading = false
            browserState.currentURL = webView.url
            browserState.showGate = false
            
            if let url = webView.url {
                browserState.addToHistory(url)
                
                // Digital Guardian Enhancement: Start engagement tracking
                let isBack = pendingNavigationType.isBack
                let isForward = pendingNavigationType.isForward
                
                engagementTracker.startEngagement(
                    url: url,
                    pageTitle: webView.title,
                    wasBackNavigation: isBack,
                    wasForwardNavigation: isForward
                )
                
                // Start content tracking for viewport monitoring
                contentAnalyzer.startPageTracking(url: url, title: webView.title)
                
                // Update navigation depth
                if isBack {
                    navigationDepth = max(0, navigationDepth - 1)
                } else if !isForward {
                    navigationDepth += 1
                }
                
                // Log page load event with navigation context
                historyService.logPageLoad(
                    url: url,
                    title: webView.title,
                    referrerURL: currentPageURL,
                    wasBackNavigation: isBack,
                    wasForwardNavigation: isForward,
                    navigationDepth: navigationDepth
                )
                
                currentPageURL = url
                pendingNavigationType = (false, false)
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            
            // Track navigation type from navigation action
            if navigationAction.navigationType == .backForward {
                if let backItem = webView.backForwardList.backItem, backItem.url == url {
                    pendingNavigationType = (isBack: true, isForward: false)
                } else if let forwardItem = webView.backForwardList.forwardItem, forwardItem.url == url {
                    pendingNavigationType = (isBack: false, isForward: true)
                }
            }

            // DIGITAL GUARDIAN: Check for inappropriate content FIRST
            let contentCheck = BrowserState.checkURL(url, parentSettings: appState.parentSettings)
            if contentCheck.shouldIntervene, let trigger = contentCheck.trigger {
                print("🛡️ Content check triggered intervention: \(trigger.searchTerm)")
                
                // Log the attempt
                historyService.logBlocked(url: url, category: "Content Filter", reason: "Inappropriate content detected: \(trigger.searchTerm)")
                
                // Show Komal intervention instead of just blocking
                DispatchQueue.main.async {
                    self.browserState.triggerIntervention(for: trigger, pendingURL: url)
                }
                
                decisionHandler(.cancel)
                return
            }

            if let rewritten = rewriteForSafeSearch(url: url), rewritten != url {
                webView.load(URLRequest(url: rewritten))
                decisionHandler(.cancel)
                return
            }

            if navigationAction.targetFrame == nil {
                webView.load(URLRequest(url: url))
                decisionHandler(.cancel)
                return
            }

            if url.host?.contains("youtube.com") == true || url.host?.contains("youtu.be") == true {
                // Still check YouTube search queries
                if let searchQuery = BrowserState.extractSearchQuery(from: url),
                   let flagged = BrowserState.checkForInappropriateContent(searchQuery) {
                    print("🛡️ YouTube search flagged: \(flagged)")
                    DispatchQueue.main.async {
                        self.browserState.triggerIntervention(for: .searchQuery(flagged), pendingURL: url)
                    }
                    decisionHandler(.cancel)
                    return
                }
                decisionHandler(.allow)
                return
            }

            if let match = blocklist.match(url: url) {
                // Log blocked event for insights
                historyService.logBlocked(url: url, category: match.category, reason: match.reason)
                // Use intervention for blocklist matches too
                DispatchQueue.main.async {
                    self.browserState.triggerIntervention(for: .urlKeyword(match.category), pendingURL: url)
                }
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        private func presentBlock(category: ContentCategory, reason: String) {
            browserState.showBlocked = true
            browserState.showGate = false
            browserState.category = category
            browserState.blockReason = reason
        }

        private func rewriteForSafeSearch(url: URL) -> URL? {
            guard appState.parentSettings.safeSearchEnabled else { return nil }
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
    }
}

// MARK: - Past Tabs View
struct PastTabsView: View {
    @ObservedObject var browserState: BrowserState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                GradientBackground()
                
                if browserState.tabHistory.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.system(size: 60, weight: .light))
                            .foregroundColor(KomalColors.pearlAqua.opacity(0.6))
                        Text("No past tabs yet")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(KomalColors.textSecondary)
                        Text("Websites you visit will appear here")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(KomalColors.textSecondary.opacity(0.7))
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(browserState.tabHistory, id: \.self) { url in
                                Button(action: {
                                    browserState.urlString = url.absoluteString
                                    browserState.currentURL = url
                                    dismiss()
                                }) {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [KomalColors.pearlAqua.opacity(0.3), KomalColors.bubblegumPink.opacity(0.3)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 44, height: 44)
                                            
                                            Image(systemName: "globe")
                                                .font(.system(size: 18, weight: .medium))
                                                .foregroundColor(KomalColors.pearlAqua)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(url.host ?? "Unknown")
                                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                                .foregroundColor(KomalColors.textPrimary)
                                                .lineLimit(1)
                                            
                                            Text(url.absoluteString)
                                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                                .foregroundColor(KomalColors.textSecondary)
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(KomalColors.textSecondary.opacity(0.5))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(KomalColors.white)
                                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                }
            }
            .navigationTitle("Past Tabs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(KomalColors.bubblegumPink)
                }
            }
        }
    }
}
#endif
