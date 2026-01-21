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
    
    /// Log a blocked URL event with optional subcategory
    func logBlocked(url: URL, category: String, reason: String, subcategory: String? = nil) {
        let fullCategory = subcategory != nil ? "\(category):\(subcategory!)" : category
        logEvent(url: url, type: .blocked, category: fullCategory, action: .block, pageTitle: reason)
    }
    
    /// Log a gated URL event with optional subcategory
    func logGated(url: URL, category: String, subcategory: String? = nil) {
        let fullCategory = subcategory != nil ? "\(category):\(subcategory!)" : category
        logEvent(url: url, type: .gated, category: fullCategory, action: .gate)
    }
    
    /// Log a page load event
    func logPageLoad(url: URL, title: String? = nil) {
        logEvent(url: url, type: .pageLoad, action: .allow, pageTitle: title)
    }
    
    /// Log a typed URL event
    func logTypedURL(url: URL) {
        logEvent(url: url, type: .typed)
    }
    
    /// Log from unified decision response (for categorization and history tracking)
    func logUnifiedDecision(url: URL, decision: UnifiedDecisionResponse, ageBand: AgeBand) {
        let category = decision.historyCategory ?? "Unknown"
        let subcategory = decision.historySubcategory
        
        // Get action for the specific age band
        let ageAction = decision.ageActions[ageBand.rawValue]
        let action = ageAction?.action.toFilterAction() ?? .allow
        
        switch action {
        case .block:
            logBlocked(url: url, category: category, reason: ageAction?.reason ?? "Blocked", subcategory: subcategory)
        case .gate:
            logGated(url: url, category: category, subcategory: subcategory)
        case .allow:
            logAllowed(url: url, category: category, subcategory: subcategory)
        }
    }
    
    /// Log allowed URL with optional category/subcategory
    func logAllowed(url: URL, category: String? = nil, subcategory: String? = nil) {
        let fullCategory: String?
        if let cat = category {
            fullCategory = subcategory != nil ? "\(cat):\(subcategory!)" : cat
        } else {
            fullCategory = nil
        }
        logEvent(url: url, type: .allowed, category: fullCategory, action: .allow)
    }
    
    // MARK: - Data Access
    
    /// Get insights for all sessions
    func getInsights() -> SessionInsights {
        return insights
    }
    
    /// Get category chart data
    func getCategoryChartData() -> [CategoryChartData] {
        let categoryCounts = insights.categoryCounts
        return categoryCounts.map { category, count in
            CategoryChartData(
                category: category,
                count: count,
                color: CategoryChartData.categoryColors[category] ?? "gray"
            )
        }.sorted { $0.count > $1.count }
    }
    
    /// Get timeline chart data
    func getTimelineData() -> [TimelineChartData] {
        // Group events by hour
        var hourlyData: [Date: (blocked: Int, gated: Int, allowed: Int)] = [:]
        
        for session in allSessions {
            for event in session.events {
                let hour = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: event.timestamp), minute: 0, second: 0, of: event.timestamp) ?? event.timestamp
                
                if hourlyData[hour] == nil {
                    hourlyData[hour] = (0, 0, 0)
                }
                
                switch event.eventType {
                case .blocked:
                    hourlyData[hour]?.blocked += 1
                case .gated:
                    hourlyData[hour]?.gated += 1
                case .allowed, .pageLoad:
                    hourlyData[hour]?.allowed += 1
                default:
                    break
                }
            }
        }
        
        return hourlyData.map { hour, counts in
            TimelineChartData(
                hour: hour,
                blockedCount: counts.blocked,
                gatedCount: counts.gated,
                allowedCount: counts.allowed
            )
        }.sorted { $0.hour < $1.hour }
    }
    
    /// Get history grouped by category (for parent viewing)
    func getHistoryGroupedByCategory() -> [String: [BrowsingEvent]] {
        var grouped: [String: [BrowsingEvent]] = [:]
        
        // Process all sessions
        for session in allSessions {
            for event in session.events {
                // Extract base category (before ":")
                let baseCategory = event.category?.split(separator: ":").first.map { String($0) } ?? "Uncategorized"
                if grouped[baseCategory] == nil {
                    grouped[baseCategory] = []
                }
                grouped[baseCategory]?.append(event)
            }
        }
        
        // Include current session
        if let current = currentSession {
            for event in current.events {
                let baseCategory = event.category?.split(separator: ":").first.map { String($0) } ?? "Uncategorized"
                if grouped[baseCategory] == nil {
                    grouped[baseCategory] = []
                }
                grouped[baseCategory]?.append(event)
            }
        }
        
        return grouped
    }
    
    /// Get history grouped by subcategory (for similar URLs grouping)
    func getHistoryGroupedBySubcategory() -> [String: [BrowsingEvent]] {
        var grouped: [String: [BrowsingEvent]] = [:]
        
        for session in allSessions {
            for event in session.events {
                // Extract subcategory from "category:subcategory" format
                if let category = event.category, category.contains(":") {
                    let parts = category.split(separator: ":")
                    if parts.count > 1 {
                        let subcat = String(parts[1])
                        if grouped[subcat] == nil {
                            grouped[subcat] = []
                        }
                        grouped[subcat]?.append(event)
                    }
                }
            }
        }
        
        // Include current session
        if let current = currentSession {
            for event in current.events {
                if let category = event.category, category.contains(":") {
                    let parts = category.split(separator: ":")
                    if parts.count > 1 {
                        let subcat = String(parts[1])
                        if grouped[subcat] == nil {
                            grouped[subcat] = []
                        }
                        grouped[subcat]?.append(event)
                    }
                }
            }
        }
        
        return grouped
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
