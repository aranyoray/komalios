#if canImport(SwiftUI) && canImport(WebKit)
import SwiftUI
import WebKit

final class BrowserState: ObservableObject {
    @Published var urlString = "https://www.khanacademy.org"
    @Published var currentURL: URL?
    @Published var category: ContentCategory = .unknown
    @Published var blockReason: String = ""
    @Published var showGate = false
    @Published var showBlocked = false
    @Published var loading = false
    @Published var tabHistory: [URL] = []
    @Published var showPastTabs = false
    
    func addToHistory(_ url: URL) {
        if !tabHistory.contains(url) {
            tabHistory.insert(url, at: 0)
            if tabHistory.count > 20 {
                tabHistory.removeLast()
            }
        }
    }
}

struct BrowserView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var browserState = BrowserState()

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: 8) {
                AddressBar(urlString: $browserState.urlString) {
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
    }

    private func normalizedURL(from input: String) -> URL? {
        if let url = URL(string: input), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(input)")
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
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = false
        if let url {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let url else { return }
        if uiView.url != url {
            uiView.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(browserState: browserState, appState: appState)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let blocklist = BlocklistService.shared
        private let browserState: BrowserState
        private let appState: AppState

        init(browserState: BrowserState, appState: AppState) {
            self.browserState = browserState
            self.appState = appState
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            browserState.loading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            browserState.loading = false
            browserState.currentURL = webView.url
            browserState.showGate = false
            if let url = webView.url {
                browserState.addToHistory(url)
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
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
                decisionHandler(.allow)
                return
            }

            if let match = blocklist.match(url: url) {
                presentBlock(category: ContentCategory(label: match.category), reason: match.reason)
                decisionHandler(.cancel)
                return
            }

            if appState.parentSettings.blockedHosts.contains(where: { url.host?.contains($0) == true }) {
                presentBlock(category: .platformRisks, reason: "Blocked by parent host rule.")
                decisionHandler(.cancel)
                return
            }

            if appState.parentSettings.blockedKeywords.contains(where: { url.absoluteString.lowercased().contains($0.lowercased()) }) {
                presentBlock(category: .platformRisks, reason: "Blocked by parent keyword rule.")
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
