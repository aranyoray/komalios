//
//  KomalSafetyScanner.swift
//  KOMAL iOS App
//
//  Main view for URL safety scanning with BLOCK/GATE/ALLOW functionality
//

import SwiftUI

#if os(iOS)

struct KomalSafetyScannerView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: KomalSafetyScannerViewModel
    
    init() {
        // Create a temporary appState for initialization
        // Will be updated in onAppear
        let tempAppState = AppState()
        _viewModel = StateObject(wrappedValue: KomalSafetyScannerViewModel(appState: tempAppState))
    }
    
    var body: some View {
        KomalSafetyScannerContentView(viewModel: viewModel, appState: appState)
            .environmentObject(appState)
            .onAppear {
                // Update appState in viewModel
                viewModel.updateAppState(appState)
                // Start browsing session for history tracking
                BrowsingHistoryService.shared.startSession()
            }
            .onDisappear {
                // End browsing session when leaving browser
                BrowsingHistoryService.shared.endSession()
            }
    }
}

private struct KomalSafetyScannerContentView: View {
    @ObservedObject var viewModel: KomalSafetyScannerViewModel
    let appState: AppState
    @State private var showBrowserMenu = false
    @State private var showReflectionTime = false
    
    var body: some View {
        ZStack {
            GradientBackground()
            
            VStack(spacing: 6) {
                    // Address bar with menu button
                    HStack(spacing: 10) {
                        // Menu button
                        Menu {
                            Button(action: {
                                // New tab - reset to Google
                                viewModel.urlInput = "google.com"
                                viewModel.currentURL = URL(string: "https://www.google.com")
                            }) {
                                Label("New Tab", systemImage: "plus.square")
                            }
                            
                            Button(action: {
                                // Refresh current page
                                if let url = viewModel.currentURL {
                                    viewModel.currentURL = nil
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        viewModel.currentURL = url
                                    }
                                }
                            }) {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                            
                            Divider()
                            
                            Button(action: {
                                showReflectionTime = true
                            }) {
                                Label("Reflection Time", systemImage: "leaf.fill")
                            }
                            
                            Divider()
                            
                            Button(action: {
                                // Clear and go home
                                viewModel.urlInput = ""
                                viewModel.currentURL = nil
                            }) {
                                Label("Close Tab", systemImage: "xmark.square")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(KomalColors.bubblegumPink)
                        }
                        
                        // Address bar (expanded)
                        AddressBar(urlString: $viewModel.urlInput) {
                            Task {
                                UIApplication.shared.hideKeyboard()
                                await viewModel.handleUrlSubmit()
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                
                // Subtle scanning indicator below address bar
                if viewModel.loading {
                    ScanningIndicator()
                        .padding(.horizontal, 8)
                }
                
                if let url = viewModel.currentURL, !viewModel.showGate, !viewModel.showBlocked, !viewModel.showBlockedEmojiPopup, !viewModel.showKomalIntervention {
                    SimpleWebView(
                        url: url,
                        loading: Binding(
                            get: { viewModel.loading },
                            set: { viewModel.updateLoading($0) }
                        ),
                        contentFilterPreferences: appState.contentFilterPreferences,
                        parentSettings: appState.parentSettings,
                        onInappropriateContent: { trigger, blockedURL in
                            // Handle in-page navigation to inappropriate content
                            viewModel.interventionTrigger = trigger
                            viewModel.pendingURL = blockedURL
                            viewModel.showKomalIntervention = true
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 8)
                    .padding(.bottom, 80) // Space for floating nav bar
                }
            }

            // Mandatory emoji check-in overlay (blocks interaction until responded)
            if viewModel.showEmojiCheckIn {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .onTapGesture {} // Absorb taps to block web interaction

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        EmojiCheckInBubble { emoji in
                            viewModel.handleEmojiResponse(emoji: emoji, forDocumentId: viewModel.lastLoggedDocumentId)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showGate, onDismiss: {
            viewModel.handleGateDismissed()
        }) {
            // Emoji gate: collect emoji then allow content
            VStack(spacing: 24) {
                Spacer()

                if let uiImage = UIImage(named: "animal\(viewModel.gateAvatarIndex)") {
                    Image(uiImage: uiImage)
                        .resizable().aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100).clipShape(Circle())
                        .overlay(Circle().stroke(KomalColors.bubblegumPink, lineWidth: 3))
                }

                VStack(spacing: 6) {
                    Text("Before you go...")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(KomalColors.textPrimary)
                    Text("How are you feeling right now?")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.textSecondary)
                }

                EmojiResponseView(subcategory: viewModel.currentSubcategory) { emoji in
                    viewModel.handleEmojiResponse(emoji: emoji, forDocumentId: viewModel.lastLoggedDocumentId)
                    viewModel.showGate = false
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .interactiveDismissDisabled()
            .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: $viewModel.showBlocked, onDismiss: {
            viewModel.handleBlockedDismissed()
        }) {
            KomalBlockedView(category: viewModel.category, reason: viewModel.blockReason)
        }
        .fullScreenCover(isPresented: $viewModel.showBlockedEmojiPopup) {
            BlockedEmojiPopup(
                subcategory: viewModel.currentSubcategory,
                characterName: "Komal",
                onDismiss: {
                    viewModel.showBlockedEmojiPopup = false
                    viewModel.handleBlockedDismissed()
                },
                onEmojiSelected: { emoji in
                    viewModel.handleEmojiResponse(emoji: emoji, forDocumentId: viewModel.lastLoggedDocumentId)
                }
            )
        }
        .fullScreenCover(isPresented: $viewModel.showKomalCheckIn) {
            KomalCheckInView()
        }
        .fullScreenCover(isPresented: $viewModel.showKomalIntervention) {
            if let trigger = viewModel.interventionTrigger {
                KomalInterventionView(
                    trigger: trigger,
                    onReflectionTime: {
                        print("🌸 Child completed reflection - redirecting to safe content")
                        viewModel.handleInterventionDismissed(allowContinue: false)
                    },
                    onGoBack: {
                        print("🌸 Child chose to go back")
                        viewModel.handleInterventionDismissed(allowContinue: false)
                    },
                    onContinueAnyway: nil  // No continue option for safety
                )
            }
        }
        .fullScreenCover(isPresented: $showReflectionTime) {
            ReflectionTimeView()
                .environmentObject(appState)
        }
}
}

// MARK: - Subtle Scanning Indicator
private struct ScanningIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Small Komal logo
            ZStack {
                if let uiImage = UIImage(named: "komaliconnobg") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 20, height: 20)
                        .clipShape(Circle())
                        .rotationEffect(Angle(degrees: isAnimating ? 10 : -10))
                } else {
                    Circle()
                        .fill(KomalColors.bubblegumPink.opacity(0.3))
                        .frame(width: 20, height: 20)
                }
            }
            
            Text("Komal is keeping you safe...")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(KomalColors.textSecondary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.9))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}
#endif

