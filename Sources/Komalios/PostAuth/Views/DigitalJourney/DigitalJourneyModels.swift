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
}
