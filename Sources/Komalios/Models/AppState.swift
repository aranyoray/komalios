import Foundation

#if canImport(Combine)
import Combine

final class AppState: ObservableObject {
    @Published var activeProfile = ChildProfile.sample
    @Published var parentSettings = ParentSettings.sample
    @Published var accountMode: AccountMode = .child

    var currentProfileName: String {
        accountMode == .guest ? "Guest" : activeProfile.name
    }
}
#else
final class AppState {
    var activeProfile = ChildProfile.sample
    var parentSettings = ParentSettings.sample
    var accountMode: AccountMode = .child

    var currentProfileName: String {
        accountMode == .guest ? "Guest" : activeProfile.name
    }
}
#endif
