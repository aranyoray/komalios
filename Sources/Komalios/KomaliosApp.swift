#if os(iOS)
import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct KomaliosApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var pathManager = PathManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(authViewModel)
                .environmentObject(pathManager)
                .preferredColorScheme(.light)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var pathManager: PathManager
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        NavigationStack(path: $pathManager.path) {
            // Start with SplashScreen - it will navigate after 3 seconds
            SplashScreenView()
                .navigationDestination(for: Routes.self) { route in
                    destinationView(for: route)
                }
        }
        .onChange(of: authViewModel.user) { _ in
            guard !appState.isGuestUser else { return }
            if authViewModel.user == nil {
                pathManager.popToRoot()
                pathManager.push(Routes.loginView)
            } else if appState.hasCompletedOnboarding {
                pathManager.popToRoot()
                pathManager.push(Routes.rootView)
            } else {
                pathManager.popToRoot()
                pathManager.push(Routes.onboardingView)
            }
        }
        .onChange(of: appState.hasCompletedOnboarding) { _ in
            if appState.hasCompletedOnboarding && (authViewModel.user != nil || appState.isGuestUser) {
                pathManager.popToRoot()
                pathManager.push(Routes.rootView)
            }
        }
        .onChange(of: scenePhase) { _ in
            if scenePhase == .background || scenePhase == .inactive {
                if appState.accountMode == .guest {
                    appState.accountMode = .child
                }
            }
        }
        .onAppear {
            print("📱 ContentView appeared - user: \(authViewModel.user?.uid ?? "nil"), hasCompletedOnboarding: \(appState.hasCompletedOnboarding)")
            // Navigation is handled by SplashScreenView after 3 seconds
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserDidSignOut"))) { _ in
            // Backup: Force update authViewModel state if notification is received
            print("📢 Received UserDidSignOut notification")
            Task { @MainActor in
                appState.isGuestUser = false
                authViewModel.user = nil
                authViewModel.loginState = .notRunning
                pathManager.popToRoot()
                pathManager.push(Routes.loginView)
                print("✅ Updated authViewModel from notification")
            }
        }
    }
    
    @ViewBuilder
    private func destinationView(for route: Routes) -> some View {
        switch route {
        case .loginView:
            LoginView(viewModel: authViewModel)
                .navigationBarBackButtonHidden(true)
        case .rootView:
            RootView()
                .navigationBarBackButtonHidden(true)
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserDidSignOut"))) { _ in
                    pathManager.popToRoot()
                    pathManager.push(Routes.loginView)
                }
        case .onboardingView:
            PostAuthOnboardingView {
                appState.savePreferences()
            }
            .navigationBarBackButtonHidden(true)
        case .settingView:
            SettingsView(selectedTab: nil)
        }
    }
}
#endif

