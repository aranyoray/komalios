//
//  BrowsingEvent.swift
//  Komalios
//
//  Browser journey tracking - individual event model
//

import Foundation

/// Type of browsing event
enum BrowsingEventType: String, Codable, CaseIterable {
    case pageLoad     // Page successfully loaded
    case linkClick    // User clicked a link
    case blocked      // URL was blocked by filter
    case gated        // Gate shown (warning/wait screen)
    case allowed      // Passed through filter
    case typed        // User typed URL in address bar
    case search       // Search query
    
    var displayName: String {
        switch self {
        case .pageLoad: return "Page Loaded"
        case .linkClick: return "Link Clicked"
        case .blocked: return "Blocked"
        case .gated: return "Gated"
        case .allowed: return "Allowed"
        case .typed: return "URL Entered"
        case .search: return "Search"
        }
    }
    
    var icon: String {
        switch self {
        case .pageLoad: return "globe"
        case .linkClick: return "link"
        case .blocked: return "xmark.shield.fill"
        case .gated: return "exclamationmark.triangle.fill"
        case .allowed: return "checkmark.circle.fill"
        case .typed: return "keyboard"
        case .search: return "magnifyingglass"
        }
    }
}

/// Single browsing event within a session
struct BrowsingEvent: Codable, Identifiable, Hashable {
    let id: UUID
    let timestamp: Date
    let url: URL
    let eventType: BrowsingEventType
    let category: String?        // Content category (Violence, Financial, etc.)
    let action: FilterAction?    // block/gate/allow action taken
    let pageTitle: String?       // Page title if available
    let domain: String           // Extracted domain for quick access
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        url: URL,
        eventType: BrowsingEventType,
        category: String? = nil,
        action: FilterAction? = nil,
        pageTitle: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.url = url
        self.eventType = eventType
        self.category = category
        self.action = action
        self.pageTitle = pageTitle
        self.domain = url.host ?? "unknown"
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: BrowsingEvent, rhs: BrowsingEvent) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Event Aggregation Helpers
extension Array where Element == BrowsingEvent {
    
    /// Count events by type
    var countByType: [BrowsingEventType: Int] {
        Dictionary(grouping: self, by: { $0.eventType })
            .mapValues { $0.count }
    }
    
    /// Count events by category
    var countByCategory: [String: Int] {
        let categorized = self.compactMap { $0.category }
        return Dictionary(grouping: categorized, by: { $0 })
            .mapValues { $0.count }
    }
    
    /// Count events by domain
    var countByDomain: [String: Int] {
        Dictionary(grouping: self, by: { $0.domain })
            .mapValues { $0.count }
    }
    
    /// Get blocked events count
    var blockedCount: Int {
        self.filter { $0.eventType == .blocked }.count
    }
    
    /// Get gated events count
    var gatedCount: Int {
        self.filter { $0.eventType == .gated }.count
    }
    
    /// Get unique domains visited
    var uniqueDomains: Set<String> {
        Set(self.map { $0.domain })
    }
}
