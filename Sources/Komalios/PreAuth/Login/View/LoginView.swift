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
    @EnvironmentObject var pathManager: PathManager
    @State private var showOnboarding = false
    
    var body: some View {
        // Navigation is handled by ContentView based on auth state
        // This view just shows the login UI
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
                        .foregroundStyle(Color.accentColor)
                        .font(.title3)
                        .underline()
                    }
                }
#if os(iOS)
                .fullScreenCover(isPresented: $showOnboarding) {
                    LoginGuestOnboardingSheet(onFinish: {
                        appState.savePreferences()
                        showOnboarding = false
                    })
                }
#else
                .sheet(isPresented: $showOnboarding) {
                    LoginGuestOnboardingSheet(onFinish: {
                        appState.savePreferences()
                        showOnboarding = false
                    })
                }
#endif
            case .loading:
                ZStack {
                    GradientBackground()
                    ProgressView()
                        .scaleEffect(1.5)
                }
            case .success:
                // Navigation will be handled by ContentView's onChange handlers
                // Show a loading state while navigation happens
                ZStack {
                    GradientBackground()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Signing you in...")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(KomalColors.textSecondary)
                    }
                }
                .onAppear {
                    // Navigation will be triggered by ContentView's onChange(of: authViewModel.user)
                    // If onboarding is needed, ContentView will navigate to onboardingView
                    // Otherwise, it will navigate to rootView
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


#if canImport(PreviewsMacros)
#Preview {
    LoginView(viewModel: AuthViewModel())
}
#endif

private struct LoginGuestOnboardingSheet: View {
    var onFinish: () -> Void
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Welcome!")
                    .font(.title.bold())
                Text("You can explore as a guest. When you're ready, you can sign in to sync across devices.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Continue") {
                    onFinish()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Getting Started")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onFinish() }
                }
            }
        }
    }
}

