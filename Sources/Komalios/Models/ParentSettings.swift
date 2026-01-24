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

    func hostVariants(for host: String) -> Set<String> {
        let normalized = normalizedHost(host)
        var variants: Set<String> = [normalized]
        if normalized.hasPrefix("www.") {
            variants.insert(String(normalized.dropFirst(4)))
        } else {
            variants.insert("www.\(normalized)")
        }
        return variants
    }

    func isHostBlocked(_ host: String?) -> Bool {
        guard let host else { return false }
        let variants = hostVariants(for: host)
        let blocked = Set(blockedHosts.map(normalizedHost))
        return variants.contains { variant in
            blocked.contains(where: { variant == $0 || variant.hasSuffix(".\($0)") })
        }
    }

    func normalizedHost(_ host: String) -> String {
        host
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
