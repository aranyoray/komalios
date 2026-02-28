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
                        Image("komal_logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 140, height: 140)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
                        
                        VStack(spacing: 16) {
                            Text(LanguageManager.localized("login.welcome"))
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(KomalColors.textPrimary)

                            Text(LanguageManager.localized("login.tagline"))
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(KomalColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        SocialSignInButton(logoImage: "google_logo", title: LanguageManager.localized("login.sign_in_google")) {
                            viewModel.signInWithGoogle()
                        }
                        .padding()
                        
                        SocialSignInButton(logoImage: "apple_logo", title: LanguageManager.localized("login.sign_in_apple")) {
                            viewModel.signInWithApple()
                        }
                        .padding()
                        
                        Text(LanguageManager.localized("login.or"))
                        
                        Button {
                            showOnboarding = true
                        } label: {
                            Text(LanguageManager.localized("login.guest_user"))
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
                        appState.isGuestUser = true
                        appState.savePreferences()
                        showOnboarding = false
                        // Navigate to onboarding survey
                        pathManager.popToRoot()
                        pathManager.push(Routes.onboardingView)
                    })
                }
#else
                .sheet(isPresented: $showOnboarding) {
                    LoginGuestOnboardingSheet(onFinish: {
                        appState.isGuestUser = true
                        appState.savePreferences()
                        showOnboarding = false
                        pathManager.popToRoot()
                        pathManager.push(Routes.onboardingView)
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
                        Text(LanguageManager.localized("login.signing_in"))
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
                        Text(LanguageManager.localized("login.failed"))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)
                        Text(string)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.red)
                            .padding()
                        
                        Button(LanguageManager.localized("login.try_again")) {
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
                Text(LanguageManager.localized("login.guest.welcome"))
                    .font(.title.bold())
                Text(LanguageManager.localized("login.guest.description"))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button(LanguageManager.localized("common.continue")) {
                    onFinish()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle(LanguageManager.localized("login.guest.getting_started"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LanguageManager.localized("common.close")) { onFinish() }
                }
            }
        }
    }
}

