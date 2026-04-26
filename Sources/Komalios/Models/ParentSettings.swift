import Foundation

struct ParentSettings: Codable {
    var blockedKeywords: [String]
    var blockedHosts: [String]
    var blockedInterests: [String]
    var notifyOnBlock: Bool
    var safeSearchEnabled: Bool
    var biometricEnabled: Bool
    var eyeTrackingEnabled: Bool
    /// Maximum voice chat session duration in minutes. 0 = no limit. Default: 20.
    var voiceChatSessionCapMinutes: Int

    static let sample = ParentSettings(
        blockedKeywords: [],
        blockedHosts: [],
        blockedInterests: [],
        notifyOnBlock: true,
        safeSearchEnabled: true,
        biometricEnabled: false,
        eyeTrackingEnabled: false,
        voiceChatSessionCapMinutes: 20
    )

    // Support decoding old data that still has parentPin
    enum CodingKeys: String, CodingKey {
        case blockedKeywords, blockedHosts, blockedInterests
        case notifyOnBlock, safeSearchEnabled, biometricEnabled, eyeTrackingEnabled
        case voiceChatSessionCapMinutes
        // Legacy key for migration
        case parentPin
    }

    init(blockedKeywords: [String], blockedHosts: [String], blockedInterests: [String],
         notifyOnBlock: Bool, safeSearchEnabled: Bool, biometricEnabled: Bool = false,
         eyeTrackingEnabled: Bool = false, voiceChatSessionCapMinutes: Int = 20) {
        self.blockedKeywords = blockedKeywords
        self.blockedHosts = blockedHosts
        self.blockedInterests = blockedInterests
        self.notifyOnBlock = notifyOnBlock
        self.safeSearchEnabled = safeSearchEnabled
        self.biometricEnabled = biometricEnabled
        self.eyeTrackingEnabled = eyeTrackingEnabled
        self.voiceChatSessionCapMinutes = voiceChatSessionCapMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        blockedKeywords = try container.decodeIfPresent([String].self, forKey: .blockedKeywords) ?? []
        blockedHosts = try container.decodeIfPresent([String].self, forKey: .blockedHosts) ?? []
        blockedInterests = try container.decodeIfPresent([String].self, forKey: .blockedInterests) ?? []
        notifyOnBlock = try container.decodeIfPresent(Bool.self, forKey: .notifyOnBlock) ?? true
        safeSearchEnabled = try container.decodeIfPresent(Bool.self, forKey: .safeSearchEnabled) ?? true
        biometricEnabled = try container.decodeIfPresent(Bool.self, forKey: .biometricEnabled) ?? false
        eyeTrackingEnabled = try container.decodeIfPresent(Bool.self, forKey: .eyeTrackingEnabled) ?? false
        voiceChatSessionCapMinutes = try container.decodeIfPresent(Int.self, forKey: .voiceChatSessionCapMinutes) ?? 20
        // parentPin is silently ignored on decode (migrated to Keychain)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(blockedKeywords, forKey: .blockedKeywords)
        try container.encode(blockedHosts, forKey: .blockedHosts)
        try container.encode(blockedInterests, forKey: .blockedInterests)
        try container.encode(notifyOnBlock, forKey: .notifyOnBlock)
        try container.encode(safeSearchEnabled, forKey: .safeSearchEnabled)
        try container.encode(biometricEnabled, forKey: .biometricEnabled)
        try container.encode(eyeTrackingEnabled, forKey: .eyeTrackingEnabled)
        try container.encode(voiceChatSessionCapMinutes, forKey: .voiceChatSessionCapMinutes)
    }
}
