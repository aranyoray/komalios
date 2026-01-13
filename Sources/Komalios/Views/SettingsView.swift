#if canImport(SwiftUI)
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var newBlockedKeyword = ""
    @State private var newBlockedHost = ""

    var body: some View {
        ZStack {
            // Clean, slightly off-white background for clearer card separation
            KomalColors.warmGray
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: - Header
                    HStack {
                        Text("Settings")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // MARK: - Account Mode
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 16) {
                            CardHeader(icon: "person.2.circle.fill", title: "Account Mode", color: KomalColors.bubblegumPink)

                            Picker("Mode", selection: $appState.accountMode) {
                                ForEach(AccountMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .colorMultiply(KomalColors.bubblegumPink.opacity(0.1)) // Subtle tint to the picker
                            
                            Text(appState.accountMode == .guest 
                                 ? "Guest mode keeps browsing anonymous with default filters." 
                                 : "Child mode applies your personalized safety settings.")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(KomalColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    // MARK: - Child Profile
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 16) {
                            CardHeader(icon: "sparkles", title: "Child Profile", color: KomalColors.lavenderPurple)

                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Name", systemImage: "pencil")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(KomalColors.textSecondary)
                                    
                                    TextField("Child's Name", text: $appState.activeProfile.name)
                                        .cleanTextFieldStyle()
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Age Group", systemImage: "chart.bar.fill")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(KomalColors.textSecondary)
                                    
                                    Menu {
                                        ForEach(AgeGroup.allCases) { group in
                                            Button {
                                                appState.activeProfile.ageGroup = group
                                            } label: {
                                                HStack {
                                                    Text(group.rawValue)
                                                    if appState.activeProfile.ageGroup == group {
                                                        Image(systemName: "checkmark")
                                                    }
                                                }
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(appState.activeProfile.ageGroup.rawValue)
                                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                                .foregroundColor(KomalColors.textPrimary)
                                            Spacer()
                                            Image(systemName: "chevron.up.chevron.down")
                                                .font(.caption)
                                                .foregroundColor(KomalColors.textSecondary)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(KomalColors.background)
                                        .cornerRadius(12)
                                    }
                                }
                                .frame(width: 140)
                            }
                        }
                    }

                    // MARK: - Parent Controls
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 20) {
                            CardHeader(icon: "lock.shield.fill", title: "Parent Controls", color: KomalColors.pearlAqua)

                            VStack(spacing: 16) {
                                ModernToggleRow(
                                    icon: "bell.badge.fill",
                                    iconColor: KomalColors.bubblegumPink,
                                    title: "Notify on Block",
                                    subtitle: "Get alerts when blocked content is accessed",
                                    isOn: $appState.parentSettings.notifyOnBlock
                                )
                                
                                Divider()
                                
                                ModernToggleRow(
                                    icon: "safari.fill",
                                    iconColor: KomalColors.pearlAqua,
                                    title: "Force Safe Search",
                                    subtitle: "Enforce strict safety on search engines",
                                    isOn: $appState.parentSettings.safeSearchEnabled
                                )
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Parent PIN")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(KomalColors.textSecondary)
                                
                                SecureField("Enter 4-digit PIN", text: $appState.parentSettings.parentPin)
                                    .cleanTextFieldStyle()
                                    .keyboardType(.numberPad)
                            }
                        }
                    }

                    // MARK: - Blocked Content
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 16) {
                            CardHeader(icon: "hand.raised.fill", title: "Blocked Content", color: KomalColors.bubblegumPink)

                            // Keywords
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Keywords")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(KomalColors.textPrimary)
                                
                                HStack(spacing: 12) {
                                    TextField("Add keyword (e.g. 'weapons')", text: $newBlockedKeyword)
                                        .cleanTextFieldStyle()
                                        .submitLabel(.done)
                                        .onSubmit {
                                            addKeyword()
                                        }
                                    
                                    Button(action: addKeyword) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 44, height: 44)
                                            .background(KomalColors.bubblegumPink)
                                            .clipShape(Circle())
                                            .shadow(color: KomalColors.bubblegumPink.opacity(0.3), radius: 4, x: 0, y: 2)
                                    }
                                }
                                
                                if !appState.parentSettings.blockedKeywords.isEmpty {
                                    FlowLayout(spacing: 8) {
                                        ForEach(appState.parentSettings.blockedKeywords, id: \.self) { keyword in
                                            ChipView(text: keyword, color: KomalColors.bubblegumPink) {
                                                if let index = appState.parentSettings.blockedKeywords.firstIndex(of: keyword) {
                                                    appState.parentSettings.blockedKeywords.remove(at: index)
                                                }
                                            }
                                        }
                                    }
                                } else {
                                    Text("No custom keywords added yet.")
                                        .font(.caption)
                                        .italic()
                                        .foregroundColor(KomalColors.textSecondary)
                                }
                            }
                            
                            Divider().padding(.vertical, 4)
                            
                            // Sites
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Websites")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(KomalColors.textPrimary)
                                
                                HStack(spacing: 12) {
                                    TextField("Add website (e.g. 'badsite.com')", text: $newBlockedHost)
                                        .cleanTextFieldStyle()
                                        .keyboardType(.URL)
                                        .textInputAutocapitalization(.never)
                                        .submitLabel(.done)
                                        .onSubmit {
                                            addHost()
                                        }
                                    
                                    Button(action: addHost) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 44, height: 44)
                                            .background(KomalColors.pearlAqua)
                                            .clipShape(Circle())
                                            .shadow(color: KomalColors.pearlAqua.opacity(0.3), radius: 4, x: 0, y: 2)
                                    }
                                }
                                
                                if !appState.parentSettings.blockedHosts.isEmpty {
                                    FlowLayout(spacing: 8) {
                                        ForEach(appState.parentSettings.blockedHosts, id: \.self) { host in
                                            ChipView(text: host, color: KomalColors.pearlAqua) {
                                                if let index = appState.parentSettings.blockedHosts.firstIndex(of: host) {
                                                    appState.parentSettings.blockedHosts.remove(at: index)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Use space at bottom
                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
    }
    
    private func addKeyword() {
        let trimmed = newBlockedKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !appState.parentSettings.blockedKeywords.contains(trimmed) {
            withAnimation {
                appState.parentSettings.blockedKeywords.append(trimmed)
            }
        }
        newBlockedKeyword = ""
    }
    
    private func addHost() {
        let trimmed = newBlockedHost.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return }
        if !appState.parentSettings.blockedHosts.contains(trimmed) {
            withAnimation {
                appState.parentSettings.blockedHosts.append(trimmed)
            }
        }
        newBlockedHost = ""
    }
}

// MARK: - Components

struct SettingsCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

struct CardHeader: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)
            
            Spacer()
        }
    }
}

struct ModernToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(KomalColors.textSecondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(KomalColors.bubblegumPink)
        }
    }
}

struct ChipView: View {
    let text: String
    let color: Color
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// Simple FlowLayout for chips
struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        return rows.last?.maxY ?? .zero
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        for row in rows {
            for item in row.items {
                item.view.place(at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + item.y), proposal: .unspecified)
            }
        }
    }

    struct Row {
        var items: [Item] = []
        var maxY: CGSize = .zero
    }

    struct Item {
        var view: LayoutSubview
        var x: CGFloat
        var y: CGFloat
    }

    func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentRow = Row()
        var x: CGFloat = 0
        var y: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && !currentRow.items.isEmpty {
                y += (currentRow.items.map { $0.view.sizeThatFits(.unspecified).height }.max() ?? 0) + spacing
                rows.append(currentRow)
                currentRow = Row()
                x = 0
            }
            currentRow.items.append(Item(view: view, x: x, y: y))
            x += size.width + spacing
        }
        if !currentRow.items.isEmpty {
            let rowHeight = currentRow.items.map { $0.view.sizeThatFits(.unspecified).height }.max() ?? 0
            currentRow.maxY = CGSize(width: maxWidth, height: y + rowHeight)
            rows.append(currentRow)
        }
        return rows
    }
}

// Custom Modifiers

struct CleanTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(KomalColors.background)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
    }
}

extension View {
    func cleanTextFieldStyle() -> some View {
        modifier(CleanTextFieldStyle())
    }
}

#endif
