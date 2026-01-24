#if canImport(SwiftUI) && canImport(WebKit)
import SwiftUI
import WebKit

struct BrowserTab: Identifiable, Equatable {
    let id = UUID()
    var url: URL?
    var title: String = "New Tab"
}

protocol BrowserNavigationControlling: AnyObject {
    func goBack()
    func goForward()
}

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
    @Published var tabs: [BrowserTab] = [BrowserTab(url: nil, title: "Komalios")]
    @Published var selectedTabID: BrowserTab.ID?
    @Published var canGoBack = false
    @Published var canGoForward = false
    weak var navigationController: BrowserNavigationControlling?

    var selectedTabIndex: Int? {
        guard let selectedTabID else { return nil }
        return tabs.firstIndex(where: { $0.id == selectedTabID })
    }

    func addToHistory(_ url: URL) {
        if !tabHistory.contains(url) {
            tabHistory.insert(url, at: 0)
            if tabHistory.count > 20 {
                tabHistory.removeLast()
            }
        }
    }

    func ensureSelectedTab() {
        if selectedTabID == nil {
            selectedTabID = tabs.first?.id
        }
    }

    func updateSelectedTabURL(_ url: URL?) {
        guard let index = selectedTabIndex else { return }
        tabs[index].url = url
    }

    func updateSelectedTabTitle(_ title: String?) {
        guard let index = selectedTabIndex else { return }
        tabs[index].title = title?.isEmpty == false ? title! : hostDisplay(for: tabs[index].url)
    }

    func openNewTab(with url: URL?) {
        let tab = BrowserTab(url: url, title: hostDisplay(for: url))
        tabs.append(tab)
        selectedTabID = tab.id
        currentURL = url
        if let url {
            urlString = url.absoluteString
        }
    }

    func closeSelectedTab() {
        guard tabs.count > 1, let index = selectedTabIndex else { return }
        tabs.remove(at: index)
        let newIndex = min(index, tabs.count - 1)
        let newTab = tabs[newIndex]
        selectedTabID = newTab.id
        currentURL = newTab.url
        urlString = newTab.url?.absoluteString ?? urlString
    }

    func selectTab(id: BrowserTab.ID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        selectedTabID = id
        currentURL = tabs[index].url
        if let url = tabs[index].url {
            urlString = url.absoluteString
        }
    }

    func goBack() {
        navigationController?.goBack()
    }

    func goForward() {
        navigationController?.goForward()
    }

    private func hostDisplay(for url: URL?) -> String {
        url?.host ?? "New Tab"
    }
}

struct BrowserView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var browserState = BrowserState()
    @State private var hasLoadedInitial = false

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: 8) {
                BrowserTabStrip(browserState: browserState) {
                    browserState.openNewTab(with: normalizedURL(from: browserState.urlString))
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                BrowserNavigationBar(browserState: browserState)
                    .padding(.horizontal, 12)

                AddressBar(urlString: $browserState.urlString) {
                    let url = normalizedURL(from: browserState.urlString)
                    browserState.currentURL = url
                    browserState.updateSelectedTabURL(url)
                }
                .padding(.horizontal, 12)

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
            // Auto-load default URL on first appearance
            if !hasLoadedInitial {
                browserState.ensureSelectedTab()
                browserState.currentURL = normalizedURL(from: browserState.urlString)
                browserState.updateSelectedTabURL(browserState.currentURL)
                hasLoadedInitial = true
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

            AddressTextField(text: $urlString, onSubmit: onSubmit)

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

struct AddressTextField: UIViewRepresentable {
    @Binding var text: String
    var onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.returnKeyType = .go
        textField.autocapitalizationType = .none
        textField.keyboardType = .URL
        textField.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        textField.textColor = UIColor(KomalColors.textPrimary)
        textField.placeholder = "Search or enter address"
        textField.addTarget(context.coordinator, action: #selector(Coordinator.didBeginEditing(_:)), for: .editingDidBegin)
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding private var text: String
        private let onSubmit: () -> Void
        private var didSelectOnFocus = false

        init(text: Binding<String>, onSubmit: @escaping () -> Void) {
            self._text = text
            self.onSubmit = onSubmit
        }

        @objc func didBeginEditing(_ textField: UITextField) {
            guard !didSelectOnFocus else { return }
            didSelectOnFocus = true
            DispatchQueue.main.async {
                textField.selectAll(nil)
                self.didSelectOnFocus = false
            }
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            text = textField.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            onSubmit()
            return true
        }
    }
}

struct BrowserNavigationBar: View {
    @ObservedObject var browserState: BrowserState

    var body: some View {
        HStack(spacing: 16) {
            navButton(systemName: "chevron.left", enabled: browserState.canGoBack) {
                browserState.goBack()
            }

            navButton(systemName: "chevron.right", enabled: browserState.canGoForward) {
                browserState.goForward()
            }

            navButton(systemName: "xmark", enabled: browserState.tabs.count > 1) {
                browserState.closeSelectedTab()
            }

            Spacer()

            Text("\(browserState.tabs.count) Tabs")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(KomalColors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(KomalColors.white.opacity(0.8)))
        }
    }

    private func navButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(enabled ? KomalColors.bubblegumPink : KomalColors.textSecondary.opacity(0.5))
                .frame(width: 36, height: 36)
                .background(Circle().fill(KomalColors.white.opacity(enabled ? 0.95 : 0.6)))
        }
        .disabled(!enabled)
        .shadow(color: .black.opacity(enabled ? 0.08 : 0), radius: 6, x: 0, y: 2)
    }
}

struct BrowserTabStrip: View {
    @ObservedObject var browserState: BrowserState
    var onAddTab: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(browserState.tabs) { tab in
                    Button {
                        browserState.selectTab(id: tab.id)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "globe")
                                .font(.system(size: 12, weight: .bold))
                            Text(tab.title)
                                .lineLimit(1)
                        }
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .foregroundColor(browserState.selectedTabID == tab.id ? KomalColors.bubblegumPink : KomalColors.textSecondary)
                        .background(
                            Capsule()
                                .fill(browserState.selectedTabID == tab.id ? KomalColors.white : KomalColors.white.opacity(0.7))
                        )
                    }
                }

                Button(action: onAddTab) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(KomalColors.pearlAqua)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(KomalColors.white.opacity(0.85)))
                }
            }
        }
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
        context.coordinator.attach(webView: webView)
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

    final class Coordinator: NSObject, WKNavigationDelegate, BrowserNavigationControlling {
        private let blocklist = BlocklistService.shared
        private let browserState: BrowserState
        private let appState: AppState
        private weak var webView: WKWebView?

        init(browserState: BrowserState, appState: AppState) {
            self.browserState = browserState
            self.appState = appState
        }

        func attach(webView: WKWebView) {
            self.webView = webView
            browserState.navigationController = self
            updateNavigationAvailability(for: webView)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            browserState.loading = true
            updateNavigationAvailability(for: webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            browserState.loading = false
            browserState.currentURL = webView.url
            browserState.updateSelectedTabURL(webView.url)
            browserState.updateSelectedTabTitle(webView.title)
            if let url = webView.url {
                browserState.urlString = url.absoluteString
            }
            browserState.showGate = false
            if let url = webView.url {
                browserState.addToHistory(url)
            }
            updateNavigationAvailability(for: webView)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            if navigationAction.targetFrame == nil {
                webView.load(URLRequest(url: url))
                decisionHandler(.cancel)
                return
            }

            if let rewritten = rewriteForSafeSearch(url: url), rewritten != url {
                webView.load(URLRequest(url: rewritten))
                decisionHandler(.cancel)
                return
            }

            if let match = blocklist.match(url: url) {
                presentBlock(category: ContentCategory(label: match.category), reason: match.reason)
                decisionHandler(.cancel)
                return
            }

            if appState.parentSettings.isHostBlocked(url.host) {
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

        private func updateNavigationAvailability(for webView: WKWebView) {
            browserState.canGoBack = webView.canGoBack
            browserState.canGoForward = webView.canGoForward
        }

        func goBack() {
            webView?.goBack()
            if let webView {
                updateNavigationAvailability(for: webView)
            }
        }

        func goForward() {
            webView?.goForward()
            if let webView {
                updateNavigationAvailability(for: webView)
            }
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
                components.queryItems = upsertQueryItem(name: "safeSearch", value: "strict", items: components.queryItems)
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
