//
//  KomalSafetyScanner.swift
//  KOMAL iOS App
//
//  Main view for URL safety scanning with BLOCK/GATE/ALLOW functionality
//

import SwiftUI

#if canImport(SwiftUI) && canImport(WebKit)

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
    
    var body: some View {
        ZStack {
            GradientBackground()
            
                VStack(spacing: 8) {
                    AddressBar(urlString: $viewModel.urlInput) {
                        Task {
                        UIApplication.shared.hideKeyboard()
                        await viewModel.handleUrlSubmit()
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                
                // Subtle scanning indicator below address bar
                if viewModel.loading {
                    ScanningIndicator()
                        .padding(.horizontal, 12)
                }
                
                if let url = viewModel.currentURL, !viewModel.showGate, !viewModel.showBlocked {
                    SimpleWebView(url: url, loading: Binding(
                        get: { viewModel.loading },
                        set: { viewModel.updateLoading($0) }
                    ))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    }
                
                Spacer(minLength: 0)
    }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .sheet(isPresented: $viewModel.showGate) {
            GateView(category: viewModel.category)
                .environmentObject(appState)
    }
        .onChange(of: viewModel.showGate) { oldValue, newValue in
            if !newValue {
                viewModel.handleGateDismissed()
            }
        }
        .fullScreenCover(isPresented: $viewModel.showBlocked) {
            KomalBlockedView(category: viewModel.category, reason: viewModel.blockReason)
                }
        .onChange(of: viewModel.showBlocked) { oldValue, newValue in
            if !newValue {
                viewModel.handleBlockedDismissed()
            }
        }
        .fullScreenCover(isPresented: $viewModel.showKomalCheckIn) {
            KomalCheckInView()
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
