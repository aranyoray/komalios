//
//  DigitalJourneyModels.swift
//  Komalios
//
//  Models for the parent Digital Journey history view
//

import Foundation

struct TopicGroup: Identifiable {
    let id = UUID()
    let topicName: String
    let intentDescription: String
    let emojiSummary: String
    var items: [HistoryItem]
    let isFlagged: Bool
}

struct HistoryItem: Identifiable {
    let id: String // Firestore document ID
    let url: String
    var action: String // BLOCK, GATE, ALLOW - mutable for parent overrides
    let category: String?
    let subcategory: String?
    let timestamp: Date
    let emojiResponse: String?
    let pageTitle: String?
    let childName: String?

    init(from event: AppHistoryEvent) {
        self.id = event.id
        self.url = event.url
        self.action = event.action
        self.category = event.category
        self.subcategory = event.subcategory
        self.timestamp = event.timestamp
        self.emojiResponse = event.emojiResponse
        self.pageTitle = event.pageTitle
        self.childName = event.childName
    }

    /// Initialize from a local BrowsingEvent (fallback when Firestore is empty)
    init(fromLocal event: BrowsingEvent) {
        self.id = event.id.uuidString
        self.url = event.url.absoluteString
        // Normalize action to BLOCK/GATE/ALLOW
        if let filterAction = event.action {
            self.action = filterAction.rawValue.uppercased()
        } else {
            switch event.eventType {
            case .blocked: self.action = "BLOCK"
            case .gated:   self.action = "GATE"
            default:        self.action = "ALLOW"
            }
        }
        // Split "Category:Subcategory" format
        if let cat = event.category, cat.contains(":") {
            let parts = cat.split(separator: ":", maxSplits: 1)
            self.category = String(parts[0])
            self.subcategory = parts.count > 1 ? String(parts[1]) : nil
        } else {
            self.category = event.category
            self.subcategory = nil
        }
        self.timestamp = event.timestamp
        self.emojiResponse = nil
        self.pageTitle = event.pageTitle
        self.childName = nil
    }
}
