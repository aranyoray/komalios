//
//  BrowsingHistoryService.swift
//  Komalios
//
//  Singleton service for tracking browsing sessions and persistence
//

import Foundation
import Combine

final class BrowsingHistoryService: ObservableObject {
    static let shared = BrowsingHistoryService()
    
    // MARK: - Published Properties
    @Published private(set) var currentSession: BrowsingSession?
    @Published private(set) var allSessions: [BrowsingSession] = []
    @Published private(set) var insights: SessionInsights = .empty
    
    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private let sessionsFileName = "browsing_sessions.json"
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private init() {
        loadSessions()
        updateInsights()
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
            
            print("📊 Ended session with \(session.events.count) events, duration: \(session.durationFormatted)")
        } else {
            print("📊 Ended empty session, not saving")
        }
        
        currentSession = nil
    }
    
    // MARK: - Event Logging
    
    /// Log a browsing event
    func logEvent(
        url: URL,
        type: BrowsingEventType,
        category: String? = nil,
        action: FilterAction? = nil,
        pageTitle: String? = nil
    ) {
        guard currentSession != nil else {
            // Auto-start session if needed
            startSession()
            logEvent(url: url, type: type, category: category, action: action, pageTitle: pageTitle)
            return
        }
        
        let event = BrowsingEvent(
            url: url,
            eventType: type,
            category: category,
            action: action,
            pageTitle: pageTitle
        )
        
        currentSession?.addEvent(event)
        
        // Update insights to include new event
        updateInsights()
        
        print("📊 Logged event: \(type.displayName) - \(url.host ?? url.absoluteString) \(category.map { "[\($0)]" } ?? "")")
    }
    
    /// Log a blocked URL event
    func logBlocked(url: URL, category: String, reason: String) {
        logEvent(url: url, type: .blocked, category: category, action: .block)
    }
    
    /// Log a gated URL event
    func logGated(url: URL, category: String) {
        logEvent(url: url, type: .gated, category: category, action: .gate)
    }
    
    /// Log a page load event
    func logPageLoad(url: URL, title: String? = nil) {
        logEvent(url: url, type: .pageLoad, action: .allow, pageTitle: title)
    }
    
    /// Log a typed URL event
    func logTypedURL(url: URL) {
        logEvent(url: url, type: .typed)
    }
    
    // MARK: - Data Access
    
    /// Get insights for all sessions
    func getInsights() -> SessionInsights {
        return insights
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
    
    /// Clear all session history
    func clearHistory() {
        allSessions = []
        currentSession = nil
        insights = .empty
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
}
