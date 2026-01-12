#if canImport(SwiftUI)
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var newBlockedKeyword = ""
    @State private var newBlockedHost = ""

    var body: some View {
        Form {
            Section("Account Mode") {
                Picker("Mode", selection: $appState.accountMode) {
                    ForEach(AccountMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                Text(appState.accountMode == .guest ? "Guest mode keeps browsing anonymous with default rules." : "Child mode applies this profile's settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Child Profile") {
                TextField("Name", text: $appState.activeProfile.name)
                Picker("Age Group", selection: $appState.activeProfile.ageGroup) {
                    ForEach(AgeGroup.allCases) { group in
                        Text(group.rawValue).tag(group)
                    }
                }
            }

            Section("Parent Controls") {
                Toggle("Notify on blocked attempts", isOn: $appState.parentSettings.notifyOnBlock)
                Toggle("Force Safe Search where available", isOn: $appState.parentSettings.safeSearchEnabled)
                SecureField("Parent PIN", text: $appState.parentSettings.parentPin)
            }

            Section("Blocked Keywords") {
                HStack {
                    TextField("Add keyword", text: $newBlockedKeyword)
                    Button("Add") {
                        guard !newBlockedKeyword.isEmpty else { return }
                        appState.parentSettings.blockedKeywords.append(newBlockedKeyword)
                        newBlockedKeyword = ""
                    }
                }
                ForEach(appState.parentSettings.blockedKeywords, id: \.self) { keyword in
                    Text(keyword)
                }
            }

            Section("Blocked Sites") {
                HStack {
                    TextField("Add host", text: $newBlockedHost)
                    Button("Add") {
                        guard !newBlockedHost.isEmpty else { return }
                        appState.parentSettings.blockedHosts.append(newBlockedHost)
                        newBlockedHost = ""
                    }
                }
                ForEach(appState.parentSettings.blockedHosts, id: \.self) { host in
                    Text(host)
                }
            }

            Section("Komal Defaults") {
                Text("Komal uses curated blocklists and parent rules to keep browsing calm and age-appropriate.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }
}
#endif
