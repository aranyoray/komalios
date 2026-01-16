import Foundation

enum AgeGroup: String, CaseIterable, Identifiable, Codable {
    case under10 = "< 10"
    case tenToThirteen = "10–13"
    case thirteenToSixteen = "13–16"
    case sixteenToEighteen = "16–18"
    case eighteenPlus = "18+"

    var id: String { rawValue }
}

enum AccountMode: String, CaseIterable, Identifiable, Codable {
    case child = "Child Account"
    case guest = "Guest Mode"

    var id: String { rawValue }
}

struct ChildProfile: Identifiable, Codable {
    var id = UUID()
    var name: String
    var ageGroup: AgeGroup

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
