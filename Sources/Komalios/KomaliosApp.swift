#if canImport(SwiftUI)
import SwiftUI

@main
struct KomaliosApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            if appState.hasCompletedOnboarding {
                RootView()
                    .environmentObject(appState)
            } else {
                OnboardingView {
                    // Onboarding completed
                    appState.savePreferences()
                }
                .environmentObject(appState)
            }
        }
    }
}
#else
@main
enum KomaliosApp {
    static func main() {
        print("Komalios requires SwiftUI and iOS to run.")
    }
}
#endif
