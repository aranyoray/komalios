#if canImport(SwiftUI)
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var newBlockedKeyword = ""
    @State private var newBlockedHost = ""

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                        // Account Mode Section
                        BubblyCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeaderView(icon: "person.circle.fill", title: "Account Mode")

                                Picker("Mode", selection: $appState.accountMode) {
                                    ForEach(AccountMode.allCases) { mode in
                                        Text(mode.rawValue)
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                            .tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .background(KomalColors.warmGray)
                                .clipShape(Capsule())

                                Text(appState.accountMode == .guest ? "Guest mode keeps browsing anonymous with default rules." : "Child mode applies this profile's settings.")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(KomalColors.textSecondary)
                                    .lineSpacing(2)
                            }
                        }

                        // Child Profile Section
                        BubblyCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeaderView(icon: "sparkles", title: "Child Profile")

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Name")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(KomalColors.textSecondary)
                                    TextField("Name", text: $appState.activeProfile.name)
                                        .roundedTextFieldStyle()
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Age Group")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(KomalColors.textSecondary)
                                    Picker("Age Group", selection: $appState.activeProfile.ageGroup) {
                                        ForEach(AgeGroup.allCases) { group in
                                            Text(group.rawValue).tag(group)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(KomalColors.bubblegumPink)
                                }
                            }
                        }

                        // Parent Controls Section
                        BubblyCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeaderView(icon: "lock.shield.fill", title: "Parent Controls")

                                VStack(spacing: 8) {
                                    SettingsToggleRow(
                                        icon: "bell.fill",
                                        title: "Notify on blocked attempts",
                                        isOn: $appState.parentSettings.notifyOnBlock
                                    )

                                    SettingsToggleRow(
                                        icon: "magnifyingglass.circle.fill",
                                        title: "Force Safe Search",
                                        isOn: $appState.parentSettings.safeSearchEnabled
                                    )
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Parent PIN")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(KomalColors.textSecondary)
                                    SecureField("Enter PIN", text: $appState.parentSettings.parentPin)
                                        .roundedTextFieldStyle()
                                }
                            }
                        }

                        // Blocked Keywords Section
                        BubblyCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeaderView(icon: "text.badge.xmark", title: "Blocked Keywords")

                                HStack(spacing: 8) {
                                    TextField("Add keyword", text: $newBlockedKeyword)
                                        .roundedTextFieldStyle()
                                    Button {
                                        guard !newBlockedKeyword.isEmpty else { return }
                                        appState.parentSettings.blockedKeywords.append(newBlockedKeyword)
                                        newBlockedKeyword = ""
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 32))
                                            .foregroundColor(KomalColors.bubblegumPink)
                                    }
                                }

                                if !appState.parentSettings.blockedKeywords.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(appState.parentSettings.blockedKeywords, id: \.self) { keyword in
                                            HStack {
                                                Text(keyword)
                                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                                    .foregroundColor(KomalColors.textPrimary)
                                                Spacer()
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(KomalColors.pearlAqua)
                                            }
                                            .padding(.vertical, 8)
                                        }
                                    }
                                }
                            }
                        }

                        // Blocked Sites Section
                        BubblyCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeaderView(icon: "globe.badge.chevron.backward", title: "Blocked Sites")

                                HStack(spacing: 8) {
                                    TextField("Add host", text: $newBlockedHost)
                                        .roundedTextFieldStyle()
                                    Button {
                                        guard !newBlockedHost.isEmpty else { return }
                                        appState.parentSettings.blockedHosts.append(newBlockedHost)
                                        newBlockedHost = ""
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 32))
                                            .foregroundColor(KomalColors.bubblegumPink)
                                    }
                                }

                                if !appState.parentSettings.blockedHosts.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(appState.parentSettings.blockedHosts, id: \.self) { host in
                                            HStack {
                                                Text(host)
                                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                                    .foregroundColor(KomalColors.textPrimary)
                                                Spacer()
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(KomalColors.pearlAqua)
                                            }
                                            .padding(.vertical, 8)
                                        }
                                    }
                                }
                            }
                        }

                        // Info Section
                        BubblyCard {
                            HStack(spacing: 12) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(KomalColors.pearlAqua)

                                Text("Komal uses curated blocklists and parent rules to keep browsing calm and age-appropriate.")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(KomalColors.textSecondary)
                                    .lineSpacing(3)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }
            }
        }
    }

struct SettingsToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(KomalColors.bubblegumPink)
                .frame(width: 24)

            Text(title)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(KomalColors.bubblegumPink)
        }
        .padding(.vertical, 4)
    }
}

#endif
