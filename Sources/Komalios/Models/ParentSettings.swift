import Foundation

struct ParentSettings: Codable {
    var blockedKeywords: [String]
    var blockedHosts: [String]
    var blockedInterests: [String]
    var parentPin: String
    var notifyOnBlock: Bool
    var safeSearchEnabled: Bool

    static let sample = ParentSettings(
        blockedKeywords: [],
        blockedHosts: [],
        blockedInterests: [],
        parentPin: "1234",
        notifyOnBlock: true,
        safeSearchEnabled: true
    )
}
