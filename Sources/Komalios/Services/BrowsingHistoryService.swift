//
//  BrowsingHistoryService.swift
//  Komalios
//
//  Singleton service for tracking browsing sessions and persistence
//  Digital Guardian Enhancement: Now includes engagement tracking and image filtering
//

import Foundation
import Combine

final class BrowsingHistoryService: ObservableObject {
    static let shared = BrowsingHistoryService()
    
    // MARK: - Published Properties
    @Published private(set) var currentSession: BrowsingSession?
    @Published private(set) var allSessions: [BrowsingSession] = []
    @Published private(set) var insights: SessionInsights = .empty
    
    // MARK: - Digital Guardian Enhancement: Engagement Insights
    @Published private(set) var engagementInsights: EngagementInsights = .empty
    @Published private(set) var totalImagesFiltered: Int = 0
    @Published private(set) var totalImagesScanned: Int = 0
    
    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private let sessionsFileName = "browsing_sessions.json"
    private var cancellables = Set<AnyCancellable>()
    
    // Digital Guardian Enhancement: Track current navigation context
    private var currentNavigationDepth = 0
    private var lastPageURL: URL?
    
    // MARK: - Initialization
    private init() {
        loadSessions()
        updateInsights()
        updateEngagementInsights()
    }
    
    // MARK: - Session Management
    
    /// Start a new browsing session
    func startSession() {
        // End any existing session first
        if currentSession != nil {
            endSession()
        }
        
        currentSession = BrowsingSession()
        print("📊 Started new browsing session: \(currentSession?.id.uuidString ?? "nil")")
    }
    
    /// End the current session and save
    func endSession() {
        guard var session = currentSession else { return }
        
        session.endSession()
        
        // Only save sessions with events
        if !session.events.isEmpty {
            allSessions.insert(session, at: 0)
            
            // Keep only last 50 sessions
            if allSessions.count > 50 {
                allSessions = Array(allSessions.prefix(50))
            }
            
            saveSessions()
            updateInsights()
            updateEngagementInsights()
            
            // Log session summary
            let imageStats = session.totalImagesFiltered > 0 ? ", \(session.totalImagesFiltered) images filtered" : ""
            print("📊 Ended session with \(session.events.count) events, duration: \(session.durationFormatted)\(imageStats)")
        } else {
            print("📊 Ended empty session, not saving")
        }
        
        // Reset navigation tracking
        currentNavigationDepth = 0
        lastPageURL = nil
        currentSession = nil
    }
    
    // MARK: - Event Logging
    
    /// Log a browsing event with full context
    func logEvent(
        url: URL,
        type: BrowsingEventType,
        category: String? = nil,
        action: FilterAction? = nil,
        pageTitle: String? = nil,
        referrerURL: URL? = nil,
        wasBackNavigation: Bool = false,
        wasForwardNavigation: Bool = false,
        navigationDepth: Int? = nil
    ) {
        guard currentSession != nil else {
            // Auto-start session if needed
            startSession()
            logEvent(url: url, type: type, category: category, action: action, pageTitle: pageTitle,
                    referrerURL: referrerURL, wasBackNavigation: wasBackNavigation,
                    wasForwardNavigation: wasForwardNavigation, navigationDepth: navigationDepth)
            return
        }
        
        // Update navigation depth tracking
        if wasBackNavigation {
            currentNavigationDepth = max(0, currentNavigationDepth - 1)
        } else if !wasForwardNavigation && type == .pageLoad {
            currentNavigationDepth += 1
        }
        
        let event = BrowsingEvent(
            url: url,
            eventType: type,
            category: category,
            action: action,
            pageTitle: pageTitle,
            referrerURL: referrerURL ?? lastPageURL,
            wasBackNavigation: wasBackNavigation,
            wasForwardNavigation: wasForwardNavigation,
            navigationDepth: navigationDepth ?? currentNavigationDepth
        )
        
        currentSession?.addEvent(event)
        
        // Update last page URL for referrer tracking
        if type == .pageLoad {
            lastPageURL = url
        }
        
        // Update insights to include new event
        updateInsights()
        
        print("📊 Logged event: \(type.displayName) - \(url.host ?? url.absoluteString) \(category.map { "[\($0)]" } ?? "") [depth: \(currentNavigationDepth)]")
    }
    
    /// Log a blocked URL event
    func logBlocked(url: URL, category: String, reason: String) {
        logEvent(url: url, type: .blocked, category: category, action: .block)
    }
    
    /// Log a gated URL event
    func logGated(url: URL, category: String) {
        logEvent(url: url, type: .gated, category: category, action: .gate)
    }
    
    /// Log a page load event with Digital Guardian context
    func logPageLoad(
        url: URL,
        title: String? = nil,
        referrerURL: URL? = nil,
        wasBackNavigation: Bool = false,
        wasForwardNavigation: Bool = false,
        navigationDepth: Int? = nil
    ) {
        logEvent(
            url: url,
            type: .pageLoad,
            action: .allow,
            pageTitle: title,
            referrerURL: referrerURL,
            wasBackNavigation: wasBackNavigation,
            wasForwardNavigation: wasForwardNavigation,
            navigationDepth: navigationDepth
        )
    }
    
    /// Log a typed URL event
    func logTypedURL(url: URL) {
        logEvent(url: url, type: .typed)
    }
    
    // MARK: - Digital Guardian Enhancement: Engagement Updates
    
    /// Update the current event's engagement metrics
    func updateCurrentEventEngagement(
        scrollDepth: Int? = nil,
        scrollEvents: Int? = nil,
        dwellTimeSeconds: TimeInterval? = nil
    ) {
        guard currentSession != nil, !currentSession!.events.isEmpty else { return }
        
        currentSession?.updateLastEvent(with: (
            dwellTime: dwellTimeSeconds,
            scrollDepth: scrollDepth,
            scrollCount: scrollEvents,
            exitURL: nil
        ))
    }
    
    /// Log an image filter event
    func logImageFiltered(event: ImageFilterEvent) {
        guard currentSession != nil else {
            startSession()
            logImageFiltered(event: event)
            return
        }
        
        currentSession?.addImageFilterEvent(event)
        
        // Update totals
        if event.wasFiltered {
            totalImagesFiltered += 1
        }
        totalImagesScanned += 1
        
        // Update insights
        updateInsights()
        updateEngagementInsights()
        
        print("🛡️ Logged image filter: \(event.detectedCategory.displayName) - \(event.action.displayName)")
    }
    
    /// Log image filtering stats for current page
    func updateCurrentEventImageStats(scanned: Int, filtered: Int, categories: [String]) {
        guard currentSession != nil, !currentSession!.events.isEmpty else { return }
        
        let lastIndex = currentSession!.events.count - 1
        currentSession?.events[lastIndex].updateEngagement(
            imagesScanned: scanned,
            imagesFiltered: filtered,
            filteredCategories: categories.isEmpty ? nil : categories
        )
    }
    
    // MARK: - Data Access
    
    /// Get insights for all sessions
    func getInsights() -> SessionInsights {
        return insights
    }
    
    /// Get engagement insights
    func getEngagementInsights() -> EngagementInsights {
        return engagementInsights
    }
    
    /// Get category chart data
    func getCategoryChartData() -> [CategoryChartData] {
        let counts = insights.categoryCounts
        
        return counts.map { category, count in
            CategoryChartData(
                category: category,
                count: count,
                color: CategoryChartData.categoryColors[category] ?? "gray"
            )
        }
        .sorted { $0.count > $1.count }
    }
    
    /// Get timeline chart data for last 24 hours
    func getTimelineData() -> [TimelineChartData] {
        let now = Date()
        let calendar = Calendar.current
        
        // Get events from last 24 hours (including current session)
        let dayAgo = calendar.date(byAdding: .hour, value: -24, to: now)!
        var allEvents = allSessions.flatMap { $0.events }
        if let current = currentSession {
            allEvents.append(contentsOf: current.events)
        }
        let recentEvents = allEvents.filter { $0.timestamp >= dayAgo }
        
        // Group by hour
        var hourlyData: [Date: (blocked: Int, gated: Int, allowed: Int)] = [:]
        
        for event in recentEvents {
            let hour = calendar.dateInterval(of: .hour, for: event.timestamp)?.start ?? event.timestamp
            var counts = hourlyData[hour] ?? (0, 0, 0)
            
            switch event.eventType {
            case .blocked:
                counts.blocked += 1
            case .gated:
                counts.gated += 1
            default:
                counts.allowed += 1
            }
            
            hourlyData[hour] = counts
        }
        
        // Create chart data
        return hourlyData.map { hour, counts in
            TimelineChartData(
                hour: hour,
                blockedCount: counts.blocked,
                gatedCount: counts.gated,
                allowedCount: counts.allowed
            )
        }
        .sorted { $0.hour < $1.hour }
    }
    
    // MARK: - Digital Guardian Enhancement: Engagement Data Access
    
    /// Get top engaged domains
    func getTopEngagedDomains(limit: Int = 10) -> [DomainEngagement] {
        var sessionsForAnalysis = allSessions
        if let current = currentSession {
            sessionsForAnalysis.insert(current, at: 0)
        }
        
        // Aggregate by domain
        let allEvents = sessionsForAnalysis.flatMap { $0.events }.filter { $0.eventType == .pageLoad }
        let byDomain = Dictionary(grouping: allEvents, by: { $0.domain })
        
        return byDomain.map { domain, events in
            let avgDwell = events.compactMap { $0.dwellTimeSeconds }.reduce(0, +) / max(Double(events.count), 1)
            let avgScroll = events.compactMap { $0.scrollDepthPercent }.reduce(0, +) / max(events.count, 1)
            let filtered = events.compactMap { $0.imagesFiltered }.reduce(0, +)
            
            return DomainEngagement(
                domain: domain,
                avgDwellTimeSeconds: avgDwell,
                visitCount: events.count,
                avgScrollDepth: avgScroll,
                imagesFiltered: filtered
            )
        }
        .sorted { $0.avgDwellTimeSeconds > $1.avgDwellTimeSeconds }
        .prefix(limit)
        .map { $0 }
    }
    
    /// Get image filter summary by category
    func getImageFilterSummary() -> [String: Int] {
        var sessionsForAnalysis = allSessions
        if let current = currentSession {
            sessionsForAnalysis.insert(current, at: 0)
        }
        
        var summary: [String: Int] = [:]
        for session in sessionsForAnalysis {
            for (category, count) in session.imageFilterBreakdown {
                summary[category, default: 0] += count
            }
        }
        
        return summary
    }
    
    /// Get navigation patterns
    func getNavigationPatterns() -> NavigationPatterns {
        var sessionsForAnalysis = allSessions
        if let current = currentSession {
            sessionsForAnalysis.insert(current, at: 0)
        }
        
        let allEvents = sessionsForAnalysis.flatMap { $0.events }
        let totalNavigations = allEvents.count
        
        guard totalNavigations > 0 else { return .empty }
        
        let backCount = allEvents.filter { $0.wasBackNavigation }.count
        let forwardCount = allEvents.filter { $0.wasForwardNavigation }.count
        let rapidCount = allEvents.filter { ($0.dwellTimeSeconds ?? Double.infinity) < 10 && $0.dwellTimeSeconds != nil }.count
        let maxDepth = allEvents.map { $0.navigationDepth }.max() ?? 0
        let avgNavsPerSession = Double(totalNavigations) / max(Double(sessionsForAnalysis.count), 1)
        
        return NavigationPatterns(
            averageSessionDepth: maxDepth,
            backNavigationRate: Double(backCount) / Double(totalNavigations),
            forwardNavigationRate: Double(forwardCount) / Double(totalNavigations),
            rapidSwitchingCount: rapidCount,
            averageNavigationsPerSession: avgNavsPerSession
        )
    }
    
    /// Clear all session history
    func clearHistory() {
        allSessions = []
        currentSession = nil
        insights = .empty
        engagementInsights = .empty
        totalImagesFiltered = 0
        totalImagesScanned = 0
        currentNavigationDepth = 0
        lastPageURL = nil
        saveSessions()
        print("📊 Cleared all browsing history")
    }
    
    // MARK: - Persistence
    
    private var sessionsFileURL: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent(sessionsFileName)
    }
    
    private func saveSessions() {
        do {
            let data = try JSONEncoder().encode(allSessions)
            try data.write(to: sessionsFileURL)
            print("📊 Saved \(allSessions.count) sessions to disk")
        } catch {
            print("📊 Error saving sessions: \(error)")
        }
    }
    
    private func loadSessions() {
        guard fileManager.fileExists(atPath: sessionsFileURL.path) else {
            print("📊 No existing sessions file found")
            return
        }
        
        do {
            let data = try Data(contentsOf: sessionsFileURL)
            allSessions = try JSONDecoder().decode([BrowsingSession].self, from: data)
            print("📊 Loaded \(allSessions.count) sessions from disk")
        } catch {
            print("📊 Error loading sessions: \(error)")
        }
    }
    
    private func updateInsights() {
        // Include current session in insights if it has events
        var sessionsForInsights = allSessions
        if let current = currentSession, !current.events.isEmpty {
            sessionsForInsights.insert(current, at: 0)
        }
        insights = SessionInsights.from(sessions: sessionsForInsights)
    }
    
    // MARK: - Digital Guardian Enhancement: Engagement Insights
    
    private func updateEngagementInsights() {
        var sessionsForAnalysis = allSessions
        if let current = currentSession, !current.events.isEmpty {
            sessionsForAnalysis.insert(current, at: 0)
        }
        
        guard !sessionsForAnalysis.isEmpty else {
            engagementInsights = .empty
            return
        }
        
        let allEvents = sessionsForAnalysis.flatMap { $0.events }
        let allImageFilterEvents = sessionsForAnalysis.flatMap { $0.imageFilterEvents }
        let pageLoads = allEvents.filter { $0.eventType == .pageLoad }
        
        // Calculate averages
        let pageLoadsWithDwell = pageLoads.filter { $0.dwellTimeSeconds != nil }
        let avgDwell = pageLoadsWithDwell.isEmpty ? 0 : pageLoadsWithDwell.compactMap { $0.dwellTimeSeconds }.reduce(0, +) / Double(pageLoadsWithDwell.count)
        
        let pageLoadsWithScroll = pageLoads.filter { $0.scrollDepthPercent != nil }
        let avgScroll = pageLoadsWithScroll.isEmpty ? 0 : pageLoadsWithScroll.compactMap { $0.scrollDepthPercent }.reduce(0, +) / pageLoadsWithScroll.count
        
        // Get domain engagement
        let topDomains = getTopEngagedDomains(limit: 10)
        
        // Get navigation patterns
        let patterns = getNavigationPatterns()
        
        // Get image filter summary
        let filterSummary = allImageFilterEvents.filteredByCategory
        
        // Calculate meaningful engagement rate
        let meaningfulCount = pageLoads.filter { event in
            (event.dwellTimeSeconds ?? 0) >= 5 || (event.scrollDepthPercent ?? 0) >= 25
        }.count
        let meaningfulRate = pageLoads.isEmpty ? 0 : Double(meaningfulCount) / Double(pageLoads.count)
        
        engagementInsights = EngagementInsights(
            averageDwellTimeSeconds: avgDwell,
            averageScrollDepthPercent: avgScroll,
            totalImagesScanned: allEvents.compactMap { $0.imagesScanned }.reduce(0, +),
            totalImagesFiltered: allImageFilterEvents.filteredCount,
            filteredByCategory: filterSummary,
            mostEngagedDomains: topDomains,
            navigationPatterns: patterns,
            totalPageViews: pageLoads.count,
            meaningfulEngagementRate: meaningfulRate
        )
        
        // Update totals
        totalImagesFiltered = allImageFilterEvents.filteredCount
        totalImagesScanned = allEvents.compactMap { $0.imagesScanned }.reduce(0, +)
    }
}
