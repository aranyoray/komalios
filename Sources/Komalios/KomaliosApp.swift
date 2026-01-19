#if canImport(SwiftUI)
import SwiftUI
import FirebaseAuth

@main
struct KomaliosApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authViewModel = AuthViewModel()
    @UIApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(authViewModel)
                .preferredColorScheme(.light)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        Group {
            if authViewModel.user != nil && appState.hasCompletedOnboarding {
                RootView()
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserDidSignOut"))) { _ in
                        // Backup: Force update authViewModel state if notification is received
                        print("📢 Received UserDidSignOut notification")
                        Task { @MainActor in
                            authViewModel.user = nil
                            authViewModel.loginState = .notRunning
                            print("✅ Updated authViewModel from notification")
                        }
                    }
            } else {
                LoginView(viewModel: authViewModel)
            }
        }
        .onChange(of: authViewModel.user) { oldUser, newUser in
            // This will trigger when user becomes nil
            if newUser == nil {
                print("✅ User logged out, should navigate to LoginView")
            }
        }
        .onAppear {
            print("📱 ContentView appeared - user: \(authViewModel.user?.uid ?? "nil"), hasCompletedOnboarding: \(appState.hasCompletedOnboarding)")
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
