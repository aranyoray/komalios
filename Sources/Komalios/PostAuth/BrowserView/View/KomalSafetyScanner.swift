//
//  KomalSafetyScanner.swift
//  KOMAL iOS App
//
//  Chrome-style browser — single top toolbar with nav + omnibox
//

import SwiftUI

#if os(iOS)

// MARK: - Entry Point

struct KomalSafetyScannerView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: KomalSafetyScannerViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(appState: AppState) {
        _viewModel = StateObject(wrappedValue: KomalSafetyScannerViewModel(appState: appState))
    }

    var body: some View {
        KomalSafetyScannerContentView(viewModel: viewModel, appState: appState)
            .environmentObject(appState)
            .onAppear {
                viewModel.updateAppState(appState)
                BrowsingHistoryService.shared.startSession()
            }
            .onDisappear {
                BrowsingHistoryService.shared.endSession()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    BrowsingHistoryService.shared.endSession()
                } else if newPhase == .active, BrowsingHistoryService.shared.currentSession == nil {
                    BrowsingHistoryService.shared.startSession()
                }
            }
            .onReceive(appState.$pendingBrowserURL) { url in
                guard let url else { return }
                appState.pendingBrowserURL = nil
                Task { await viewModel.navigateToURL(url) }
            }
    }
}

// MARK: - Content View

private struct KomalSafetyScannerContentView: View {
    @ObservedObject var viewModel: KomalSafetyScannerViewModel
    let appState: AppState
    @StateObject private var navigator = SafariBrowserNavigator()
    @State private var showReflectionTime = false
    @State private var isOmniboxEditing = false
    @State private var showTabSwitcher = false

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                chromeToolbar
                progressBar

                // Web content area
                if let url = viewModel.currentURL,
                   !viewModel.showGate,
                   !viewModel.showBlocked,
                   !viewModel.showBlockedEmojiPopup,
                   !viewModel.showKomalIntervention {
                    SimpleWebView(
                        url: url,
                        loading: Binding(
                            get: { viewModel.loading },
                            set: { viewModel.updateLoading($0) }
                        ),
                        contentFilterPreferences: appState.contentFilterPreferences,
                        parentSettings: appState.parentSettings,
                        onInappropriateContent: { trigger, blockedURL in
                            viewModel.interventionTrigger = trigger
                            viewModel.currentSubcategory = trigger.searchTerm
                            viewModel.currentURL = nil
                            viewModel.clearLastSafeURLIfMatches(blockedURL)
                            viewModel.triggerBlockedEmojiPopup()
                        },
                        onPageFinished: { url, title in
                            viewModel.handlePageFinished(url: url, title: title)
                        },
                        onSearchNeedsScan: { query, url in
                            Task { await viewModel.backgroundScanSearchQuery(query, url: url) }
                        },
                        navigator: navigator
                    )
                    .ignoresSafeArea(.keyboard)
                } else if !viewModel.loading {
                    newTabPage
                } else {
                    VStack(spacing: 16) {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(LanguageManager.shared.localized("browser.checking_page"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(.bottom, 70)
            .allowsHitTesting(!viewModel.showEmojiCheckIn)

            // Emoji check-in overlay
            if viewModel.showEmojiCheckIn {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture {}
                    .transition(.opacity)

                VStack(spacing: 20) {
                    if let uiImage = UIImage(named: "animal\(viewModel.gateAvatarIndex)") {
                        Image(uiImage: uiImage)
                            .resizable().aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(KomalColors.bubblegumPink, lineWidth: 3))
                            .shadow(color: KomalColors.bubblegumPink.opacity(0.3), radius: 8, x: 0, y: 4)
                    }

                    VStack(spacing: 6) {
                        Text(LanguageManager.shared.localized("browser.quick_checkin"))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)
                        Text(LanguageManager.shared.localized("checkin.how_are_you"))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(KomalColors.textSecondary)
                    }

                    EmojiResponseView(subcategory: viewModel.currentSubcategory) { emoji in
                        viewModel.handleEmojiResponse(emoji: emoji, forDocumentId: viewModel.lastLoggedDocumentId)
                    }
                }
                .padding(.vertical, 28)
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(UIColor.systemBackground))
                        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                )
                .padding(.horizontal, 32)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        // Gate sheet
        .sheet(isPresented: $viewModel.showGate, onDismiss: {
            viewModel.handleGateDismissed()
        }) {
            VStack(spacing: 24) {
                Spacer()

                if let uiImage = UIImage(named: "animal\(viewModel.gateAvatarIndex)") {
                    Image(uiImage: uiImage)
                        .resizable().aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100).clipShape(Circle())
                        .overlay(Circle().stroke(KomalColors.bubblegumPink, lineWidth: 3))
                }

                VStack(spacing: 6) {
                    Text(LanguageManager.shared.localized("browser.before_you_go"))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(KomalColors.textPrimary)
                    Text(LanguageManager.shared.localized("checkin.how_are_you"))
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
        // Blocked fullscreen cover
        .fullScreenCover(isPresented: $viewModel.showBlocked, onDismiss: {
            viewModel.handleBlockedDismissed()
        }) {
            KomalBlockedView(category: viewModel.category, reason: viewModel.blockReason)
                .environmentObject(appState)
        }
        // Blocked emoji popup fullscreen cover
        .fullScreenCover(isPresented: $viewModel.showBlockedEmojiPopup) {
            BlockedEmojiPopup(
                subcategory: viewModel.currentSubcategory,
                characterName: "Komal",
                showTalkFeature: viewModel.shouldShowTalkFeature,
                onDismiss: {
                    viewModel.showBlockedEmojiPopup = false
                    viewModel.handleInterventionDismissed(allowContinue: false)
                },
                onEmojiSelected: { emoji in
                    viewModel.handleEmojiResponse(emoji: emoji, forDocumentId: viewModel.lastLoggedDocumentId)
                }
            )
            .environmentObject(appState)
        }
        // Reflection time
        .fullScreenCover(isPresented: $showReflectionTime) {
            ReflectionTimeView()
                .environmentObject(appState)
        }
        // Tab switcher
        .sheet(isPresented: $showTabSwitcher) {
            TabSwitcherView(viewModel: viewModel, isPresented: $showTabSwitcher)
        }
    }

    // MARK: - Chrome Top Toolbar

    private var chromeToolbar: some View {
        VStack(spacing: 0) {
            if isOmniboxEditing {
                HStack(spacing: 8) {
                    omniboxEditing
                    Button {
                        omniboxFocused = false
                        isOmniboxEditing = false
                    } label: {
                        Text(LanguageManager.shared.localized("common.cancel"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "4285F4"))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            } else {
                HStack(spacing: 6) {
                    // Back
                    Button(action: { navigator.goBack() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(navigator.canGoBack ? Color(UIColor.label) : Color(UIColor.quaternaryLabel))
                            .frame(width: 36, height: 36)
                    }
                    .disabled(!navigator.canGoBack)
                    .accessibilityLabel(LanguageManager.shared.localized("accessibility.go_back"))

                    // Forward
                    Button(action: { navigator.goForward() }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(navigator.canGoForward ? Color(UIColor.label) : Color(UIColor.quaternaryLabel))
                            .frame(width: 36, height: 36)
                    }
                    .disabled(!navigator.canGoForward)
                    .accessibilityLabel(LanguageManager.shared.localized("accessibility.go_forward"))

                    // Omnibox
                    omniboxCompact
                        .frame(maxWidth: .infinity)

                    // Tab switcher
                    Button(action: {
                        viewModel.saveCurrentTabState()
                        showTabSwitcher = true
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color(UIColor.label), lineWidth: 1.8)
                                .frame(width: 20, height: 20)
                            Text("\(viewModel.tabCount)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(UIColor.label))
                        }
                        .frame(width: 36, height: 36)
                    }
                    .accessibilityLabel(LanguageManager.shared.localized("accessibility.tab_switcher", viewModel.tabCount))

                    // Overflow menu
                    Menu {
                        Button(action: { navigator.reload() }) {
                            Label(LanguageManager.shared.localized("browser.reload"), systemImage: "arrow.clockwise")
                        }
                        Button(action: { shareCurrentPage() }) {
                            Label(LanguageManager.shared.localized("browser.share"), systemImage: "square.and.arrow.up")
                        }
                        Button(action: { showReflectionTime = true }) {
                            Label(LanguageManager.shared.localized("reflect.title"), systemImage: "leaf.fill")
                        }
                        Divider()
                        Button(action: { viewModel.addNewTab() }) {
                            Label(LanguageManager.shared.localized("browser.new_tab"), systemImage: "plus")
                        }
                        if viewModel.tabCount > 1 {
                            Button(role: .destructive, action: {
                                viewModel.closeTab(at: viewModel.activeTabIndex)
                            }) {
                                Label(LanguageManager.shared.localized("browser.close_tab"), systemImage: "xmark")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(Color(UIColor.label))
                            .frame(width: 36, height: 36)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
        }
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - Omnibox Compact

    private var omniboxCompact: some View {
        let displayDomain: String = {
            guard let url = navigator.currentDisplayURL ?? viewModel.currentURL,
                  let host = url.host else { return "" }
            return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        }()
        let hasURL = (navigator.currentDisplayURL ?? viewModel.currentURL) != nil

        return Button {
            viewModel.urlInput = ""
            isOmniboxEditing = true
        } label: {
            HStack(spacing: 0) {
                if hasURL { Color.clear.frame(width: 28) }
                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    if hasURL {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(UIColor.secondaryLabel))
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(UIColor.secondaryLabel))
                    }
                    Text(hasURL ? displayDomain : LanguageManager.shared.localized("browser.search_or_url"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(hasURL ? Color(UIColor.label) : Color(UIColor.placeholderText))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if hasURL {
                    if viewModel.loading {
                        Button(action: { navigator.stopLoading() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(UIColor.secondaryLabel))
                                .frame(width: 28, height: 28)
                        }
                    } else {
                        Button(action: { navigator.reload() }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(UIColor.secondaryLabel))
                                .frame(width: 28, height: 28)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(UIColor.tertiarySystemFill))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Omnibox Editing

    @FocusState private var omniboxFocused: Bool

    private var omniboxEditing: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color(UIColor.secondaryLabel))
                .font(.system(size: 15, weight: .medium))

            TextField(LanguageManager.shared.localized("browser.search_or_url"), text: $viewModel.urlInput)
                .font(.system(size: 16))
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .focused($omniboxFocused)
                .onSubmit {
                    omniboxFocused = false
                    isOmniboxEditing = false
                    // Small delay lets SwiftUI's focus system fully resign
                    // before WKWebView needs keyboard input
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        Task { await viewModel.handleUrlSubmit() }
                    }
                }
                .onAppear { omniboxFocused = true }

            if !viewModel.urlInput.isEmpty {
                Button(action: { viewModel.urlInput = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                        .font(.system(size: 17))
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 36)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(UIColor.tertiarySystemFill))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
        )
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            let show = viewModel.loading || (navigator.estimatedProgress > 0 && navigator.estimatedProgress < 1)
            if show {
                Rectangle()
                    .fill(Color(hex: "4285F4"))
                    .frame(
                        width: geo.size.width * max(navigator.estimatedProgress, 0.08),
                        height: 2
                    )
                    .animation(.easeInOut(duration: 0.3), value: navigator.estimatedProgress)
            }
        }
        .frame(height: 2)
    }

    // MARK: - New Tab Page

    private var newTabPage: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                if let uiImage = UIImage(named: "komaliconnobg") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 72, height: 72)
                        .opacity(0.35)
                }

                Text(LanguageManager.shared.localized("browser.search_or_url"))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color(UIColor.placeholderText))
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
    }

    // MARK: - Share

    private func shareCurrentPage() {
        guard let url = viewModel.currentURL else { return }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Tab Switcher View

private struct TabSwitcherView: View {
    @ObservedObject var viewModel: KomalSafetyScannerViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.secondarySystemBackground)
                    .ignoresSafeArea()

                if viewModel.tabs.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "square.on.square.dashed")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(Color(UIColor.tertiaryLabel))
                        Text(LanguageManager.shared.localized("browser.no_open_tabs"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(UIColor.secondaryLabel))
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(Array(viewModel.tabs.enumerated()), id: \.element.id) { index, tab in
                                tabCard(tab: tab, index: index)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 80)
                    }
                }
            }
            .navigationTitle(LanguageManager.shared.localized("browser.tabs"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LanguageManager.shared.localized("common.done")) {
                        isPresented = false
                    }
                    .font(.system(size: 16, weight: .medium))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.addNewTab()
                        isPresented = false
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .medium))
                    }
                }
            }
        }
    }

    private func tabCard(tab: BrowserTab, index: Int) -> some View {
        Button {
            viewModel.switchToTab(at: index)
            isPresented = false
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(UIColor.tertiarySystemFill))
                        .frame(width: 40, height: 40)
                    Image(systemName: tab.url != nil ? "globe" : "plus.square")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(tab.title.isEmpty ? LanguageManager.shared.localized("browser.new_tab") : tab.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(UIColor.label))
                        .lineLimit(1)
                    if let url = tab.url {
                        Text(url.host ?? url.absoluteString)
                            .font(.system(size: 12))
                            .foregroundColor(Color(UIColor.secondaryLabel))
                            .lineLimit(1)
                    }
                }

                Spacer()

                if index == viewModel.activeTabIndex {
                    Circle()
                        .fill(Color(hex: "4285F4"))
                        .frame(width: 8, height: 8)
                }

                if viewModel.tabCount > 1 {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.closeTab(at: index)
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(UIColor.tertiaryLabel))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color(UIColor.tertiarySystemFill)))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(index == viewModel.activeTabIndex
                          ? Color(UIColor.systemBackground)
                          : Color(UIColor.systemBackground).opacity(0.7))
                    .shadow(
                        color: index == viewModel.activeTabIndex
                            ? Color.black.opacity(0.08) : Color.clear,
                        radius: 4, x: 0, y: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#endif
