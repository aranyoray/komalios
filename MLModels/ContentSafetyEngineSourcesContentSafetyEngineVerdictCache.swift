// VerdictCache.swift
// LRU cache for storing verdicts

import Foundation

@available(iOS 17.0, macOS 14.0, *)
actor VerdictCache {
    
    private struct CacheKey: Hashable {
        let contentID: String
        let ageGroup: AgeGroup
    }
    
    private struct CacheEntry {
        let verdict: SafetyVerdict
        let timestamp: Date
        var accessCount: Int
    }
    
    private var cache: [CacheKey: CacheEntry] = [:]
    private let limitMB: Int
    private let maxAge: TimeInterval = 3600 // 1 hour
    
    init(limitMB: Int) {
        self.limitMB = limitMB
    }
    
    // MARK: - Cache Operations
    
    func verdict(for content: ContentInput, ageGroup: AgeGroup) -> SafetyVerdict? {
        let key = CacheKey(contentID: content.id, ageGroup: ageGroup)
        
        guard var entry = cache[key] else {
            return nil
        }
        
        // Check if expired
        if Date().timeIntervalSince(entry.timestamp) > maxAge {
            cache.removeValue(forKey: key)
            return nil
        }
        
        // Update access count
        entry.accessCount += 1
        cache[key] = entry
        
        return entry.verdict
    }
    
    func store(_ verdict: SafetyVerdict, for content: ContentInput, ageGroup: AgeGroup) {
        let key = CacheKey(contentID: content.id, ageGroup: ageGroup)
        let entry = CacheEntry(
            verdict: verdict,
            timestamp: Date(),
            accessCount: 1
        )
        
        cache[key] = entry
        
        // Evict old entries if cache is too large
        evictIfNeeded()
    }
    
    func clear() {
        cache.removeAll()
    }
    
    func clearExpired() {
        let now = Date()
        cache = cache.filter { _, entry in
            now.timeIntervalSince(entry.timestamp) <= maxAge
        }
    }
    
    // MARK: - Private Methods
    
    private func evictIfNeeded() {
        // Simplified eviction based on count
        // In production, calculate actual memory usage
        let maxEntries = limitMB * 100 // Rough estimate
        
        if cache.count > maxEntries {
            // Evict least recently used (lowest access count)
            let sorted = cache.sorted { $0.value.accessCount < $1.value.accessCount }
            let toRemove = sorted.prefix(maxEntries / 10) // Remove 10%
            
            for (key, _) in toRemove {
                cache.removeValue(forKey: key)
            }
        }
    }
}
