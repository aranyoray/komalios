//
//  KomalInterventionTrigger.swift
//  Komalios
//
//  Defines what triggered a Komal intervention
//

import Foundation

enum KomalInterventionTrigger: Equatable {
    case prolongedDwelling(seconds: Int, url: String)
    case rapidClicking(count: Int)
    case negativeContent(category: String)
    case behavioralPattern(description: String)
    
    var title: String {
        switch self {
        case .prolongedDwelling:
            return "I noticed you've been here a while"
        case .rapidClicking:
            return "You seem to be clicking a lot"
        case .negativeContent:
            return "This content might not be helpful"
        case .behavioralPattern:
            return "I wanted to check in with you"
        }
    }
    
    var message: String {
        switch self {
        case .prolongedDwelling(let seconds, _):
            return "You've been viewing this content for \(seconds) seconds. How are you feeling? Would you like to take a break?"
        case .rapidClicking(let count):
            return "I noticed you've clicked \(count) times quickly. Are you looking for something specific? I can help!"
        case .negativeContent(let category):
            return "This \(category) content might be upsetting. Would you like to explore something more positive?"
        case .behavioralPattern(let description):
            return description
        }
    }
    
    var icon: String {
        switch self {
        case .prolongedDwelling:
            return "clock.fill"
        case .rapidClicking:
            return "hand.tap.fill"
        case .negativeContent:
            return "heart.fill"
        case .behavioralPattern:
            return "sparkles"
        }
    }
}
