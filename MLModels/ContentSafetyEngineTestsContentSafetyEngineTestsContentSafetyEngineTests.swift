// ContentSafetyEngineTests.swift
// Unit tests for content safety engine

import Testing
@testable import ContentSafetyEngine

@available(iOS 17.0, macOS 14.0, *)
@Suite("Content Safety Engine Tests")
struct ContentSafetyEngineTests {
    
    // MARK: - Basic Analysis Tests
    
    @Test("Analyze safe text content")
    func analyzeSafeContent() async throws {
        let engine = try await ContentSafetyEngine()
        
        let content = ContentInput(
            text: "This is a nice educational article about science and nature.",
            domain: "wikipedia.org"
        )
        
        let verdict = try await engine.analyze(content, for: .age10to13)
        
        #expect(verdict.action == .allow)
        #expect(verdict.categories.isEmpty)
    }
    
    @Test("Analyze explicit content")
    func analyzeExplicitContent() async throws {
        let engine = try await ContentSafetyEngine()
        
        let content = ContentInput(
            text: "This is porn and explicit sexual content XXX nude photos.",
            domain: "unknown.com"
        )
        
        let verdict = try await engine.analyze(content, for: .age10to13)
        
        #expect(verdict.action == .block)
        #expect(verdict.categories.contains(.explicit))
    }
    
    @Test("Analyze violence content")
    func analyzeViolenceContent() async throws {
        let engine = try await ContentSafetyEngine()
        
        let content = ContentInput(
            text: "Graphic violence with blood and gore, brutal fighting scene.",
            domain: "unknown.com"
        )
        
        let verdict = try await engine.analyze(content, for: .below10)
        
        #expect(verdict.action == .block)
        #expect(verdict.categories.contains(.violence))
    }
    
    // MARK: - Age Group Tests
    
    @Test("Different verdicts for different age groups")
    func ageGroupDifferences() async throws {
        let engine = try await ContentSafetyEngine()
        
        let content = ContentInput(
            text: "Mild fighting scene in sports context, boxing match highlights.",
            domain: "espn.com"
        )
        
        let verdict10 = try await engine.analyze(content, for: .below10)
        let verdict13 = try await engine.analyze(content, for: .age13to16)
        let verdict18 = try await engine.analyze(content, for: .adult)
        
        // Younger ages should be more restrictive
        #expect(verdict10.action == .block || verdict10.action == .gate)
        #expect(verdict13.action == .gate || verdict13.action == .allow)
        #expect(verdict18.action == .allow)
    }
    
    // MARK: - Domain Override Tests
    
    @Test("Blocked domain override")
    func blockedDomainOverride() async throws {
        let engine = try await ContentSafetyEngine()
        
        let content = ContentInput(
            text: "This is safe content.",
            domain: "pornhub.com"
        )
        
        let verdict = try await engine.analyze(content, for: .adult)
        
        #expect(verdict.action == .block)
        #expect(verdict.reason.contains("blocklist"))
    }
    
    @Test("Allowed domain override")
    func allowedDomainOverride() async throws {
        let engine = try await ContentSafetyEngine()
        
        let content = ContentInput(
            text: "Some content with violence keywords fight punch.",
            domain: "apple.com"
        )
        
        let verdict = try await engine.analyze(content, for: .below10)
        
        #expect(verdict.action == .allow)
        #expect(verdict.reason.contains("allowlist"))
    }
    
    // MARK: - Batch Analysis Tests
    
    @Test("Batch analysis")
    func batchAnalysis() async throws {
        let engine = try await ContentSafetyEngine()
        
        let contents = [
            ContentInput(text: "Safe educational content"),
            ContentInput(text: "Explicit porn XXX content"),
            ContentInput(text: "Violence and gore"),
            ContentInput(text: "Another safe article")
        ]
        
        let verdicts = try await engine.analyze(contents, for: .age10to13)
        
        #expect(verdicts.count == 4)
        #expect(verdicts[0].action == .allow)
        #expect(verdicts[1].action == .block)
        #expect(verdicts[2].action == .block || verdicts[2].action == .gate)
        #expect(verdicts[3].action == .allow)
    }
    
    // MARK: - Cache Tests
    
    @Test("Cache hit on repeated analysis")
    func cacheHit() async throws {
        let engine = try await ContentSafetyEngine()
        
        let content = ContentInput(
            id: "test-123",
            text: "Some content to cache"
        )
        
        let start1 = CFAbsoluteTimeGetCurrent()
        let verdict1 = try await engine.analyze(content, for: .age10to13)
        let time1 = CFAbsoluteTimeGetCurrent() - start1
        
        let start2 = CFAbsoluteTimeGetCurrent()
        let verdict2 = try await engine.analyze(content, for: .age10to13)
        let time2 = CFAbsoluteTimeGetCurrent() - start2
        
        // Second call should be faster (cache hit)
        #expect(time2 < time1)
        #expect(verdict1.action == verdict2.action)
    }
    
    // MARK: - Performance Tests
    
    @Test("Text-only analysis latency < 200ms")
    func textLatency() async throws {
        let engine = try await ContentSafetyEngine()
        
        let content = ContentInput(
            text: String(repeating: "Some sample text for performance testing. ", count: 50)
        )
        
        let start = CFAbsoluteTimeGetCurrent()
        let verdict = try await engine.analyze(content, for: .age10to13)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        
        #expect(elapsed < 0.2) // 200ms
        #expect(verdict.details?.processingTimeMs != nil)
    }
    
    // MARK: - Multi-Label Tests
    
    @Test("Multiple categories detected")
    func multipleCategories() async throws {
        let engine = try await ContentSafetyEngine()
        
        let content = ContentInput(
            text: "Explicit porn with violence and gambling casino content."
        )
        
        let verdict = try await engine.analyze(content, for: .below10)
        
        #expect(verdict.action == .block)
        #expect(verdict.categories.count >= 2)
    }
}

// MARK: - Policy Engine Tests

@available(iOS 17.0, macOS 14.0, *)
@Suite("Policy Engine Tests")
struct PolicyEngineTests {
    
    @Test("Load policy artifacts")
    func loadPolicyArtifacts() async throws {
        let engine = try await PolicyEngine()
        
        // Should load without errors
        let policy = await engine.policy(for: .explicit, ageGroup: .below10)
        #expect(policy.defaultAction == .block)
    }
    
    @Test("Domain management")
    func domainManagement() async throws {
        let engine = try await PolicyEngine()
        
        await engine.addBlockedDomain("test-blocked.com")
        let isBlocked = await engine.isBlockedDomain("test-blocked.com")
        #expect(isBlocked == true)
        
        await engine.removeBlockedDomain("test-blocked.com")
        let isStillBlocked = await engine.isBlockedDomain("test-blocked.com")
        #expect(isStillBlocked == false)
    }
    
    @Test("Custom keywords")
    func customKeywords() async throws {
        let engine = try await PolicyEngine()
        
        await engine.setCustomBlockedKeywords(["badword1", "badword2"])
        let keywords = await engine.customBlockedKeywords()
        
        #expect(keywords?.count == 2)
        #expect(keywords?.contains("badword1") == true)
    }
}

// MARK: - Integration Tests

@available(iOS 17.0, macOS 14.0, *)
@Suite("Integration Tests")
struct IntegrationTests {
    
    @Test("End-to-end safe content flow")
    func endToEndSafe() async throws {
        let engine = try await ContentSafetyEngine()
        
        let content = ContentInput(
            text: "Learn about the solar system and planets in our educational guide.",
            domain: "khanacademy.org"
        )
        
        let verdict = try await engine.analyze(content, for: .age10to13)
        
        #expect(verdict.action == .allow)
        #expect(verdict.confidence > 0.5)
        #expect(verdict.details != nil)
    }
    
    @Test("End-to-end unsafe content flow with vision")
    func endToEndUnsafe() async throws {
        let engine = try await ContentSafetyEngine()
        
        // Simulate explicit content that would trigger vision
        let content = ContentInput(
            text: "Adult content XXX porn explicit photos",
            media: nil, // In real test, would include explicit image
            domain: "unknown.com"
        )
        
        let verdict = try await engine.analyze(content, for: .below10)
        
        #expect(verdict.action == .block)
        #expect(verdict.categories.contains(.explicit))
        #expect(verdict.confidence > 0.7)
    }
}
