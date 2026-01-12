import Foundation

struct ParentSettings {
    var blockedKeywords: [String]
    var blockedHosts: [String]
    var blockedInterests: [String]
    var parentPin: String
    var notifyOnBlock: Bool
    var safeSearchEnabled: Bool

    static let sample = ParentSettings(
        blockedKeywords: ["loot box", "vape", "apology video"],
        blockedHosts: ["example.com"],
        blockedInterests: ["Roblox"],
        parentPin: "1234",
        notifyOnBlock: true,
        safeSearchEnabled: true
    )
}
