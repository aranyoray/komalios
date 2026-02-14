#if os(iOS)
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var selectedTab: NavigationTab = .browser
    
    var body: some View {
        ZStack {
            // Content based on selected tab
            Group {
                switch selectedTab {
                case .browser:
                    KomalSafetyScannerView()
                case .riki:
                    RikiCheckInView()
                case .reflect:
                    ReflectionTimeView()
                case .settings:
                    SettingsView(selectedTab: $selectedTab)
                        .environmentObject(authViewModel)
                }
            }
            
            // Floating menu overlay
            FloatingMenuView(selectedTab: $selectedTab)
        }
    }
}
#endif


