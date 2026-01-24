//
//  Extensions.swift
//  Komalios
//
//  Utility extensions
//

import Foundation

extension AgeGroup {
    /// Convert AgeGroup to AgeBand for unified decision system
    func toAgeBand() -> AgeBand {
        switch self {
        case .under10:
            return .below10
        case .tenToThirteen:
            return .age10_13
        case .thirteenToSixteen:
            return .age13_16
        case .sixteenToEighteen:
            return .age16_18
        case .eighteenPlus:
            return .age16_18 // Map 18+ to highest age band
        }
    }
}

extension FilterAction {
    /// Convert FilterAction to Action enum
    func toAction() -> Action {
        switch self {
        case .block:
            return .block
        case .gate:
            return .gate
        case .allow:
            return .allow
        }
    }
}

extension Action {
    /// Convert Action to FilterAction enum
    func toFilterAction() -> FilterAction {
        switch self {
        case .block:
            return .block
        case .gate:
            return .gate
        case .allow:
            return .allow
        }
    }
}
