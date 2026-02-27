//
//  Extensions.swift
//  Komalios
//
//  Utility extensions
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

#if os(iOS)
extension UIApplication {
    func hideKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder),
                   to: nil, from: nil, for: nil)
    }
}

extension String {
    /// Shorthand for localization using current language
    var localized: String {
        LanguageManager.shared.localized(self)
    }

    /// Localize with format arguments
    func localized(_ args: CVarArg...) -> String {
        let template = LanguageManager.shared.localized(self)
        return String(format: template, arguments: args)
    }
}
#endif

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
            // No 18+ AgeBand exists; map to highest. Note: round-trip via toAgeGroup() will return .sixteenToEighteen
            return .age16_18
        }
    }
}

extension AgeBand {
    /// Convert AgeBand back to AgeGroup for resolving filter preferences
    func toAgeGroup() -> AgeGroup {
        switch self {
        case .below10:
            return .under10
        case .age10_13:
            return .tenToThirteen
        case .age13_16:
            return .thirteenToSixteen
        case .age16_18:
            return .sixteenToEighteen
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
