#if canImport(SwiftUI)
import SwiftUI

struct GateView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let category: ContentCategory
    @State private var pin = ""
    @State private var showMindfulBreak = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                RikiAssistantCard(
                    title: "Riki suggests a pause",
                    message: "This page touches on \(category.label). Let's check in before continuing.",
                    buttonTitle: "Start Mindful Break"
                ) {
                    showMindfulBreak = true
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Parent approval")
                        .font(.headline)
                    SecureField("Enter parent PIN", text: $pin)
                        .textFieldStyle(.roundedBorder)
                    Button("Approve and Continue") {
                        if pin == appState.parentSettings.parentPin {
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                Text("Access is gated for \(appState.currentProfileName) (\(appState.activeProfile.ageGroup.rawValue)).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Gated content")
            .sheet(isPresented: $showMindfulBreak) {
                MindfulBreakView()
            }
        }
    }
}
#endif
