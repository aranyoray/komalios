//
//  ContentCategory.swift
//  Komalios
//
//  Content classification categories
//

import Foundation

enum ContentCategory: String, Codable, CaseIterable {
    case violence = "Violence"
    case adult = "Adult Content"
    case hate = "Hate Speech"
    case selfHarm = "Self Harm"
    case drugs = "Drugs"
    case weapons = "Weapons"
    case profanity = "Profanity"
    case gambling = "Gambling"
    case unknown = "Unknown"
    case safe = "Safe"
    
    init(label: String) {
        let lowercased = label.lowercased()
        
        if lowercased.contains("violence") || lowercased.contains("violent") {
            self = .violence
        } else if lowercased.contains("adult") || lowercased.contains("sexual") || lowercased.contains("nsfw") {
            self = .adult
        } else if lowercased.contains("hate") || lowercased.contains("discrimination") {
            self = .hate
        } else if lowercased.contains("self") && lowercased.contains("harm") {
            self = .selfHarm
        } else if lowercased.contains("drug") || lowercased.contains("substance") {
            self = .drugs
        } else if lowercased.contains("weapon") || lowercased.contains("gun") {
            self = .weapons
        } else if lowercased.contains("profan") || lowercased.contains("curse") {
            self = .profanity
        } else if lowercased.contains("gambl") {
            self = .gambling
        } else if lowercased.contains("safe") {
            self = .safe
        } else {
            self = .unknown
        }
    }
    
    var icon: String {
        switch self {
        case .violence: return "exclamationmark.triangle.fill"
        case .adult: return "hand.raised.fill"
        case .hate: return "exclamationmark.bubble.fill"
        case .selfHarm: return "heart.slash.fill"
        case .drugs: return "pills.fill"
        case .weapons: return "shield.slash.fill"
        case .profanity: return "text.bubble.fill"
        case .gambling: return "dice.fill"
        case .safe: return "checkmark.shield.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .safe:
            return "green"
        case .unknown:
            return "gray"
        default:
            return "red"
        }
    }
}
