#if canImport(SwiftUI)
import SwiftUI

struct RootView: View {
    @State private var selectedTab: NavigationTab = .browser
    @StateObject private var browserState = BrowserState()
    
    var body: some View {
        ZStack {
            // Content based on selected tab
            Group {
                switch selectedTab {
                case .browser:
                    BrowserViewWithState(browserState: browserState)
                case .riki:
                    RikiCheckInView()
                case .settings:
                    SettingsView()
                }
            }
            
            // Floating menu overlay
            FloatingMenuView(selectedTab: $selectedTab, onNewTab: {
                let googleURL = URL(string: "https://www.google.com")
                browserState.urlString = googleURL?.absoluteString ?? browserState.urlString
                browserState.openNewTab(with: googleURL)
            }, onPastTabs: {
                // Show past tabs
                browserState.showPastTabs = true
            })
        }
    }
}

// Wrapper to pass browserState to BrowserView
struct BrowserViewWithState: View {
    @ObservedObject var browserState: BrowserState
    @EnvironmentObject private var appState: AppState
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
        .onAppear {
            if !hasLoadedInitial {
                browserState.ensureSelectedTab()
                browserState.currentURL = normalizedURL(from: browserState.urlString)
                browserState.updateSelectedTabURL(browserState.currentURL)
                hasLoadedInitial = true
            }
        }
    }
    
    private func normalizedURL(from input: String) -> URL? {
        if let url = URL(string: input), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(input)")
    }
}
#endif
