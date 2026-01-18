# 🚀 7-DAY COREML SPRINT: JAN 19-26
## Objective: Ship App Store Update with 5 CoreML Models + Demo Ready

---

## 📊 OVERVIEW

**Start Date**: Sunday, Jan 19, 2025
**Demo Date**: Sunday, Jan 26, 2025
**App Store Push**: Friday, Jan 24, 2025

**Available Resources**:
- ✅ Pre-trained GCP models (high accuracy)
- ✅ Cursor Pro + Claude Pro + Codex access
- ✅ Existing web flow at komalkids.com/demo
- ✅ Senior SwiftUI developer (5.2 years exp)

**Models to Integrate** (already trained on GCP):
1. Horror/Paranormal Classifier
2. Cyberbullying Classifier
3. Parasocial Content Classifier
4. Financial Advice Classifier
5. Mature Content Classifier

**Critical Requirements**:
- ❌ ZERO BUGS - Must pass all testing
- ❌ ZERO APP STORE REJECTIONS - Follow all guidelines
- ✅ Full E2E data pipeline (GCP → CoreML → On-device storage)
- ✅ Production-ready code with proper error handling
- ✅ Demo-ready by Jan 26

---

## 📅 DAILY MILESTONES (11 PM Check-ins)

---

## DAY 1: SUNDAY, JAN 19
### 🎯 Milestone: GCP Model Download + Web Flow Understanding + CoreML Conversion Setup

#### Deliverables by 11 PM:
- [ ] **Clone and explore komalweb repo** (https://github.com/aranyoray/komalweb)
  - Understand NLP vector search/algorithm flow at komalkids.com/demo
  - Document how web demo classifies content (API endpoints, model calls, data flow)
  - Map web flow to iOS requirements
  - Create architecture diagram showing GCP → iOS pipeline

- [ ] **Download all 5 trained models from GCP**
  - Get model files (TensorFlow/PyTorch/ONNX format)
  - Download model metadata (accuracy metrics, label mappings, preprocessing steps)
  - Verify model formats and compatibility
  - Store in `MLModels/gcp_models/` folder

- [ ] **Set up CoreML conversion environment**
  - Install coremltools: `pip install coremltools tensorflow torch`
  - Create conversion script: `convert_to_coreml.py`
  - Test conversion with ONE model (Horror classifier as proof of concept)
  - Validate converted model runs in Python before iOS integration

- [ ] **Create iOS data pipeline architecture document**
  - Design: GCP API → Local cache → CoreML inference → Result storage
  - Define data models for classification results
  - Plan on-device storage strategy (Core Data vs UserDefaults vs files)
  - Document error handling strategy

#### Success Criteria:
✅ komalweb demo flow fully understood and documented
✅ All 5 GCP models downloaded locally
✅ At least 1 model successfully converted to CoreML (.mlmodel file)
✅ Architecture doc shows complete data pipeline

---

## DAY 2: MONDAY, JAN 20
### 🎯 Milestone: Convert All 5 Models to CoreML + Create iOS ML Service Layer

#### Deliverables by 11 PM:
- [ ] **Convert all 5 GCP models to CoreML**
  - Run conversion script for all models
  - Generate `.mlmodel` files: `HorrorClassifier.mlmodel`, `CyberbullyingClassifier.mlmodel`, etc.
  - Validate each model with test inputs in Python
  - Document input/output specs for each model
  - Ensure models are optimized for iOS (quantization if needed)

- [ ] **Add models to Xcode project**
  - Drag all 5 `.mlmodel` files into `Sources/Komalios/Resources/`
  - Verify Xcode auto-generates Swift classes
  - Check model metadata in Xcode (Preview tab)
  - Ensure models compile without errors

- [ ] **Create comprehensive ML service layer**
  - Build `Sources/Komalios/Services/MLClassificationService.swift`
  - Implement model loading with error handling
  - Create async classification methods for each model
  - Add caching layer (NSCache) for performance
  - Implement text preprocessing (matching web demo logic)
  - Add logging/telemetry for debugging

- [ ] **Create data models for results**
  - `ClassificationResult` struct with all metadata
  - `ContentCategory` enum matching web demo categories
  - `MLModelMetrics` for tracking performance
  - Codable conformance for storage

#### Success Criteria:
✅ All 5 models converted and in Xcode
✅ MLClassificationService compiles without errors
✅ Can load all models successfully on app launch
✅ Basic classification works with test strings

---

## DAY 3: TUESDAY, JAN 21
### 🎯 Milestone: Full E2E Integration - First Model Working in BrowserView

#### Deliverables by 11 PM:
- [ ] **Integrate Horror Classifier into BrowserView (end-to-end)**
  - Hook into WKNavigationDelegate's `decidePolicyFor` method
  - Extract URL + page title for classification
  - Call MLClassificationService asynchronously
  - Handle classification results (Block/Gate/Allow)
  - Update BrowserState with results
  - Trigger BlockedView when horror content detected

- [ ] **Implement on-device result storage**
  - Create Core Data model: `ClassificationHistory` entity
  - Fields: url, timestamp, category, confidence, action (blocked/gated/allowed)
  - Create `ClassificationStorageService.swift`
  - Implement save, fetch, delete operations
  - Add batch operations for performance
  - Test with 100+ classification results

- [ ] **Update BlockedView to show ML results**
  - Display detected category (e.g., "Horror/Paranormal")
  - Show confidence score with visual indicator
  - Add "Detected by AI" badge
  - Implement "Report Incorrect" button (stores feedback)
  - Match design to existing KomalTheme

- [ ] **Add comprehensive logging**
  - Log every classification attempt
  - Log model inference time
  - Log storage operations
  - Create debug overlay showing ML stats
  - Use OSLog for production logging

- [ ] **Test Horror classifier thoroughly**
  - Test with 20+ horror-related URLs
  - Test with 20+ safe URLs
  - Verify no false positives on Khan Academy, Wikipedia
  - Check classification latency (<100ms)
  - Test offline behavior (models work without network)

#### Success Criteria:
✅ Horror classifier blocks scary content in real-time
✅ All classifications stored in Core Data
✅ BlockedView shows beautiful ML-powered UI
✅ <100ms classification latency
✅ Zero crashes during testing

---

## DAY 4: WEDNESDAY, JAN 22
### 🎯 Milestone: Integrate All 5 Models + Advanced Features

#### Deliverables by 11 PM:
- [ ] **Integrate remaining 4 models into BrowserView**
  - Add Cyberbullying classifier
  - Add Parasocial classifier
  - Add Financial Advice classifier
  - Add Mature Content classifier
  - Run all 5 models in parallel using async/await
  - Aggregate results with weighted scoring
  - Handle multi-category detection (e.g., content that's both horror AND mature)

- [ ] **Implement smart classification pipeline**
  - Quick pre-filter: Check static blocklist first (faster)
  - If blocklist passes → Run ML models
  - Combine blocklist + ML results intelligently
  - Cache classifications by URL (avoid re-running models)
  - Implement confidence threshold tuning per category
  - Add fallback logic if models fail to load

- [ ] **Build parent dashboard for ML insights**
  - Create new SettingsView section: "AI Content Reports"
  - Show classification history grouped by category
  - Display charts: blocked categories over time
  - Show most blocked websites
  - Export data as CSV for parent review
  - Add "Clear History" button

- [ ] **Implement age-appropriate thresholds**
  - Different confidence thresholds per age group
  - <10: Strict (0.5 threshold = block)
  - 10-13: Moderate (0.65 threshold)
  - 13-16: Relaxed (0.75 threshold)
  - 16+: Very relaxed (0.85 threshold)
  - Load from ContentFilterPreferences
  - Allow parent customization

- [ ] **Performance optimization**
  - Profile with Instruments (Time Profiler)
  - Optimize model loading (lazy loading if needed)
  - Reduce memory footprint (<50MB for all models)
  - Implement result caching (LRU cache, 500 entries)
  - Test with rapid navigation (10 URLs in 10 seconds)

#### Success Criteria:
✅ All 5 models working simultaneously
✅ Classification pipeline handles complex cases
✅ Parent dashboard shows beautiful insights
✅ Age-based thresholds work correctly
✅ App stays responsive during heavy ML usage

---

## DAY 5: THURSDAY, JAN 23
### 🎯 Milestone: Comprehensive Testing + Bug Fixes + App Store Prep

#### Deliverables by 11 PM:
- [ ] **Unit testing (XCTest)**
  - Create `Tests/KomaliosTests/MLClassificationServiceTests.swift`
  - Test each model with 10+ examples (true positives/negatives)
  - Test edge cases: empty strings, very long URLs, special characters, emojis
  - Test caching behavior
  - Test error handling (model fails to load, invalid input)
  - Test Core Data storage (CRUD operations)
  - Test performance (measure block - each model <50ms)
  - **Target: 30+ passing tests, 0 failures**

- [ ] **Integration testing**
  - Test complete user flows:
    - Child opens browser → Navigates to horror site → Blocked by ML
    - Parent reviews AI reports → Sees correct data
    - Child switches age group → Thresholds update correctly
  - Test onboarding flow with ML features
  - Test settings changes persist correctly
  - Test app backgrounding/foregrounding (models stay loaded)
  - Test memory warnings (models reload gracefully)

- [ ] **Real-world URL testing**
  - Test with 50+ real URLs across all categories:
    - Horror: reddit.com/r/nosleep, creepypasta.com
    - Cyberbullying: twitter posts with harassment
    - Parasocial: youtube.com/watch?v=mr-beast-challenge
    - Financial: crypto pump groups, stock tip sites
    - Mature: LGBTQ+ content, religious sites
  - Verify accuracy matches GCP model performance
  - Document false positives/negatives
  - Tune thresholds to reduce false positives

- [ ] **Bug hunting and fixing**
  - Use Cursor Pro AI to review all ML-related code for bugs
  - Fix memory leaks (Instruments - Leaks)
  - Fix any crashes (Xcode crash logs)
  - Fix UI glitches in BlockedView
  - Fix race conditions in async code
  - Fix Core Data threading issues
  - **Goal: Zero known bugs by EOD**

- [ ] **App Store compliance check**
  - Review App Store Review Guidelines (especially 1.4.4 - Physical Harm)
  - Ensure privacy disclosures for ML usage (PrivacyInfo.xcprivacy)
  - Add App Store description mentioning AI features
  - Prepare screenshots showing ML blocking
  - Update "What's New" for this version
  - Check for any rejected API usage
  - Verify all third-party dependencies are compliant

- [ ] **Privacy manifest updates**
  - Update `Resources/PrivacyInfo.xcprivacy`
  - Add data collection disclosure for classification history
  - Document ML model usage (on-device processing)
  - Add required reasons for API usage
  - Ensure COPPA compliance (app is for children)

#### Success Criteria:
✅ 30+ unit tests passing
✅ All integration tests pass
✅ Zero known bugs
✅ 95%+ accuracy on real-world URLs
✅ App Store compliance verified
✅ Privacy manifest complete

---

## DAY 6: FRIDAY, JAN 24
### 🎯 Milestone: App Store Submission + Final Polish

#### Deliverables by 11 PM:
- [ ] **Pre-submission checklist**
  - [ ] All tests passing (`cmd+U`)
  - [ ] No warnings in Xcode
  - [ ] Build succeeds on Release configuration
  - [ ] App runs perfectly on iOS 16, 17, 18 simulators
  - [ ] Test on real device (if available)
  - [ ] Memory usage <150MB during heavy use
  - [ ] No crashes after 30min continuous use
  - [ ] All analytics/logging working

- [ ] **Version bump and changelog**
  - Update version number (e.g., 1.1.0)
  - Update build number
  - Write detailed "What's New":
    ```
    🤖 AI-Powered Content Safety (NEW!)
    • 5 advanced AI models protect your child from harmful content
    • Real-time detection of horror, cyberbullying, manipulation, and more
    • Smarter blocking with age-appropriate intelligence
    • Parent dashboard shows AI-detected content insights

    🛡️ Enhanced Protection
    • Faster and more accurate content filtering
    • Better handling of evolving online risks
    • Improved performance and stability

    📊 For Parents
    • New AI Content Reports in Settings
    • See exactly what content was blocked and why
    • Export reports for review
    ```
  - Update CHANGELOG.md in repo

- [ ] **Build and archive**
  - Clean build folder (`cmd+shift+K`)
  - Archive app (`Product > Archive`)
  - Validate archive (Xcode validation)
  - Fix any validation errors
  - Submit to App Store Connect
  - Fill out App Store metadata
  - Upload screenshots (including ML features)
  - Submit for review

- [ ] **Monitor app currently in review**
  - Check status of existing submission
  - If approved → Great! Plan for next update
  - If rejected → Address issues immediately
  - Respond to any App Review questions within 2 hours

- [ ] **Create fallback plan**
  - If submission rejected, document exact issues
  - Prepare fixes for common rejection reasons:
    - Privacy issues → Update manifest
    - Crashes → Fix and resubmit same day
    - Guideline violations → Adjust features
  - Keep Jan 25 as buffer for resubmission

#### Success Criteria:
✅ App successfully submitted to App Store Connect
✅ No validation errors
✅ All metadata and screenshots uploaded
✅ Status shows "Waiting for Review" or "In Review"
✅ Fallback plan documented

---

## DAY 7: SATURDAY, JAN 25
### 🎯 Milestone: Demo Preparation + Documentation

#### Deliverables by 11 PM:
- [ ] **Create comprehensive demo script**
  - Write step-by-step demo flow (10-15 minutes)
  - Script covers all 5 ML models in action
  - Shows parent dashboard with AI insights
  - Demonstrates age-based intelligence
  - Highlights performance (speed, accuracy)
  - Include "wow moments" (blocking harmful content in real-time)

- [ ] **Demo video recording**
  - Record 5-minute demo video showing:
    1. Child mode: Browse safe content (Khan Academy) ✅
    2. Navigate to horror site → ML blocks instantly with category shown
    3. Try cyberbullying content → Blocked with confidence score
    4. Try manipulative influencer content → Blocked
    5. Parent mode: Open AI Reports → Show beautiful charts
    6. Switch age groups → Demonstrate threshold changes
  - Edit with captions/annotations
  - Export in 1080p

- [ ] **Create demo environment**
  - Prepare test URLs list (20+ URLs across categories)
  - Clear classification history for fresh demo
  - Set up demo child profile (age 8-10 for strict blocking)
  - Pre-load app on demo device/simulator
  - Test complete demo flow 3 times (practice!)

- [ ] **Build presentation deck** (10 slides max)
  - Slide 1: Problem (kids exposed to harmful content)
  - Slide 2: Solution (AI-powered safety)
  - Slide 3: Architecture (GCP models → CoreML pipeline)
  - Slide 4: 5 Model Categories (with examples)
  - Slide 5: Demo - Horror Blocking
  - Slide 6: Demo - Cyberbullying Blocking
  - Slide 7: Parent Dashboard
  - Slide 8: Performance Metrics (speed, accuracy, battery)
  - Slide 9: App Store Readiness
  - Slide 10: Next Steps

- [ ] **Prepare FAQ responses**
  - "How accurate are the models?" → Show GCP metrics
  - "Does it work offline?" → Yes, models on-device
  - "Battery impact?" → Negligible, <2% increase
  - "Privacy concerns?" → All processing on-device, zero data sent to servers
  - "False positives?" → Parent can override, feedback loop planned
  - "What if App Store rejects?" → On-device ML is compliant, worst case we iterate

- [ ] **Documentation for handoff**
  - Update README.md with ML features section
  - Create ARCHITECTURE.md showing data flow diagrams
  - Document all model files and their purposes
  - Create TESTING.md with test URLs and expected results
  - Write TROUBLESHOOTING.md for common issues

- [ ] **Final polish**
  - Review all UI text for typos
  - Check all animations are smooth
  - Verify color consistency with KomalTheme
  - Test on largest iPhone (Pro Max) and smallest (SE)
  - Fix any UI layout issues
  - Ensure accessibility (VoiceOver support for ML features)

#### Success Criteria:
✅ Demo script finalized and practiced
✅ Demo video recorded and polished
✅ Presentation deck complete
✅ FAQ document ready
✅ All documentation updated
✅ App is pixel-perfect

---

## DAY 8: SUNDAY, JAN 26
### 🎯 DEMO DAY - Show Everything

#### Demo Checklist (Practice at 9 AM, Demo at TBD):
- [ ] **Environment ready**
  - Device/simulator charged and ready
  - Demo URLs bookmarked
  - Presentation deck open
  - Demo video as backup
  - Internet connection stable (if needed for live demo)

- [ ] **Demo flow (15 minutes)**
  1. **Intro** (2 min)
     - Problem: Online safety for kids
     - Solution: AI-powered content filtering

  2. **Live Demo** (8 min)
     - Launch app in child mode
     - Browse safe content (Khan Academy) - works perfectly
     - Navigate to horror subreddit → **Blocked instantly**
       - Show BlockedView with "Horror/Paranormal" category
       - Show confidence: 92%
     - Try cyberbullying Twitter post → **Blocked**
       - Category: "Cyberbullying"
       - Confidence: 88%
     - Try Mr Beast FOMO video → **Blocked**
       - Category: "Parasocial/Manipulative"
       - Confidence: 85%
     - Switch to parent mode (PIN unlock)
     - Open AI Content Reports
       - Show 3 blocked items
       - Show category breakdown chart
       - Export CSV demo

  3. **Technical Deep Dive** (3 min)
     - Show architecture diagram
     - Explain GCP → CoreML pipeline
     - Highlight on-device processing (privacy!)
     - Show performance: <100ms per classification
     - Show model sizes: ~5MB total

  4. **App Store Status** (1 min)
     - Show submission confirmation
     - Current status: [In Review / Waiting for Review]
     - Expected approval: [Date]

  5. **Q&A** (1 min)
     - Handle questions from FAQ doc

#### Backup Plan:
- If live demo fails → Play pre-recorded video
- If questions arise → Reference documentation
- If technical deep dive requested → Show actual code in Xcode

#### Post-Demo:
- [ ] Gather feedback
- [ ] Document any issues discovered
- [ ] Plan iteration based on feedback
- [ ] Celebrate! 🎉

---

## 📦 FINAL DELIVERABLES CHECKLIST

### Code Artifacts
- [ ] 5 CoreML models integrated and working
- [ ] `MLClassificationService.swift` (300+ lines)
- [ ] `ClassificationStorageService.swift` (200+ lines)
- [ ] Updated `BrowserView.swift` with ML integration
- [ ] Updated `BlockedView.swift` with AI UI
- [ ] New `AIReportsView.swift` (parent dashboard)
- [ ] Core Data model for classification history
- [ ] 30+ unit tests all passing

### ML Artifacts
- [ ] 5 `.mlmodel` files in Xcode
- [ ] Conversion scripts from GCP models
- [ ] Model metadata documentation
- [ ] Performance benchmarks

### Documentation
- [ ] README.md updated
- [ ] ARCHITECTURE.md created
- [ ] TESTING.md with test URLs
- [ ] TROUBLESHOOTING.md
- [ ] CHANGELOG.md updated
- [ ] Demo script document

### Demo Materials
- [ ] 5-minute demo video
- [ ] 10-slide presentation deck
- [ ] FAQ document
- [ ] Test URLs list
- [ ] Performance metrics sheet

### App Store
- [ ] Version 1.1.0 submitted
- [ ] "What's New" written
- [ ] Screenshots updated
- [ ] Privacy manifest updated
- [ ] Metadata complete

---

## 🚨 CRITICAL SUCCESS FACTORS

### App Store Rejection Risks - AVOID THESE:
1. **Privacy Issues**
   - ✅ Ensure PrivacyInfo.xcprivacy includes ML data collection
   - ✅ Add "Required Reasons API" declarations
   - ✅ COPPA compliance for child safety app

2. **Crashes**
   - ✅ Handle model loading failures gracefully
   - ✅ Catch all CoreML exceptions
   - ✅ Test on iOS 16, 17, 18
   - ✅ Test on low-memory devices

3. **Performance**
   - ✅ App launches in <3 seconds
   - ✅ No ANRs (Application Not Responding)
   - ✅ Models load asynchronously (don't block main thread)

4. **Content Guidelines**
   - ✅ Don't show harmful content in screenshots
   - ✅ Clearly explain AI features benefit children
   - ✅ Emphasize parental control

### Zero Bug Tolerance - Testing Checklist:
- [ ] Test on iPhone SE (smallest screen)
- [ ] Test on iPhone 15 Pro Max (largest screen)
- [ ] Test on iOS 16.0 (minimum supported)
- [ ] Test on iOS 18.2 (latest)
- [ ] Test in low power mode
- [ ] Test with slow network
- [ ] Test in airplane mode
- [ ] Test rapid navigation (stress test)
- [ ] Test with VoiceOver enabled
- [ ] Test after app backgrounded for 1 hour

---

## 💡 PRODUCTIVITY BOOSTERS

### Cursor Pro / Claude Pro Usage:
- Use AI to generate Core Data models
- Ask Claude to review ML service code for thread-safety
- Use Copilot to write boilerplate test cases
- Ask AI to optimize slow code sections
- Use AI to generate privacy manifest entries

### Time Savers:
- Copy web demo preprocessing logic directly
- Reuse existing KomalTheme components
- Don't reinvent caching - use NSCache
- Use Xcode code snippets for repetitive code
- Batch test runs (don't test after every line change)

### Debug Shortcuts:
- Add `#if DEBUG` logging throughout ML pipeline
- Use breakpoints with conditions (not print statements)
- Enable Xcode Memory Graph to catch leaks early
- Use Instruments from Day 1 (don't wait for slowness)

---

## 📞 DAILY CHECK-IN FORMAT (11 PM)

Post in team chat:
```
DAY X CHECK-IN ✅

Completed:
- ✅ [Task 1]
- ✅ [Task 2]
- ✅ [Task 3]

In Progress:
- 🟡 [Task 4 - 80% done]

Blockers:
- ❌ [Issue if any] → [How resolving]

Tomorrow:
- [ ] [Plan for next day]

Demo Readiness: [%]
App Store Readiness: [%]
```

---

## 🎯 KEY METRICS TO TRACK

| Metric | Target | Track Daily |
|--------|--------|-------------|
| Models Integrated | 5/5 | Day 4 |
| Classification Latency | <100ms | Day 3+ |
| Test Coverage | 30+ tests | Day 5 |
| Memory Usage | <150MB | Day 5 |
| Known Bugs | 0 | Day 5 |
| App Store Submission | Done | Day 6 |
| Demo Readiness | 100% | Day 7 |

---

## 🏆 SUCCESS = ALL OF THE FOLLOWING:

1. ✅ **5 CoreML models** working in production iOS app
2. ✅ **Full E2E pipeline**: GCP models → CoreML → On-device storage
3. ✅ **Zero bugs** - Comprehensively tested
4. ✅ **App Store submitted** by Jan 24
5. ✅ **Demo ready** by Jan 26 (video + live + deck)
6. ✅ **Performance**: <100ms classification, <150MB memory
7. ✅ **Privacy compliant**: All manifests updated
8. ✅ **Beautiful UI**: ML features integrated with KomalTheme
9. ✅ **Parent dashboard**: AI insights visible
10. ✅ **Documentation**: Complete and clear

---

**LET'S SHIP THIS! 🚀**

*Timeline: 7 days | Models: 5 | Zero bugs | Demo ready Jan 26*
