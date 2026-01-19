//
//  BrowsingSession.swift
//  Komalios
//
//  Browser journey tracking - session container model
//

import Foundation

/// A browsing session containing multiple events
struct BrowsingSession: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var events: [BrowsingEvent]
    
    init(id: UUID = UUID(), startTime: Date = Date(), events: [BrowsingEvent] = []) {
        self.id = id
        self.startTime = startTime
        self.events = events
    }
    
    // MARK: - Computed Properties
    
    /// Duration of the session
    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
    
    /// Formatted duration string
    var durationFormatted: String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
    
    /// Total number of page loads
    var totalPageLoads: Int {
        events.filter { $0.eventType == .pageLoad }.count
    }
    
    /// Total sites blocked
    var blockedCount: Int {
        events.blockedCount
    }
    
    /// Total sites gated
    var gatedCount: Int {
        events.gatedCount
    }
    
    /// Unique domains visited
    var uniqueDomainsCount: Int {
        events.uniqueDomains.count
    }
    
    /// Category breakdown as dictionary
    var categoryBreakdown: [String: Int] {
        events.countByCategory
    }
    
    /// Top domains by visit count
    var topDomains: [(domain: String, count: Int)] {
        events.countByDomain
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { (domain: $0.key, count: $0.value) }
    }
    
    /// Is session currently active
    var isActive: Bool {
        endTime == nil
    }
    
    /// Date formatted for display
    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }
    
    // MARK: - Mutations
    
    mutating func addEvent(_ event: BrowsingEvent) {
        events.append(event)
    }
    
    mutating func endSession() {
        endTime = Date()
    }
}

// MARK: - Session Insights
struct SessionInsights: Codable {
    let totalSessions: Int
    let totalEvents: Int
    let totalBlockedCount: Int
    let totalGatedCount: Int
    let totalDuration: TimeInterval
    let categoryCounts: [String: Int]
    let domainCounts: [String: Int]
    let eventTypeCounts: [String: Int]
    
    /// Empty insights for initial state
    static var empty: SessionInsights {
        SessionInsights(
            totalSessions: 0,
            totalEvents: 0,
            totalBlockedCount: 0,
            totalGatedCount: 0,
            totalDuration: 0,
            categoryCounts: [:],
            domainCounts: [:],
            eventTypeCounts: [:]
        )
    }
    
    /// Create insights from array of sessions
    static func from(sessions: [BrowsingSession]) -> SessionInsights {
        let allEvents = sessions.flatMap { $0.events }
        
        var categoryCounts: [String: Int] = [:]
        for (category, count) in allEvents.countByCategory {
            categoryCounts[category] = count
        }
        
        var domainCounts: [String: Int] = [:]
        for (domain, count) in allEvents.countByDomain {
            domainCounts[domain] = count
        }
        
        var eventTypeCounts: [String: Int] = [:]
        for (type, count) in allEvents.countByType {
            eventTypeCounts[type.rawValue] = count
        }
        
        return SessionInsights(
            totalSessions: sessions.count,
            totalEvents: allEvents.count,
            totalBlockedCount: allEvents.blockedCount,
            totalGatedCount: allEvents.gatedCount,
            totalDuration: sessions.reduce(0) { $0 + $1.duration },
            categoryCounts: categoryCounts,
            domainCounts: domainCounts,
            eventTypeCounts: eventTypeCounts
        )
    }
}

// MARK: - Chart Data Models
struct CategoryChartData: Identifiable {
    let id = UUID()
    let category: String
    let count: Int
    let color: String  // Color name for chart
    
    static let categoryColors: [String: String] = [
        "Violence & Disturbing": "red",
        "Explicit & Body Content": "pink",
        "Substances & Addictive": "orange",
        "Financial & Commercial": "green",
        "Media & Platform Risks": "blue",
        "Social & Cultural": "purple"
    ]
}

struct TimelineChartData: Identifiable {
    let id = UUID()
    let hour: Date
    let blockedCount: Int
    let gatedCount: Int
    let allowedCount: Int
    
    var total: Int {
        blockedCount + gatedCount + allowedCount
    }
}
