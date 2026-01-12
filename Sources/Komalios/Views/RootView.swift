#if canImport(SwiftUI)
import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            BrowserView()
                .tabItem {
                    Label("Browser", systemImage: "safari")
                }

            RikiCheckInView()
                .tabItem {
                    Label("Riki", systemImage: "pawprint.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}
#endif
