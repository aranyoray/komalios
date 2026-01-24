# Unified Decision Architecture
## Content Filtering System - Implementation Guide

This document describes the implementation of the unified decision system for content filtering, following the specification provided.

---

## Overview

The system implements an **on-device first** approach with cloud fallback, following this pipeline:

1. **Custom Rules Check** (parent-defined keywords/URLs) → BLOCK immediately if matched
2. **On-device NLP** → Text analysis for major categories and subcategories
3. **On-device Vision** → Image/video analysis
4. **On-device Audio** → Speech transcription and analysis
5. **Cross-content Analysis** → Sponsor links, external links
6. **Merge Decisions** → Most restrictive rule (BLOCK > GATE > ALLOW)
7. **Cloud Fallback** → Only if on-device analysis is low-confidence
8. **History Tracking** → Categorize and group similar URLs for parent viewing

---

## Key Files Created

### 1. `UnifiedDecisionModels.swift`
**Location**: `Sources/Komalios/PostAuth/BrowserView/Model/`

**Purpose**: Defines the unified JSON decision model matching the specification.

**Key Models**:
- `UnifiedDecisionResponse` - Main response structure
- `AgeAction` - BLOCK/GATE/ALLOW per age band
- `MajorCategory` - Top-level content categories
- `Subcategory` - Detailed subcategories with source tracking
- `DecisionSource` - Tracks which analysis methods were used
- `SafetyFlags` - Boolean flags for specific risk types
- `DecisionMerger` - Utility for merging decisions using most restrictive rule

### 2. `ContentAnalysisService.swift`
**Location**: `Sources/Komalios/Services/`

**Purpose**: Implements the main analysis pipeline.

**Key Methods**:
- `analyzeContent()` - Main entry point
- `checkCustomRules()` - Step 1: Parent-defined rules
- `analyzeNLP()` - Step 3: On-device NLP (placeholder for future ML)
- `analyzeVision()` - Step 4: On-device vision (placeholder)
- `analyzeAudio()` - Step 5: On-device audio (placeholder)
- `analyzeLinks()` - Step 6: Sponsor/external link analysis
- `mergeAllDecisions()` - Step 7: Most restrictive rule merging
- `shouldUseCloudFallback()` - Step 8: Determine if cloud needed
- `callCloudFallback()` - Step 9: Call existing API

**Current Implementation**:
- ✅ Custom rules checking (keywords/URLs)
- ✅ Keyword-based major category detection (temporary until on-device NLP)
- ✅ Sponsor/link analysis
- ✅ Decision merging logic
- ✅ Cloud fallback integration
- ⏳ On-device NLP (placeholder - ready for ML integration)
- ⏳ On-device Vision (placeholder - ready for ML integration)
- ⏳ On-device Audio (placeholder - ready for ML integration)

### 3. `BrowsingHistoryService.swift` (Enhanced)
**Location**: `Sources/Komalios/Services/`

**Enhancements Added**:
- `logUnifiedDecision()` - Log decisions with category/subcategory
- `getHistoryGroupedByCategory()` - Group by major category for parent viewing
- `getHistoryGroupedBySubcategory()` - Group similar URLs by subcategory
- Support for `category:subcategory` format in history

### 4. `Extensions.swift`
**Location**: `Sources/Komalios/Shared/`

**Purpose**: Utility extensions for type conversions.

**Extensions**:
- `AgeGroup.toAgeBand()` - Convert to unified age band
- `FilterAction.toAction()` - Convert to unified Action enum
- `Action.toFilterAction()` - Reverse conversion

---

## Integration Points

### Current Flow (KomalSafetyScannerViewModel)

1. User enters URL
2. `handleUrlSubmit()` is called
3. **Step 1**: Check custom blocked keywords/URLs → BLOCK if found
4. **Step 2**: Check trusted domains → ALLOW if trusted
5. **Step 3**: Call `ScanNetworkService.scanURL()` → Get `ScanResponse`
6. **Step 4**: Process result → Determine action (BLOCK/GATE/ALLOW)
7. **Step 5**: Log to history with category

### Future Flow (With Unified System)

1. User enters URL
2. `handleUrlSubmit()` is called
3. **Step 1**: Check custom blocked keywords/URLs → BLOCK if found
4. **Step 2**: Build `ContentAnalysisInput` from URL/page content
5. **Step 3**: Call `ContentAnalysisService.analyzeContent()`
6. **Step 4**: Get `UnifiedDecisionResponse`
7. **Step 5**: Extract action for user's age band
8. **Step 6**: Log to history with category/subcategory

---

## Decision Merging Logic

The system uses the **most restrictive rule**:

```
BLOCK > GATE > ALLOW
```

**Implementation** (`DecisionMerger.mergeDecisions()`):
1. Collect all decisions from: NLP, Vision, Audio, Links, Cloud, Custom
2. If **any** source says BLOCK → Final = BLOCK
3. Else if **any** source says GATE → Final = GATE
4. Else → Final = ALLOW
5. If all sources are UNKNOWN → Default to GATE (safety)

---

## History Categorization

### Category Format
- **Major Category**: Stored as base category (e.g., "Violence & Disturbing")
- **Subcategory**: Stored as "category:subcategory" (e.g., "Violence & Disturbing:Weapons")
- **Grouping**: 
  - `getHistoryGroupedByCategory()` - Groups by major category
  - `getHistoryGroupedBySubcategory()` - Groups similar URLs by subcategory

### Example History Entry
```swift
BrowsingEvent(
    url: URL("https://example.com/weapons"),
    eventType: .blocked,
    category: "Violence & Disturbing:Weapons", // category:subcategory
    action: .block
)
```

---

## Next Steps for Full Implementation

### 1. On-Device NLP Integration
- Replace `keywordBasedMajorCategoryDetection()` with actual CoreML model
- Implement subcategory detection with confidence thresholds
- Add text preprocessing (strip boilerplate, extract key blocks)

### 2. On-Device Vision Integration
- Integrate Vision framework for image analysis
- Implement NSFW detection
- Add violence/weapon detection
- Map vision results to subcategories

### 3. On-Device Audio Integration
- Integrate Speech framework for transcription
- Run NLP on transcriptions
- Optional: Audio tone analysis

### 4. Content Extraction
- Extract HTML text, images, metadata from WebView
- Build `ContentAnalysisInput` from actual page content
- Extract sponsor links and external links

### 5. Update ViewModel Integration
- Replace `ScanNetworkService` calls with `ContentAnalysisService`
- Convert `ScanResponse` to `UnifiedDecisionResponse` (or use unified directly)
- Update history logging to use `logUnifiedDecision()`

---

## API Compatibility

The system maintains compatibility with the existing `ScanNetworkService` API:
- `ScanResponse` can be converted to `UnifiedDecisionResponse`
- Cloud fallback uses existing API endpoint
- Gradual migration path: Use unified system for on-device, fallback to API

---

## Testing

### Test Cases Needed:
1. Custom keyword blocking (should block immediately)
2. Custom URL blocking (should block immediately)
3. Trusted domain bypass (should allow without scanning)
4. NLP keyword detection (major categories)
5. Sponsor link analysis (should upgrade risk)
6. Decision merging (most restrictive rule)
7. Cloud fallback (when on-device confidence low)
8. History categorization (grouping by category/subcategory)

---

## Notes

- **App Store Compliance**: The current implementation uses keyword-based detection and API calls. On-device ML models can be added later when ready for App Store submission.
- **Performance**: On-device analysis should be fast (<100ms). Cloud fallback only when needed.
- **Privacy**: All on-device analysis happens locally. Only minimal data sent to cloud when fallback needed.
