#if canImport(SwiftUI)
import SwiftUI

enum NavigationTab: String, CaseIterable {
    case browser = "Browser"
    case riki = "Riki"
    case settings = "Settings"
    
    var icon: String {
        switch self {
        case .browser: return "safari.fill"
        case .riki: return "pawprint.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct FloatingMenuView: View {
    @Binding var selectedTab: NavigationTab
    var onNewTab: (() -> Void)? = nil
    @State private var isExpanded = false
    
    // Reduced sizes based on user feedback
    private let mainButtonSize: CGFloat = 72 // Increased for larger Komal image
    private let optionButtonSize: CGFloat = 64 // Increased
    private let secondaryButtonSize: CGFloat = 48
    private let expansionRadius: CGFloat = 125 // Increased for larger buttons
    
    var body: some View {
        ZStack {
            // Dimmed background when expanded
            if isExpanded {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            isExpanded = false
                        }
                    }
                    .zIndex(0)
            }
            
            VStack {
                Spacer()
                
                // Different layout for browser vs other tabs
                if selectedTab == .browser {
                    browserLayout
                } else {
                    centeredLayout
                }
            }
            .zIndex(1)
            .allowsHitTesting(isExpanded || true)
        }
    }
    
    // MARK: - Browser Layout (Komal on right, new tab button on left)
    private var browserLayout: some View {
        HStack(alignment: .bottom) {
            // Left: New tab button (3 dots)
            newTabButton
            
            Spacer()
            
            // Right: Main Komal button with expandable menu
            ZStack(alignment: .bottomTrailing) {
                // Anchor
                Color.clear
                    .frame(width: mainButtonSize, height: mainButtonSize)
                
                mainButton
                
                if isExpanded {
                    ForEach(Array(NavigationTab.allCases.enumerated()), id: \.element) { index, tab in
                        // Angles: -180 (Left), -135 (Top-Left), -90 (Top)
                        let angle = -180.0 + (Double(index) * 45.0)
                        optionButton(for: tab, angle: angle)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
    
    // MARK: - Centered Layout (for Riki and Settings)
    private var centeredLayout: some View {
        ZStack(alignment: .bottom) {
            // Anchor
            Color.clear
                .frame(width: mainButtonSize, height: mainButtonSize)
                
            mainButton
            
            if isExpanded {
                ForEach(Array(NavigationTab.allCases.enumerated()), id: \.element) { index, tab in
                    // Angles: -135 (Top-Left), -90 (Top), -45 (Top-Right)
                    let angle = -135.0 + (Double(index) * 45.0)
                    optionButton(for: tab, angle: angle)
                }
            }
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - New Tab Button
    private var newTabButton: some View {
        Button {
            onNewTab?()
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: secondaryButtonSize, height: secondaryButtonSize)
                
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)
            }
        }
        .frame(width: secondaryButtonSize, height: secondaryButtonSize)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Main Komal Button
    private var mainButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                isExpanded.toggle()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: mainButtonSize, height: mainButtonSize)
                
                if let uiImage = UIImage(named: "komaliconnobg") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: mainButtonSize - 4, height: mainButtonSize - 4) // Reduced padding for larger image
                        .clipShape(Circle())
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(KomalColors.bubblegumPink)
                }
            }
        }
        // Explicitly set frame on the button itself to prevent expansion
        .frame(width: mainButtonSize, height: mainButtonSize)
        .rotationEffect(.degrees(isExpanded ? 45 : 0))
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        .zIndex(10)
    }
    
    // MARK: - Option Button
    private func optionButton(for tab: NavigationTab, angle: Double) -> some View {
        let radians = angle * .pi / 180
        let xOffset = cos(radians) * expansionRadius
        let yOffset = sin(radians) * expansionRadius
        
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedTab = tab
                isExpanded = false
            }
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: optionButtonSize, height: optionButtonSize)
                
                VStack(spacing: 2) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(selectedTab == tab ? KomalColors.bubblegumPink : .primary)
                    
                    Text(tab.rawValue)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(selectedTab == tab ? KomalColors.bubblegumPink : .secondary)
                }
            }
        }
        .frame(width: optionButtonSize, height: optionButtonSize)
        .offset(x: xOffset, y: yOffset)
        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
        .transition(.scale.combined(with: .opacity))
        .zIndex(5)
    }
}
#endif
