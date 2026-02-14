#if canImport(SwiftUI)
import SwiftUI

enum NavigationTab: String, CaseIterable {
    case browser = "Browse"
    case riki = "Talk"
    case reflect = "Reflect"
    case settings = "Settings"
    
    var icon: String {
        switch self {
        case .browser: return "safari.fill"
        case .riki: return "pawprint.fill"
        case .reflect: return "leaf.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct FloatingMenuView: View {
    @Binding var selectedTab: NavigationTab
    var onNewTab: (() -> Void)? = nil
    var onPastTabs: (() -> Void)? = nil
    
    @Namespace private var animation
    
    var body: some View {
        VStack {
            Spacer()
            
            // Liquid Glass Navigation Bar
            HStack(spacing: 4) {
                ForEach(NavigationTab.allCases, id: \.self) { tab in
                    TabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        namespace: animation
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(6)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
            )
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Tab Button

private struct TabButton: View {
    let tab: NavigationTab
    let isSelected: Bool
    let namespace: Namespace.ID
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.system(size: 17, weight: .semibold))
                
                if isSelected {
                    Text(tab.rawValue)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                }
            }
            .foregroundColor(isSelected ? KomalColors.textPrimary : KomalColors.textSecondary)
            .padding(.horizontal, isSelected ? 20 : 16)
            .padding(.vertical, 12)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.white)
                        .matchedGeometryEffect(id: "TAB_INDICATOR", in: namespace)
                        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#if canImport(PreviewsMacros)
#Preview {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()

        FloatingMenuView(selectedTab: .constant(.browser))
    }
}
#endif
#endif
