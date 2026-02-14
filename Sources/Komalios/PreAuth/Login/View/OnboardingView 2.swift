#if os(iOS)
import SwiftUI

/// Wrapper that maps the legacy OnboardingView name to PostAuthOnboardingView
struct OnboardingView: View {
    let onComplete: () -> Void

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    var body: some View {
        PostAuthOnboardingView(onComplete: onComplete)
    }
}
#endif
