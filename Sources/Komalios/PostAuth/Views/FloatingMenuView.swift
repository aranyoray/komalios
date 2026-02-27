#if canImport(SwiftUI)
import SwiftUI

enum NavigationTab: String, CaseIterable {
    case browser = "browser"
    case riki = "riki"
    case reflect = "reflect"
    case settings = "settings"

    var icon: String {
        switch self {
        case .browser: return "globe"
        case .riki: return "pawprint.fill"
        case .reflect: return "leaf.fill"
        case .settings: return "gearshape.fill"
        }
    }

    func displayName(lang: LanguageManager) -> String {
        switch self {
        case .browser: return lang.localized("menu.browse")
        case .riki: return lang.localized("menu.talk")
        case .reflect: return lang.localized("menu.reflect")
        case .settings: return lang.localized("menu.settings")
        }
    }
}

struct FloatingMenuView: View {
    @Binding var selectedTab: NavigationTab
    @EnvironmentObject var lang: LanguageManager
    @EnvironmentObject var appState: AppState
    @Namespace private var animation

    /// Display name for the Riki tab — uses selected avatar's name
    private var rikiDisplayName: String {
        let avatarIndex = appState.activeProfile.selectedAvatarIndex
        if let character = RikiCharacter.allCharacters.first(where: { $0.id == avatarIndex }) {
            return character.name
        }
        return lang.localized("menu.talk")
    }

    var body: some View {
        // Only the tab bar — no full-screen VStack/Spacer overlay.
        // Positioned at the bottom via ZStack(alignment: .bottom) in RootView.
        HStack(spacing: 0) {
            ForEach(NavigationTab.allCases, id: \.self) { tab in
                TabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    namespace: animation,
                    displayNameOverride: tab == .riki ? rikiDisplayName : nil
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.10), radius: 12, x: 0, y: -2)
        )
        .padding(.horizontal, 6)
        .padding(.bottom, 2)
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Tab Button

private struct TabButton: View {
    let tab: NavigationTab
    let isSelected: Bool
    let namespace: Namespace.ID
    var displayNameOverride: String? = nil
    let onTap: () -> Void

    private var displayName: String {
        displayNameOverride ?? tab.displayName(lang: LanguageManager.shared)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18, weight: isSelected ? .semibold : .regular))

                Text(displayName)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? KomalColors.bubblegumPink : KomalColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
