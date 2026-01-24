# Next Steps - Integration Guide
## Step-by-Step Implementation Plan

---

## 🎯 Goal
Integrate the unified decision system into the app so it uses the new `ContentAnalysisService` instead of (or alongside) the existing `ScanNetworkService`.

---

## Step 1: Update ViewModel to Use ContentAnalysisService

### File: `Sources/Komalios/PostAuth/BrowserView/ViewModel/KomalSafetyScannerViewModel.swift`

**Current Flow:**
```swift
// Line ~144: Currently uses ScanNetworkService
scanResult = try await networkService.scanURL(normalizedURL)
```

**New Flow:**
```swift
// Replace with ContentAnalysisService
let decision = try await contentAnalysisService.analyzeContent(
    url: normalizedURL,
    input: buildContentAnalysisInput(url: normalizedURL), // We'll create this helper
    ageBand: appState.activeProfile.ageGroup.toAgeBand(),
    customBlockedKeywords: appState.parentSettings.blockedKeywords,
    customBlockedHosts: appState.parentSettings.blockedHosts
)
```

**Action Items:**
1. Add helper method `buildContentAnalysisInput()` to extract content from URL
2. Update `processScanResult()` to work with `UnifiedDecisionResponse` instead of `ScanResponse`
3. Update history logging to use `logUnifiedDecision()`

---

## Step 2: Create Content Extraction Helper

### File: `Sources/Komalios/PostAuth/BrowserView/ViewModel/KomalSafetyScannerViewModel.swift`

**Add this method:**
```swift
/// Build ContentAnalysisInput from URL (basic version - can be enhanced later)
private func buildContentAnalysisInput(url: String) -> ContentAnalysisInput {
    let urlObj = URL(string: url)
    
    return ContentAnalysisInput(
        url: url,
        htmlText: nil, // Will be extracted from WebView later
        media: nil,    // Will be extracted from WebView later
        structuralMetadata: StructuralMetadata(
            pageType: .generic, // Can be detected from URL patterns
            platform: detectPlatform(from: url)
        ),
        extraMetadata: ExtraMetadata(
            creator: nil,
            sponsors: [],
            links: []
        )
    )
}

/// Detect platform from URL
private func detectPlatform(from urlString: String) -> String? {
    let lowercased = urlString.lowercased()
    if lowercased.contains("youtube.com") || lowercased.contains("youtu.be") {
        return "YouTube"
    } else if lowercased.contains("tiktok.com") {
        return "TikTok"
    } else if lowercased.contains("instagram.com") {
        return "Instagram"
    } else if lowercased.contains("discord.com") {
        return "Discord"
    }
    return nil
}
```

---

## Step 3: Update processScanResult to Handle UnifiedDecisionResponse

### File: `Sources/Komalios/PostAuth/BrowserView/ViewModel/KomalSafetyScannerViewModel.swift`

**Current Method:**
```swift
private func processScanResult(normalizedURL: String) async {
    // Uses scanResult: ScanResponse
}
```

**New Method:**
```swift
private func processUnifiedDecision(normalizedURL: String, decision: UnifiedDecisionResponse) async {
    let ageBand = appState.activeProfile.ageGroup.toAgeBand()
    guard let ageAction = decision.ageActions[ageBand.rawValue] else {
        // Fallback: allow
        loading = false
        if let url = URL(string: normalizedURL) {
            currentURL = url
        }
        return
    }
    
    // Determine category from major categories
    if let firstMajor = decision.majorCategories.first {
        category = ContentCategory(label: firstMajor.name)
    }
    
    blockReason = ageAction.reason ?? "Content filtered"
    
    // Handle action
    handleAction(ageAction.action, result: decision)
    
    // Log to history with categorization
    if let url = URL(string: normalizedURL) {
        historyService.logUnifiedDecision(
            url: url,
            decision: decision,
            ageBand: ageBand
        )
    }
}

// Update handleAction to work with UnifiedDecisionResponse
private func handleAction(_ action: Action, result: UnifiedDecisionResponse) {
    switch action {
    case .block:
        currentURL = nil
        showGate = false
        showKomalCheckIn = false
        loading = false
        showBlocked = true
        
    case .gate:
        if let url = URL(string: result.url) {
            pendingURL = url
        }
        currentURL = nil
        showBlocked = false
        showKomalCheckIn = false
        loading = false
        showGate = true
        
    case .allow:
        showGate = false
        showBlocked = false
        if let url = URL(string: result.url) {
            currentURL = url
            loading = true
        } else {
            loading = false
        }
    }
}
```

---

## Step 4: Update handleUrlSubmit Method

### File: `Sources/Komalios/PostAuth/BrowserView/ViewModel/KomalSafetyScannerViewModel.swift`

**Replace the scan section (around line 144):**
```swift
// OLD:
// Scan URL (for non-trusted sites)
do {
    scanResult = try await networkService.scanURL(normalizedURL)
    print("✅ Scan completed. Result: Success")
    await processScanResult(normalizedURL: normalizedURL)
    // ...
}

// NEW:
// Analyze content using unified system
do {
    let input = buildContentAnalysisInput(url: normalizedURL)
    let decision = try await contentAnalysisService.analyzeContent(
        url: normalizedURL,
        input: input,
        ageBand: appState.activeProfile.ageGroup.toAgeBand(),
        customBlockedKeywords: appState.parentSettings.blockedKeywords,
        customBlockedHosts: appState.parentSettings.blockedHosts
    )
    
    print("✅ Content analysis completed")
    await processUnifiedDecision(normalizedURL: normalizedURL, decision: decision)
    
    // Show check-in after successful search (if it's time)
    if shouldCheckIn && !showBlocked && !showGate {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.showKomalCheckIn = true
            self.updateNextCheckIn()
        }
    }
} catch {
    print("❌ Analysis Error: \(error.localizedDescription)")
    // Fallback: try existing API
    do {
        scanResult = try await networkService.scanURL(normalizedURL)
        await processScanResult(normalizedURL: normalizedURL)
    } catch {
        self.error = error
        loading = false
        if let url = URL(string: normalizedURL) {
            currentURL = url
        }
    }
}
```

---

## Step 5: Add Missing Properties to ViewModel

### File: `Sources/Komalios/PostAuth/BrowserView/ViewModel/KomalSafetyScannerViewModel.swift`

**Add at the top (if not already there):**
```swift
@Published var unifiedDecision: UnifiedDecisionResponse?
```

**Remove or keep (for backward compatibility):**
```swift
@Published var scanResult: ScanResponse? // Keep for now as fallback
```

---

## Step 6: Update ContentAnalysisService to Handle URL-Only Input

### File: `Sources/Komalios/Services/ContentAnalysisService.swift`

**Enhance `analyzeContent()` to handle minimal input:**
```swift
/// Simplified version that works with just URL (for initial integration)
func analyzeContentFromURL(
    url: String,
    ageBand: AgeBand,
    customBlockedKeywords: [String],
    customBlockedHosts: [String]
) async throws -> UnifiedDecisionResponse {
    
    // Build minimal input from URL
    let input = ContentAnalysisInput(
        url: url,
        htmlText: nil, // Will be enhanced later
        media: nil,
        structuralMetadata: StructuralMetadata(
            pageType: .generic,
            platform: nil
        ),
        extraMetadata: nil
    )
    
    return try await analyzeContent(
        url: url,
        input: input,
        ageBand: ageBand,
        customBlockedKeywords: customBlockedKeywords,
        customBlockedHosts: customBlockedHosts
    )
}
```

---

## Step 7: Test the Integration

### Testing Checklist:

1. **Custom Keywords Blocking**
   - Add a keyword in Settings (e.g., "weed")
   - Enter URL containing keyword
   - ✅ Should block immediately

2. **Custom URLs Blocking**
   - Add a URL in Settings
   - Enter that URL
   - ✅ Should block immediately

3. **Trusted Domains**
   - Enter trusted domain (e.g., khanacademy.org)
   - ✅ Should allow without scanning

4. **Regular URL Scanning**
   - Enter a regular URL
   - ✅ Should analyze and show appropriate action

5. **History Categorization**
   - Visit several URLs
   - Check history grouping
   - ✅ Should group by category/subcategory

---

## Step 8: Enhance Content Extraction (Future)

### Extract Real Content from WebView

**Create: `Sources/Komalios/Services/WebViewContentExtractor.swift`**

```swift
import WebKit

class WebViewContentExtractor {
    static func extractContent(from webView: WKWebView) async -> ContentAnalysisInput? {
        // Use JavaScript to extract:
        // - Title
        // - Meta description
        // - Body text
        // - Images
        // - Links
        // - Sponsor information
        
        // This requires JavaScript injection into WebView
        // Implementation details will depend on your WebView setup
    }
}
```

**Then update ViewModel to extract content after page loads:**
```swift
// After WebView finishes loading
if let content = await WebViewContentExtractor.extractContent(from: webView) {
    // Re-analyze with full content
    let decision = try await contentAnalysisService.analyzeContent(...)
}
```

---

## Step 9: Add On-Device ML Models (When Ready)

### Replace Placeholder Methods in ContentAnalysisService:

1. **NLP Model:**
   - Replace `keywordBasedMajorCategoryDetection()` with CoreML model
   - Implement `detectSubcategories()` with actual ML

2. **Vision Model:**
   - Replace placeholder in `analyzeVision()` with Vision framework
   - Add NSFW detection, violence detection, etc.

3. **Audio Model:**
   - Replace placeholder in `analyzeAudio()` with Speech framework
   - Add transcription and NLP on transcript

---

## Step 10: Update History View for Parent Viewing

### File: `Sources/Komalios/PostAuth/Views/Insights/InsightsView.swift`

**Add category/subcategory grouping display:**
```swift
// Show history grouped by category
let byCategory = historyService.getHistoryGroupedByCategory()
// Display in UI

// Show history grouped by subcategory (similar URLs)
let bySubcategory = historyService.getHistoryGroupedBySubcategory()
// Display in UI
```

---

## 📋 Quick Start (Minimal Integration)

If you want to test quickly, do these 3 steps:

### Step 1: Add Helper Method
Add `buildContentAnalysisInput()` to `KomalSafetyScannerViewModel`

### Step 2: Update handleUrlSubmit
Replace `networkService.scanURL()` call with `contentAnalysisService.analyzeContent()`

### Step 3: Update processScanResult
Rename to `processUnifiedDecision()` and update to use `UnifiedDecisionResponse`

---

## ⚠️ Important Notes

1. **Backward Compatibility**: Keep `ScanNetworkService` as fallback for now
2. **Gradual Migration**: You can use both systems side-by-side
3. **Error Handling**: Always have fallback to existing API if new system fails
4. **Testing**: Test thoroughly before removing old system

---

## 🎯 Priority Order

1. **High Priority** (Do First):
   - Step 1: Update ViewModel
   - Step 2: Create content extraction helper
   - Step 3: Update processScanResult
   - Step 4: Update handleUrlSubmit

2. **Medium Priority** (Do Next):
   - Step 6: Enhance ContentAnalysisService
   - Step 7: Test integration

3. **Low Priority** (Future):
   - Step 8: Extract real content from WebView
   - Step 9: Add on-device ML models
   - Step 10: Update history view UI

---

## 📝 Code Snippets Ready to Use

All the code snippets above are ready to copy-paste. The architecture is complete, you just need to wire it up!
