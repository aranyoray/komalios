//
//  SplashScreenView.swift
//  Komalios
//
//  Initial splash screen with app logo and animation
//

import SwiftUI

struct SplashScreenView: View {
    @EnvironmentObject var pathManager: PathManager
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var appState: AppState
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0
    
    var body: some View {
        ZStack {
            GradientBackground()
            
            VStack(spacing: 20) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 100))
                    .foregroundColor(.white)
                    .scaleEffect(scale)
                    .opacity(opacity)
                
                Text("Komal")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(opacity)
                
                Text("Safe Digital Companion")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
            
            // Navigate after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                navigateToNextScreen()
            }
        }
    }
    
    private func navigateToNextScreen() {
        if authViewModel.user != nil {
            // User is logged in
            if appState.hasCompletedOnboarding {
                pathManager.push(.rootView)
            } else {
                pathManager.push(.onboardingView)
            }
        } else {
            // User not logged in
            pathManager.push(.loginView)
        }
    }
}

#Preview {
    SplashScreenView()
        .environmentObject(PathManager())
        .environmentObject(AuthViewModel())
        .environmentObject(AppState())
}
