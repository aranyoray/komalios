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
    
    // MARK: - Digital Guardian Enhancement: Image Filter Events
    var imageFilterEvents: [ImageFilterEvent]
    
    init(id: UUID = UUID(), startTime: Date = Date(), events: [BrowsingEvent] = [], imageFilterEvents: [ImageFilterEvent] = []) {
        self.id = id
        self.startTime = startTime
        self.events = events
        self.imageFilterEvents = imageFilterEvents
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
        Array(events.countByDomain
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { (domain: $0.key, count: $0.value) })
    }
    
    /// Is session currently active
    var isActive: Bool {
        endTime == nil
    }
    
    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    /// Date formatted for display
    var dateFormatted: String {
        BrowsingSession.displayFormatter.string(from: startTime)
    }
    
    // MARK: - Digital Guardian Enhancement: Engagement Metrics
    
    /// Average dwell time across all page loads in session
    var averageDwellTime: TimeInterval {
        let pageLoads = events.filter { $0.eventType == .pageLoad && $0.dwellTimeSeconds != nil }
        guard !pageLoads.isEmpty else { return 0 }
        return pageLoads.compactMap { $0.dwellTimeSeconds }.reduce(0, +) / Double(pageLoads.count)
    }
    
    /// Average scroll depth across all page loads
    var averageScrollDepth: Int {
        let pageLoads = events.filter { $0.eventType == .pageLoad && $0.scrollDepthPercent != nil }
        guard !pageLoads.isEmpty else { return 0 }
        return pageLoads.compactMap { $0.scrollDepthPercent }.reduce(0, +) / pageLoads.count
    }
    
    /// Total images scanned in this session
    var totalImagesScanned: Int {
        events.compactMap { $0.imagesScanned }.reduce(0, +)
    }
    
    /// Total images filtered in this session
    var totalImagesFiltered: Int {
        imageFilterEvents.filteredCount
    }
    
    /// Images filtered from imageFilterEvents
    var imagesProtected: Int {
        imageFilterEvents.filter { $0.wasFiltered }.count
    }
    
    /// Maximum navigation depth reached
    var maxNavigationDepth: Int {
        events.map { $0.navigationDepth }.max() ?? 0
    }
    
    /// Count of rapid site switches (under 10 seconds)
    var rapidSwitchCount: Int {
        events.filter { ($0.dwellTimeSeconds ?? 0) < 10 && $0.dwellTimeSeconds != nil }.count
    }
    
    /// Back navigation count
    var backNavigationCount: Int {
        events.filter { $0.wasBackNavigation }.count
    }
    
    /// Forward navigation count
    var forwardNavigationCount: Int {
        events.filter { $0.wasForwardNavigation }.count
    }
    
    /// Navigation path (ordered list of domains visited)
    var navigationPath: [String] {
        events
            .filter { $0.eventType == .pageLoad }
            .sorted { $0.timestamp < $1.timestamp }
            .map { $0.domain }
    }
    
    /// Top engaged domains with dwell time
    var topEngagedDomains: [(domain: String, avgDwellTime: TimeInterval, visits: Int)] {
        let pageLoads = events.filter { $0.eventType == .pageLoad }
        let byDomain = Dictionary(grouping: pageLoads, by: { $0.domain })
        
        return Array(byDomain.map { domain, events in
            let avgDwell = events.compactMap { $0.dwellTimeSeconds }.reduce(0, +) / max(Double(events.count), 1)
            return (domain: domain, avgDwellTime: avgDwell, visits: events.count)
        }
        .sorted { $0.avgDwellTime > $1.avgDwellTime }
        .prefix(5))
    }
    
    /// Image filter breakdown by category
    var imageFilterBreakdown: [String: Int] {
        imageFilterEvents.filteredByCategory
    }
    
    // MARK: - Mutations
    
    mutating func addEvent(_ event: BrowsingEvent) {
        events.append(event)
    }
    
    mutating func addImageFilterEvent(_ event: ImageFilterEvent) {
        imageFilterEvents.append(event)
    }
    
    mutating func updateLastEvent(with engagement: (dwellTime: TimeInterval?, scrollDepth: Int?, scrollCount: Int?, exitURL: URL?)) {
        guard !events.isEmpty else { return }
        let lastIndex = events.count - 1
        events[lastIndex].updateEngagement(
            dwellTime: engagement.dwellTime,
            scrollDepth: engagement.scrollDepth,
            scrollCount: engagement.scrollCount,
            exitURL: engagement.exitURL
        )
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
    
    // MARK: - Digital Guardian Enhancement: Engagement Insights
    let averageDwellTimeSeconds: TimeInterval
    let averageScrollDepthPercent: Int
    let totalImagesScanned: Int
    let totalImagesFiltered: Int
    let imageFilterByCategory: [String: Int]
    let rapidSwitchingCount: Int
    let backNavigationCount: Int
    let averageNavigationDepth: Double
    
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
            eventTypeCounts: [:],
            averageDwellTimeSeconds: 0,
            averageScrollDepthPercent: 0,
            totalImagesScanned: 0,
            totalImagesFiltered: 0,
            imageFilterByCategory: [:],
            rapidSwitchingCount: 0,
            backNavigationCount: 0,
            averageNavigationDepth: 0
        )
    }
    
    /// Create insights from array of sessions
    static func from(sessions: [BrowsingSession]) -> SessionInsights {
        let allEvents = sessions.flatMap { $0.events }
        let allImageFilterEvents = sessions.flatMap { $0.imageFilterEvents }
        
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
        
        // Calculate engagement metrics
        let pageLoadsWithDwell = allEvents.filter { $0.eventType == .pageLoad && $0.dwellTimeSeconds != nil }
        let avgDwell = pageLoadsWithDwell.isEmpty ? 0 : pageLoadsWithDwell.compactMap { $0.dwellTimeSeconds }.reduce(0, +) / Double(pageLoadsWithDwell.count)
        
        let pageLoadsWithScroll = allEvents.filter { $0.eventType == .pageLoad && $0.scrollDepthPercent != nil }
        let avgScroll = pageLoadsWithScroll.isEmpty ? 0 : pageLoadsWithScroll.compactMap { $0.scrollDepthPercent }.reduce(0, +) / pageLoadsWithScroll.count
        
        let totalScanned = allEvents.compactMap { $0.imagesScanned }.reduce(0, +)
        let totalFiltered = allImageFilterEvents.filteredCount
        
        let rapidCount = allEvents.filter { guard let dwell = $0.dwellTimeSeconds else { return false }; return dwell < 10 }.count
        let backCount = allEvents.filter { $0.wasBackNavigation }.count
        
        let maxDepths = sessions.map { $0.maxNavigationDepth }
        let avgDepth = maxDepths.isEmpty ? 0 : Double(maxDepths.reduce(0, +)) / Double(maxDepths.count)
        
        return SessionInsights(
            totalSessions: sessions.count,
            totalEvents: allEvents.count,
            totalBlockedCount: allEvents.blockedCount,
            totalGatedCount: allEvents.gatedCount,
            totalDuration: sessions.reduce(0) { $0 + $1.duration },
            categoryCounts: categoryCounts,
            domainCounts: domainCounts,
            eventTypeCounts: eventTypeCounts,
            averageDwellTimeSeconds: avgDwell,
            averageScrollDepthPercent: avgScroll,
            totalImagesScanned: totalScanned,
            totalImagesFiltered: totalFiltered,
            imageFilterByCategory: allImageFilterEvents.filteredByCategory,
            rapidSwitchingCount: rapidCount,
            backNavigationCount: backCount,
            averageNavigationDepth: avgDepth
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
