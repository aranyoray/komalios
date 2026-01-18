# 🏗️ Komalios Architecture - CoreML Integration

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         KOMALIOS iOS APP                            │
│                     (SwiftUI + CoreML + Core Data)                  │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────────────────┐      ┌──────────────────────────┐
│   User Interaction       │      │   External Data          │
│                          │      │                          │
│ • BrowserView            │      │ • GCP Trained Models     │
│ • SettingsView           │      │ • komalweb/demo API      │
│ • Onboarding             │      │   (reference flow)       │
└────────────┬─────────────┘      └──────────┬───────────────┘
             │                               │
             │                               │ (one-time conversion)
             ▼                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        APP STATE LAYER                              │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────────────┐  │
│  │  AppState    │  │ BrowserState │  │ ContentFilterPreferences │  │
│  │  (@Published)│  │              │  │  (age-based thresholds)  │  │
│  └──────┬───────┘  └──────┬───────┘  └───────────┬─────────────┘  │
└─────────┼──────────────────┼──────────────────────┼─────────────────┘
          │                  │                      │
          │                  │                      │
          ▼                  ▼                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       SERVICE LAYER                                 │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │          MLClassificationService (NEW!)                    │    │
│  │  ┌──────────────────────────────────────────────────────┐  │    │
│  │  │  • Loads 5 CoreML models on init                     │  │    │
│  │  │  • classifyText(_ text: String) async                │  │    │
│  │  │  • Runs models in parallel (async let)               │  │    │
│  │  │  • Aggregates results with confidence thresholds     │  │    │
│  │  │  • Returns ClassificationResult                      │  │    │
│  │  └──────────────────────────────────────────────────────┘  │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │       ClassificationStorageService (NEW!)                  │    │
│  │  • Core Data CRUD operations                              │    │
│  │  • Saves classification history                           │    │
│  │  • Exports CSV for parent review                          │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │       BlocklistService (EXISTING)                          │    │
│  │  • Static rule-based blocking                             │    │
│  │  • Loads Blocklists.json                                  │    │
│  │  • Fast pre-filter before ML                              │    │
│  └────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
          │
          │
          ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     COREML MODEL LAYER                              │
│                                                                     │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐      │
│  │ HorrorClassifier│ │Cyberbullying   │  │Parasocial      │      │
│  │   .mlmodel      │  │Classifier      │  │Classifier      │      │
│  │                 │  │  .mlmodel      │  │  .mlmodel      │      │
│  │ Input: String   │  │                │  │                │      │
│  │ Output: Dict    │  │ Input: String  │  │ Input: String  │      │
│  │  {horror: 0.92} │  │ Output: Dict   │  │ Output: Dict   │      │
│  └────────────────┘  └────────────────┘  └────────────────┘      │
│                                                                     │
│  ┌────────────────┐  ┌────────────────┐                           │
│  │Financial       │  │MatureContent   │                           │
│  │AdviceClassifier│  │Classifier      │                           │
│  │  .mlmodel      │  │  .mlmodel      │                           │
│  │                 │  │ (Multi-label)  │                           │
│  │ Input: String  │  │                │                           │
│  │ Output: Dict   │  │ Input: String  │                           │
│  └────────────────┘  │ Output: Dict   │                           │
│                      │ {sexual: 0.1,  │                           │
│                      │  lgbtq: 0.8,   │                           │
│                      │  religious:0.0}│                           │
│                      └────────────────┘                           │
└─────────────────────────────────────────────────────────────────────┘
          │
          │
          ▼
┌─────────────────────────────────────────────────────────────────────┐
│                  CORE DATA PERSISTENCE                              │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │          ClassificationHistory Entity                       │  │
│  │  ┌───────────────────────────────────────────────────────┐  │  │
│  │  │ • id: UUID                                            │  │  │
│  │  │ • url: String                                         │  │  │
│  │  │ • timestamp: Date                                     │  │  │
│  │  │ • category: String (e.g., "Horror/Paranormal")       │  │  │
│  │  │ • confidence: Double (0.0 - 1.0)                     │  │  │
│  │  │ • action: String ("blocked", "gated", "allowed")     │  │  │
│  │  │ • childProfileId: UUID (which child triggered it)   │  │  │
│  │  └───────────────────────────────────────────────────────┘  │  │
│  └─────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 📊 Data Flow: URL Navigation → ML Classification

```
┌───────────────────────────────────────────────────────────────────────┐
│                          USER ACTION                                  │
│           Child navigates to URL in BrowserView                       │
└───────────────────────────────────┬───────────────────────────────────┘
                                    │
                                    ▼
┌───────────────────────────────────────────────────────────────────────┐
│  WKNavigationDelegate.decidePolicyFor(navigationAction)               │
│                                                                        │
│  1. Extract URL components:                                           │
│     • url.host (e.g., "reddit.com")                                  │
│     • url.path (e.g., "/r/nosleep")                                  │
│     • webView.title (e.g., "Scary Ghost Stories")                    │
│                                                                        │
│  2. Combine into classification text:                                │
│     text = "\(host) \(path) \(title)"                               │
│     → "reddit.com /r/nosleep Scary Ghost Stories"                    │
└───────────────────────────────────┬───────────────────────────────────┘
                                    │
                                    ▼
┌───────────────────────────────────────────────────────────────────────┐
│              STEP 1: Static Blocklist Check (Fast Path)               │
│                                                                        │
│  BlocklistService.shouldBlock(url)                                   │
│  • Check against Blocklists.json patterns                            │
│  • If matched → BLOCK immediately (no ML needed)                     │
│  • If not matched → Continue to ML classification                    │
│                                                                        │
│  Performance: ~5ms (JSON lookup)                                     │
└───────────────────────────────────┬───────────────────────────────────┘
                                    │
                                    ▼
┌───────────────────────────────────────────────────────────────────────┐
│              STEP 2: ML Classification (Parallel Execution)           │
│                                                                        │
│  MLClassificationService.classifyText(text)                          │
│                                                                        │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  async let horror = classifyHorror(text)          │ ~20ms   │    │
│  │  async let bullying = classifyCyberbullying(text) │ ~20ms   │    │
│  │  async let parasocial = classifyParasocial(text)  │ ~20ms   │    │
│  │  async let financial = classifyFinancial(text)    │ ~20ms   │    │
│  │  async let mature = classifyMature(text)          │ ~20ms   │    │
│  │                                                               │    │
│  │  Total time: ~20-30ms (parallel, not 5x20ms = 100ms)        │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                        │
│  Each model returns:                                                 │
│  • isHarmful: Bool                                                   │
│  • confidence: Double (0.0 - 1.0)                                    │
└───────────────────────────────────┬───────────────────────────────────┘
                                    │
                                    ▼
┌───────────────────────────────────────────────────────────────────────┐
│              STEP 3: Result Aggregation                               │
│                                                                        │
│  Combine results from 5 models:                                      │
│                                                                        │
│  Example:                                                             │
│    horror.isHarmful = true,  horror.confidence = 0.92                │
│    bullying.isHarmful = false, bullying.confidence = 0.12            │
│    parasocial.isHarmful = false, parasocial.confidence = 0.31       │
│    financial.isHarmful = false, financial.confidence = 0.08          │
│    mature.isHarmful = false, mature.confidence = 0.15               │
│                                                                        │
│  Aggregated Result:                                                  │
│    ClassificationResult {                                            │
│      isHarmful: true                                                 │
│      categories: ["Horror/Paranormal"]                               │
│      confidence: 0.92                                                │
│      detailedScores: [horror: 0.92, bullying: 0.12, ...]           │
│    }                                                                  │
└───────────────────────────────────┬───────────────────────────────────┘
                                    │
                                    ▼
┌───────────────────────────────────────────────────────────────────────┐
│              STEP 4: Age-Based Threshold Filter                       │
│                                                                        │
│  Get child's age group from AppState.activeProfile                   │
│  Load threshold from ContentFilterPreferences                        │
│                                                                        │
│  Age <10:   threshold = 0.5  (very strict)                           │
│  Age 10-13: threshold = 0.65                                         │
│  Age 13-16: threshold = 0.75                                         │
│  Age 16+:   threshold = 0.85 (relaxed)                               │
│                                                                        │
│  If confidence >= threshold → BLOCK/GATE                             │
│  If confidence < threshold → ALLOW                                   │
│                                                                        │
│  Example: confidence = 0.92, age = 8, threshold = 0.5               │
│  → 0.92 >= 0.5 → BLOCK ✓                                            │
└───────────────────────────────────┬───────────────────────────────────┘
                                    │
                                    ▼
┌───────────────────────────────────────────────────────────────────────┐
│              STEP 5: Store Classification Result                      │
│                                                                        │
│  ClassificationStorageService.save(result)                           │
│                                                                        │
│  Save to Core Data:                                                  │
│    ClassificationHistory {                                           │
│      id: UUID()                                                      │
│      url: "https://reddit.com/r/nosleep"                            │
│      timestamp: Date()                                               │
│      category: "Horror/Paranormal"                                   │
│      confidence: 0.92                                                │
│      action: "blocked"                                               │
│      childProfileId: activeProfile.id                               │
│    }                                                                  │
│                                                                        │
│  Used later for:                                                     │
│  • Parent dashboard (AI Reports)                                     │
│  • CSV export                                                         │
│  • Analytics/improvement                                             │
└───────────────────────────────────┬───────────────────────────────────┘
                                    │
                                    ▼
┌───────────────────────────────────────────────────────────────────────┐
│              STEP 6: Update UI                                        │
│                                                                        │
│  If isHarmful = true:                                                │
│    • Show BlockedView overlay                                        │
│    • Display category: "Horror/Paranormal"                           │
│    • Show confidence: 92%                                            │
│    • Show "Detected by AI" badge                                     │
│    • Offer "Report Incorrect" button                                │
│                                                                        │
│  If isHarmful = false:                                               │
│    • Allow navigation                                                │
│    • Continue browsing normally                                      │
│                                                                        │
│  navigationAction.decisionHandler(.cancel) or (.allow)              │
└───────────────────────────────────────────────────────────────────────┘
```

**Total latency**: ~30-50ms (blocklist check + ML inference + storage)

---

## 🔄 GCP Model → CoreML Conversion Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                    GCP TRAINING ENVIRONMENT                         │
│                                                                     │
│  1. Models trained on GCP with large datasets                      │
│  2. Validated with high accuracy (>90%)                            │
│  3. Exported in TensorFlow/PyTorch/ONNX format                     │
│                                                                     │
│  Output files:                                                      │
│    • horror_classifier/saved_model.pb (TensorFlow)                 │
│    • cyberbullying_classifier.pt (PyTorch)                         │
│    • parasocial_classifier.onnx (ONNX)                             │
│    • financial_classifier.pkl (scikit-learn)                       │
│    • mature_content_classifier/saved_model.pb (TensorFlow)         │
└─────────────────────────────┬───────────────────────────────────────┘
                              │ (Download to local)
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    LOCAL CONVERSION (Day 1-2)                       │
│                                                                     │
│  python convert_to_coreml.py --model all                           │
│                                                                     │
│  For each model:                                                    │
│  1. Load GCP model (TF/PyTorch/ONNX)                               │
│  2. Convert using coremltools                                       │
│  3. Add metadata (description, author, version)                    │
│  4. Optimize for iOS (quantization, pruning)                       │
│  5. Validate with test inputs                                      │
│  6. Save as .mlmodel file                                           │
│                                                                     │
│  Output:                                                            │
│    • HorrorClassifier.mlmodel                                      │
│    • CyberbullyingClassifier.mlmodel                               │
│    • ParasocialClassifier.mlmodel                                  │
│    • FinancialAdviceClassifier.mlmodel                             │
│    • MatureContentClassifier.mlmodel                               │
└─────────────────────────────┬───────────────────────────────────────┘
                              │ (Drag into Xcode)
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        XCODE PROJECT                                │
│                                                                     │
│  1. Add .mlmodel files to Resources/                               │
│  2. Xcode auto-generates Swift classes:                            │
│     • HorrorClassifierInput                                        │
│     • HorrorClassifierOutput                                       │
│     • HorrorClassifier (with prediction methods)                   │
│  3. Compile into app bundle                                         │
│  4. Models embedded in .ipa (no network needed!)                   │
│                                                                     │
│  Model sizes:                                                       │
│    • Each model: ~1-2 MB (optimized)                               │
│    • Total: ~5-10 MB added to app size                             │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     iOS APP (PRODUCTION)                            │
│                                                                     │
│  • Models loaded on app launch                                     │
│  • Inference runs on-device (no internet required)                 │
│  • Fast, private, offline-capable                                  │
│  • Uses Neural Engine for acceleration                             │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🎨 UI Component Hierarchy

```
KomaliosApp
│
├─── RootView (TabView)
│    │
│    ├─── BrowserView ⭐ (ML INTEGRATION HERE)
│    │    │
│    │    ├─── WKWebView (wrapped)
│    │    │    └─── WKNavigationDelegate
│    │    │         └─── decidePolicyFor() → ML Classification
│    │    │
│    │    ├─── FloatingMenuView (bottom nav)
│    │    │
│    │    ├─── BlockedView (overlay when ML blocks) ⭐ NEW UI
│    │    │    ├─── Category badge
│    │    │    ├─── Confidence indicator
│    │    │    ├─── "Detected by AI" label
│    │    │    └─── "Report Incorrect" button
│    │    │
│    │    └─── GateView (overlay when content gated)
│    │
│    ├─── RikiCheckInView (companion chat)
│    │
│    └─── SettingsView
│         │
│         ├─── Account mode toggle
│         ├─── Child profile editor
│         ├─── Content filter preferences
│         │    └─── Age-based thresholds
│         │
│         └─── AI Content Reports ⭐ NEW SECTION
│              ├─── Classification history list
│              ├─── Category breakdown chart
│              ├─── Most blocked sites
│              └─── Export CSV button
│
└─── OnboardingView (first launch)
     ├─── Welcome
     ├─── Child info
     ├─── Content settings
     └─── Completion
```

---

## 📦 File Structure

```
komalios/
├── Sources/
│   └── Komalios/
│       ├── KomaliosApp.swift
│       │
│       ├── Models/
│       │   ├── AppState.swift
│       │   ├── BrowserState.swift (updated with ML results)
│       │   ├── ContentFilterPreferences.swift (age thresholds)
│       │   ├── ClassificationResult.swift ⭐ NEW
│       │   └── ClassificationHistory+CoreData.swift ⭐ NEW
│       │
│       ├── Services/
│       │   ├── BlocklistService.swift (existing)
│       │   ├── MLClassificationService.swift ⭐ NEW
│       │   └── ClassificationStorageService.swift ⭐ NEW
│       │
│       ├── Views/
│       │   ├── BrowserView.swift (updated with ML)
│       │   ├── BlockedView.swift (updated with AI UI)
│       │   ├── SettingsView.swift (updated with AI Reports)
│       │   └── AIReportsView.swift ⭐ NEW
│       │
│       ├── Theme/
│       │   └── KomalTheme.swift
│       │
│       └── Resources/
│           ├── Blocklists.json
│           ├── Assets.xcassets/
│           ├── PrivacyInfo.xcprivacy (updated)
│           │
│           └── CoreML/ ⭐ NEW
│               ├── HorrorClassifier.mlmodel
│               ├── CyberbullyingClassifier.mlmodel
│               ├── ParasocialClassifier.mlmodel
│               ├── FinancialAdviceClassifier.mlmodel
│               └── MatureContentClassifier.mlmodel
│
├── Tests/
│   └── KomaliosTests/
│       ├── MLClassificationServiceTests.swift ⭐ NEW
│       └── ClassificationStorageServiceTests.swift ⭐ NEW
│
└── MLModels/ (not included in Xcode, for development only)
    ├── gcp_models/ (downloaded from GCP)
    ├── convert_to_coreml.py
    └── README.md
```

---

## 🔐 Privacy & Security

### On-Device Processing:
✅ **All ML inference happens on-device**
- Models embedded in app bundle
- No data sent to servers
- Works offline
- Privacy-preserving

### Data Storage:
- Classification history stored locally (Core Data)
- Not synced to cloud (unless parent explicitly exports)
- Can be cleared anytime
- Per-child profile isolation

### App Store Compliance:
- PrivacyInfo.xcprivacy updated with ML data collection
- Required Reasons API declarations
- COPPA compliant (child safety app)
- No advertising/tracking

---

## ⚡ Performance Optimizations

### Model Loading:
- Load all models on app launch (async)
- Keep in memory (small size ~5MB total)
- Lazy loading if memory constrained

### Inference:
- Parallel execution (5 models in ~20-30ms)
- Caching results (NSCache, 500 entries)
- Pre-filter with static blocklist (faster)

### Storage:
- Batch Core Data operations
- Index on url + timestamp for fast queries
- Auto-cleanup old entries (30 days)

### UI:
- Async/await for non-blocking UI
- Show BlockedView immediately (no lag)
- Background queue for storage

---

## 🎯 Success Metrics

| Metric | Target | How Measured |
|--------|--------|--------------|
| Classification Latency | <100ms | XCTest performance tests |
| App Launch Time | <3 seconds | Instruments Time Profiler |
| Memory Usage | <150MB | Instruments Allocations |
| Model Size | <10MB total | Archive size analysis |
| Accuracy | >90% | Real-world URL testing |
| False Positive Rate | <5% | Manual testing with safe URLs |

---

**This architecture ensures fast, private, and accurate content filtering! 🚀**
