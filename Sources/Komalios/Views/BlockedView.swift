#if canImport(SwiftUI)
import SwiftUI

struct BlockedView: View {
    let category: ContentCategory
    let reason: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.slash")
                .font(.system(size: 60))
                .foregroundStyle(.red)
            Text("This content is blocked")
                .font(.title2)
                .bold()
            Text("Komal blocked this page because it includes \(category.label.lowercased()) content.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text(reason)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Ask a parent if you need access.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
#endif
