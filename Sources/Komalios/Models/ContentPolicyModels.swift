import Foundation

enum AgeGroup: String, CaseIterable, Identifiable, Codable {
    case under10 = "< 10"
    case tenToThirteen = "10–13"
    case thirteenToSixteen = "13–16"
    case sixteenToEighteen = "16–18"
    case eighteenPlus = "18+"

    var id: String { rawValue }
}

/// Operating mode for the app.
/// - `.child`: Default mode with content filtering active (normal usage).
/// - `.guest`: Parent/guardian mode with elevated permissions (temporarily unlocked).
///   Named "guest" for historical reasons; resets to `.child` when the app goes to background.
enum AccountMode: String, CaseIterable, Identifiable, Codable {
    case child = "Child Account"
    case guest = "Parent Mode"

    var id: String { rawValue }
}

struct ChildProfile: Identifiable, Codable {
    var id = UUID()
    var name: String
    var ageGroup: AgeGroup
    var selectedAvatarIndex: Int = 1

    enum CodingKeys: String, CodingKey {
        case id, name, ageGroup, selectedAvatarIndex
    }

    init(name: String, ageGroup: AgeGroup, selectedAvatarIndex: Int = 1) {
        self.name = name
        self.ageGroup = ageGroup
        self.selectedAvatarIndex = selectedAvatarIndex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        ageGroup = try container.decode(AgeGroup.self, forKey: .ageGroup)
        selectedAvatarIndex = try container.decodeIfPresent(Int.self, forKey: .selectedAvatarIndex) ?? 1
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(ageGroup, forKey: .ageGroup)
        try container.encode(selectedAvatarIndex, forKey: .selectedAvatarIndex)
    }

    static let sample = ChildProfile(name: "Komal", ageGroup: .tenToThirteen)
}

enum ContentCategory: String, CaseIterable, Hashable {
    case violence
    case explicitContent
    case substances
    case financial
    case platformRisks
    case socialTopics
    case selfHarm
    case gaming
    case unknown

    var label: String {
        switch self {
        case .violence: return "Violence & Disturbing"
        case .explicitContent: return "Explicit & Body"
        case .substances: return "Substances & Addictive"
        case .financial: return "Financial & Commercial"
        case .platformRisks: return "Platform Risks"
        case .socialTopics: return "Social & Cultural"
        case .selfHarm: return "Self-harm or Suicide"
        case .gaming: return "Gaming & Betting"
        case .unknown: return "Uncategorized"
        }
    }
    
    init(label: String) {
        switch label {
        case "Violence & Disturbing": self = .violence
        case "Explicit & Body": self = .explicitContent
        case "Substances & Addictive": self = .substances
        case "Financial & Commercial": self = .financial
        case "Platform Risks": self = .platformRisks
        case "Social & Cultural": self = .socialTopics
        case "Self-harm or Suicide": self = .selfHarm
        case "Gaming & Betting": self = .gaming
        default: self = .unknown
        }
    }
}
