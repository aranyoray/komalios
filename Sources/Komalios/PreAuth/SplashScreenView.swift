//
//  SplashScreenView.swift
//  Komalios
//
//  Created by Auto on 22/01/26.
//

import SwiftUI

struct SplashScreenView: View {
    @EnvironmentObject var pathManager: PathManager
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var appState: AppState
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.5
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    KomalColors.bubblegumPink.opacity(0.3),
                    KomalColors.lavenderPurple.opacity(0.2),
                    KomalColors.pearlAqua.opacity(0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // App Icon/Logo
                ZStack {
                    Circle()
                        .fill(KomalColors.white)
                        .frame(width: 140, height: 140)
                        .shadow(color: Color.black.opacity(0.1), radius: 20, y: 10)
                    
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 70, weight: .semibold))
                        .foregroundColor(KomalColors.bubblegumPink)
                }
                .scaleEffect(scale)
                .opacity(opacity)
                
                // App Name
                Text("Komal")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)
                    .opacity(opacity)
                
                // Tagline
                Text("Your child's safe digital companion")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(KomalColors.textSecondary)
                    .opacity(opacity * 0.8)
            }
        }
        .onAppear {
            // Animate appearance
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            
            // Navigate after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                // Only navigate if path is empty (prevent double navigation)
                guard pathManager.path.isEmpty else { return }
                
                // If user is already logged in (or guest) and completed onboarding, go to RootView
                // Otherwise, go to LoginView
                if (authViewModel.user != nil || appState.isGuestUser) && appState.hasCompletedOnboarding {
                    pathManager.push(Routes.rootView)
                } else {
                    pathManager.push(Routes.loginView)
                }
            }
        }
    }
}

#if canImport(PreviewsMacros)
#Preview {
    SplashScreenView()
        .environmentObject(PathManager())
        .environmentObject(AuthViewModel())
        .environmentObject(AppState())
}
#endif
