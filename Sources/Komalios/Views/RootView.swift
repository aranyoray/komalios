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
                // New tab action - open Google
                browserState.urlString = "https://www.google.com"
                browserState.currentURL = URL(string: "https://www.google.com")
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
#endif


