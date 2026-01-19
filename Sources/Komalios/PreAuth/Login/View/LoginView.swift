//
//  LoginView.swift
//  Komalios
//
//  Created by Amit Kumar on 18/01/26.
//

import SwiftUI

struct LoginView: View {
    
    @ObservedObject var viewModel: AuthViewModel
    @EnvironmentObject var appState: AppState
    @State private var showOnboarding = false
    
    var body: some View {
        // If user is authenticated, go to RootView
        //        if viewModel.user != nil {
        if appState.hasCompletedOnboarding {
            RootView()
                .environmentObject(appState)
        }
        else {
            switch viewModel.loginState {
            case .notRunning:
                ZStack {
                    GradientBackground()
                    VStack {
                        ZStack {
                            Circle()
                                .fill(KomalColors.white)
                                .frame(width: 140, height: 140)
                                .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
                            
                            Image(systemName: "shield.checkered")
                                .font(.system(size: 70))
                                .foregroundColor(KomalColors.bubblegumPink)
                        }
                        
                        VStack(spacing: 16) {
                            Text("Welcome to Komal")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(KomalColors.textPrimary)
                            
                            Text("Your child's safe digital companion")
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(KomalColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        SocialSignInButton(logoImage: "google_logo", title: "Sign in with Google") {
                            viewModel.signInWithGoogle()
                        }
                        .padding()
                        
                        SocialSignInButton(logoImage: "apple_logo", title: "Sign in with Apple") {
                            viewModel.signInWithApple()
                        }
                        .padding(.horizontal)
                        
                        Text("Or")
                        
                        Button {
                            showOnboarding = true
                        } label: {
                            Text("Guest User")
                        }
                        .padding()
                        .foregroundStyle(.accent)
                        .font(.title3)
                        .underline()
                    }
                }
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingView {
                        appState.savePreferences()
                    }
                }
            case .loading:
                ProgressView()
            case .success:
                if appState.hasCompletedOnboarding {
                    RootView()
                        .environmentObject(appState)
                } else {
                    OnboardingView {
                        appState.savePreferences()
                    }
                    .environmentObject(appState)
                }
                
            case .failure(let string):
                ZStack {
                    GradientBackground()
                    VStack {
                        Text("Login Failed")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)
                        Text(string)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.red)
                            .padding()
                        
                        Button("Try Again") {
                            viewModel.loginState = .notRunning
                        }
                        .buttonStyle(PillButtonStyle())
                        .padding()
                    }
                }
            }
        }
    }
}

#Preview {
    LoginView(viewModel: AuthViewModel())
}
