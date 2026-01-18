# 🚀 1-WEEK INTENSE COREML INTEGRATION PLAN
## 10 Hours Total | 5 CoreML Models | Daily 2-Hour Sprints

---

## 📊 OVERVIEW

**Objective**: Train and integrate 5 CoreML text classification models into Komalios SwiftUI app

**Models to Build**:
1. **Horror/Paranormal Classifier** - Detects scary, creepy, jumpscare content
2. **Cyberbullying Classifier** - Detects harassment, slut-shaming, body-shaming
3. **Parasocial Content Classifier** - Detects manipulative influencer content, FOMO triggers
4. **Financial Advice Classifier** - Detects unregulated crypto/stock tips
5. **Mature Content Classifier** - Detects sexual/LGBTQ+/religious content (multi-label)

**Tech Stack**:
- **Training**: Python + scikit-learn/CoreMLTools OR Create ML (macOS)
- **Integration**: Swift 5.9, CoreML, NaturalLanguage framework
- **Architecture**: MVVM pattern with async/await
- **Testing**: XCTest for model validation

---

## 📅 DAY 1: MONDAY (2 HOURS)
### Environment Setup + Dataset Preparation + Model 1

**TIME**: 9:00 AM - 11:00 AM

#### ✅ MILESTONE 1.1: Development Environment (30 min)
**Tasks**:
- [ ] Install Python 3.9+ with pip
- [ ] Install dependencies: `pip install coremltools scikit-learn pandas numpy transformers`
- [ ] Create project directory: `komalios/MLModels/`
- [ ] Set up Xcode 15+ with SwiftUI project open
- [ ] Create new Swift file: `Sources/Komalios/Services/MLContentClassifier.swift`

**Deliverable**: Screenshot of successful `import coremltools` in Python

---

#### ✅ MILESTONE 1.2: Dataset Preparation (45 min)
**Tasks**:
- [ ] Create `MLModels/datasets/` folder
- [ ] Build 5 CSV files (one per model) with columns: `text, label`
  - `horror_dataset.csv` (200+ samples: 100 horror, 100 safe)
  - `cyberbullying_dataset.csv` (200+ samples: 100 bullying, 100 safe)
  - `parasocial_dataset.csv` (200+ samples: 100 manipulative, 100 safe)
  - `financial_dataset.csv` (200+ samples: 100 risky advice, 100 safe)
  - `mature_dataset.csv` (300+ samples: multi-label for sexual/lgbtq/religion)

**Data Sources**:
- Use keywords from your table as seed data
- Augment with synthetic examples using GPT-4 prompts
- Manual labeling for 50-100 examples per category
- Web scraping from Reddit/Twitter (use existing datasets if available)

**Example `horror_dataset.csv`**:
```csv
text,label
"This creepy ghost story gave me nightmares",horror
"Paranormal activity caught on camera at 3AM",horror
"Best chocolate cake recipe tutorial",safe
"Jumpscare compilation that will terrify you",horror
```

**Deliverable**: 5 CSV files with 200-300 labeled examples each

---

#### ✅ MILESTONE 1.3: Train Model 1 - Horror Classifier (45 min)
**Tasks**:
- [ ] Create `MLModels/train_horror_model.py`
- [ ] Load `horror_dataset.csv`
- [ ] Train TF-IDF + Logistic Regression classifier
- [ ] Evaluate with 80/20 train-test split (target: >85% accuracy)
- [ ] Convert to CoreML using `coremltools`
- [ ] Save as `HorrorClassifier.mlmodel`
- [ ] Test model with sample inputs

**Python Script Structure**:
```python
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report
import coremltools as ct

# Load data
df = pd.read_csv('datasets/horror_dataset.csv')
X_train, X_test, y_train, y_test = train_test_split(
    df['text'], df['label'], test_size=0.2, random_state=42
)

# Train TF-IDF + Logistic Regression
vectorizer = TfidfVectorizer(max_features=1000, ngram_range=(1,2))
X_train_vec = vectorizer.fit_transform(X_train)
X_test_vec = vectorizer.transform(X_test)

clf = LogisticRegression(max_iter=1000)
clf.fit(X_train_vec, y_train)

# Evaluate
y_pred = clf.predict(X_test_vec)
print(classification_report(y_test, y_pred))

# Convert to CoreML (requires coremltools pipeline)
# Use sklearn-coreml or custom conversion
# Save HorrorClassifier.mlmodel
```

**Deliverable**: `HorrorClassifier.mlmodel` file with >85% accuracy report

---

## 📅 DAY 2: TUESDAY (2 HOURS)
### Train Model 2 & 3 + Initial Swift Integration

**TIME**: 9:00 AM - 11:00 AM

#### ✅ MILESTONE 2.1: Train Model 2 - Cyberbullying Classifier (45 min)
**Tasks**:
- [ ] Create `train_cyberbullying_model.py`
- [ ] Load `cyberbullying_dataset.csv`
- [ ] Train TF-IDF + Logistic Regression (same pipeline as Day 1)
- [ ] Evaluate (target: >85% accuracy)
- [ ] Convert to `CyberbullyingClassifier.mlmodel`
- [ ] Test with examples: "you're so ugly", "nice outfit!", etc.

**Deliverable**: `CyberbullyingClassifier.mlmodel` with validation report

---

#### ✅ MILESTONE 2.2: Train Model 3 - Parasocial Classifier (45 min)
**Tasks**:
- [ ] Create `train_parasocial_model.py`
- [ ] Load `parasocial_dataset.csv`
- [ ] Train model focusing on FOMO triggers, clickbait, manipulation
- [ ] Evaluate (target: >80% accuracy - harder category)
- [ ] Convert to `ParasocialClassifier.mlmodel`
- [ ] Test with: "YOU MUST WATCH THIS NOW", "don't miss out", etc.

**Deliverable**: `ParasocialClassifier.mlmodel` with validation report

---

#### ✅ MILESTONE 2.3: Swift Service Setup (30 min)
**Tasks**:
- [ ] Create `Sources/Komalios/Services/MLContentClassifier.swift`
- [ ] Import CoreML and NaturalLanguage frameworks
- [ ] Add 3 CoreML model files to Xcode project (drag & drop into Resources)
- [ ] Write class structure:

```swift
import Foundation
import CoreML
import NaturalLanguage

@available(iOS 16.0, *)
class MLContentClassifier: ObservableObject {
    private var horrorModel: HorrorClassifier?
    private var cyberbullyingModel: CyberbullyingClassifier?
    private var parasocialModel: ParasocialClassifier?

    init() {
        loadModels()
    }

    private func loadModels() {
        do {
            let config = MLModelConfiguration()
            horrorModel = try HorrorClassifier(configuration: config)
            cyberbullyingModel = try CyberbullyingClassifier(configuration: config)
            parasocialModel = try ParasocialClassifier(configuration: config)
        } catch {
            print("Error loading models: \(error)")
        }
    }

    func classifyText(_ text: String) async throws -> ClassificationResult {
        // TODO: Implement in Day 4
        return ClassificationResult(isHarmful: false, categories: [], confidence: 0.0)
    }
}

struct ClassificationResult {
    let isHarmful: Bool
    let categories: [String]
    let confidence: Double
}
```

**Deliverable**: Swift service stub with 3 models loaded successfully

---

## 📅 DAY 3: WEDNESDAY (2 HOURS)
### Train Model 4 & 5 + Model Integration Architecture

**TIME**: 9:00 AM - 11:00 AM

#### ✅ MILESTONE 3.1: Train Model 4 - Financial Advice Classifier (45 min)
**Tasks**:
- [ ] Create `train_financial_model.py`
- [ ] Load `financial_dataset.csv`
- [ ] Train model detecting crypto tips, stock advice without disclaimers
- [ ] Evaluate (target: >85% accuracy)
- [ ] Convert to `FinancialAdviceClassifier.mlmodel`
- [ ] Test with: "buy this crypto now", "investment opportunity", etc.

**Deliverable**: `FinancialAdviceClassifier.mlmodel` with validation report

---

#### ✅ MILESTONE 3.2: Train Model 5 - Mature Content Classifier (45 min)
**Tasks**:
- [ ] Create `train_mature_content_model.py`
- [ ] Load `mature_dataset.csv` (multi-label: sexual, lgbtq, religious)
- [ ] Train multi-label classifier (use `MultiOutputClassifier` or separate models)
- [ ] Alternative: Train 3 sub-models or single model with probability outputs
- [ ] Evaluate (target: >80% accuracy per label)
- [ ] Convert to `MatureContentClassifier.mlmodel`
- [ ] Test with: "LGBTQ+ pride event", "religious sermon", "kissing scene", etc.

**Python Multi-Label Approach**:
```python
from sklearn.multioutput import MultiOutputClassifier

# Assume labels are: sexual, lgbtq, religious (0/1 for each)
clf = MultiOutputClassifier(LogisticRegression(max_iter=1000))
clf.fit(X_train_vec, y_train_multilabel)
```

**Deliverable**: `MatureContentClassifier.mlmodel` with multi-label validation

---

#### ✅ MILESTONE 3.3: Add Models to Xcode + Update Service (30 min)
**Tasks**:
- [ ] Drag `FinancialAdviceClassifier.mlmodel` and `MatureContentClassifier.mlmodel` into Xcode
- [ ] Verify all 5 `.mlmodel` files compile to Swift classes
- [ ] Update `MLContentClassifier.swift` to load all 5 models
- [ ] Add model properties:

```swift
private var financialModel: FinancialAdviceClassifier?
private var matureContentModel: MatureContentClassifier?
```

- [ ] Update `loadModels()` to initialize all 5 models
- [ ] Create enum for content categories:

```swift
enum ContentCategory: String, CaseIterable {
    case horror = "Horror/Paranormal"
    case cyberbullying = "Cyberbullying"
    case parasocial = "Parasocial/Manipulative"
    case financialAdvice = "Financial Advice"
    case matureContent = "Mature Content"
}
```

**Deliverable**: All 5 models loaded in Swift without errors

---

## 📅 DAY 4: THURSDAY (2 HOURS)
### Full CoreML Integration + BrowserView Hook

**TIME**: 9:00 AM - 11:00 AM

#### ✅ MILESTONE 4.1: Implement Classification Logic (60 min)
**Tasks**:
- [ ] Implement `classifyText(_ text: String) async throws -> ClassificationResult` method
- [ ] Run all 5 models on input text in parallel using `async let`
- [ ] Aggregate results with weighted scoring
- [ ] Return harmful content detection with categories and confidence

**Implementation**:
```swift
func classifyText(_ text: String) async throws -> ClassificationResult {
    guard !text.isEmpty else {
        return ClassificationResult(isHarmful: false, categories: [], confidence: 0.0)
    }

    // Preprocess text (lowercase, remove URLs, etc.)
    let cleanText = preprocessText(text)

    // Run all 5 models in parallel
    async let horrorResult = classifyHorror(cleanText)
    async let bullyingResult = classifyCyberbullying(cleanText)
    async let parasocialResult = classifyParasocial(cleanText)
    async let financialResult = classifyFinancial(cleanText)
    async let matureResult = classifyMature(cleanText)

    let results = try await [
        horrorResult,
        bullyingResult,
        parasocialResult,
        financialResult,
        matureResult
    ]

    // Aggregate results
    var detectedCategories: [String] = []
    var maxConfidence: Double = 0.0

    for (index, result) in results.enumerated() {
        if result.isHarmful {
            detectedCategories.append(ContentCategory.allCases[index].rawValue)
            maxConfidence = max(maxConfidence, result.confidence)
        }
    }

    let isHarmful = !detectedCategories.isEmpty
    return ClassificationResult(
        isHarmful: isHarmful,
        categories: detectedCategories,
        confidence: maxConfidence
    )
}

private func classifyHorror(_ text: String) async throws -> (isHarmful: Bool, confidence: Double) {
    guard let model = horrorModel else {
        throw MLError.modelNotLoaded
    }

    // Call CoreML model (depends on model input/output structure)
    // Example assuming text input and probability output:
    let input = HorrorClassifierInput(text: text)
    let output = try model.prediction(input: input)

    // Assuming output has "horror" probability
    let probability = output.horrorProbability // Adjust based on actual model
    return (isHarmful: probability > 0.7, confidence: probability)
}

// Repeat for other 4 models...
```

- [ ] Create helper methods: `preprocessText()`, `classifyHorror()`, `classifyCyberbullying()`, etc.
- [ ] Handle CoreML errors gracefully
- [ ] Add logging for debugging

**Deliverable**: Complete `MLContentClassifier` service with all 5 models working

---

#### ✅ MILESTONE 4.2: Integrate with BrowserView (45 min)
**Tasks**:
- [ ] Open `Sources/Komalios/Views/BrowserView.swift`
- [ ] Add `@StateObject var mlClassifier = MLContentClassifier()` to BrowserView
- [ ] Hook into WKNavigationDelegate's `decidePolicyFor` method
- [ ] Extract page title + URL for classification
- [ ] Call `mlClassifier.classifyText()` asynchronously
- [ ] If harmful content detected → trigger `BlockedView` or `GateView`
- [ ] Pass detected categories to BlockedView for user feedback

**Integration Code**:
```swift
// In BrowserView's WKNavigationDelegate
func webView(_ webView: WKWebView,
             decidePolicyFor navigationAction: WKNavigationAction,
             decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

    guard let url = navigationAction.request.url else {
        decisionHandler(.allow)
        return
    }

    // Existing blocklist check...

    // NEW: ML-based classification
    Task {
        let textToClassify = "\(url.host ?? "") \(url.path) \(webView.title ?? "")"

        do {
            let result = try await mlClassifier.classifyText(textToClassify)

            if result.isHarmful {
                await MainActor.run {
                    // Show BlockedView with ML-detected categories
                    browserState.blockedCategories = result.categories
                    browserState.showBlockedOverlay = true
                    decisionHandler(.cancel)
                }
            } else {
                decisionHandler(.allow)
            }
        } catch {
            print("ML classification error: \(error)")
            decisionHandler(.allow) // Fallback to allow on error
        }
    }
}
```

- [ ] Update `BrowserState` model to include `blockedCategories: [String]`
- [ ] Update `BlockedView.swift` to display ML-detected categories
- [ ] Test with sample URLs

**Deliverable**: Browser blocks harmful content using ML models in real-time

---

#### ✅ MILESTONE 4.3: Update BlockedView UI (15 min)
**Tasks**:
- [ ] Open `Sources/Komalios/Views/BlockedView.swift`
- [ ] Add display for ML-detected categories
- [ ] Show confidence score (optional)
- [ ] Add "This was detected by AI" badge

**UI Update**:
```swift
VStack(spacing: 20) {
    // Existing blocked icon...

    Text("Content Blocked by AI")
        .font(.title2.bold())

    if !blockedCategories.isEmpty {
        Text("Detected: \(blockedCategories.joined(separator: ", "))")
            .font(.subheadline)
            .foregroundColor(.secondary)
    }

    // Existing buttons...
}
```

**Deliverable**: Enhanced BlockedView showing AI detection results

---

## 📅 DAY 5: FRIDAY (2 HOURS)
### Testing, Optimization & Deployment

**TIME**: 9:00 AM - 11:00 AM

#### ✅ MILESTONE 5.1: Unit Testing (45 min)
**Tasks**:
- [ ] Create `Tests/KomaliosTests/MLContentClassifierTests.swift`
- [ ] Write XCTest cases for each model
- [ ] Test true positives (harmful content correctly detected)
- [ ] Test true negatives (safe content correctly allowed)
- [ ] Test edge cases (empty strings, very long text, special characters)
- [ ] Measure inference latency (target: <100ms per classification)

**Test Structure**:
```swift
import XCTest
@testable import Komalios

final class MLContentClassifierTests: XCTestCase {
    var classifier: MLContentClassifier!

    override func setUp() async throws {
        classifier = MLContentClassifier()
    }

    func testHorrorDetection() async throws {
        let horrorText = "This paranormal ghost story has scary jumpscares"
        let result = try await classifier.classifyText(horrorText)

        XCTAssertTrue(result.isHarmful)
        XCTAssertTrue(result.categories.contains("Horror/Paranormal"))
        XCTAssertGreaterThan(result.confidence, 0.7)
    }

    func testSafeContent() async throws {
        let safeText = "Learn how to bake a delicious chocolate cake"
        let result = try await classifier.classifyText(safeText)

        XCTAssertFalse(result.isHarmful)
        XCTAssertEqual(result.categories.count, 0)
    }

    func testCyberbullyingDetection() async throws {
        let bullyingText = "You're so ugly and worthless, slut"
        let result = try await classifier.classifyText(bullyingText)

        XCTAssertTrue(result.isHarmful)
        XCTAssertTrue(result.categories.contains("Cyberbullying"))
    }

    func testPerformance() {
        measure {
            let text = "Sample text for performance testing"
            Task {
                _ = try? await classifier.classifyText(text)
            }
        }
    }

    // Add 10+ more tests...
}
```

- [ ] Run all tests: `cmd+U` in Xcode
- [ ] Fix any failing tests
- [ ] Achieve >90% pass rate

**Deliverable**: 15+ passing unit tests with performance benchmarks

---

#### ✅ MILESTONE 5.2: End-to-End Testing (30 min)
**Tasks**:
- [ ] Manual testing in iOS Simulator
- [ ] Test URLs that should be blocked:
  - Horror: "reddit.com/r/nosleep"
  - Cyberbullying: "twitter.com/example-bully-post"
  - Parasocial: "youtube.com/watch?v=clickbait-fomo"
  - Financial: "crypto-pump-group.com"
  - Mature: "lgbtq-pride-event.org"
- [ ] Test URLs that should be allowed:
  - "khanacademy.org"
  - "wikipedia.org"
  - "bbc.com/news/science"
- [ ] Test edge cases:
  - Very long URLs
  - Non-English text (if datasets support)
  - Rapid navigation (stress test)
- [ ] Verify BlockedView displays correct categories
- [ ] Test GateView PIN unlock for gated content
- [ ] Test with different age group settings in SettingsView

**Deliverable**: Documented test results with screenshots

---

#### ✅ MILESTONE 5.3: Performance Optimization (30 min)
**Tasks**:
- [ ] Profile app with Instruments (Time Profiler)
- [ ] Identify bottlenecks in ML inference
- [ ] Optimize if inference >200ms:
  - Cache recent classifications (LRU cache)
  - Reduce model size (quantization)
  - Limit text input length (first 500 chars)
- [ ] Add background queue for ML processing
- [ ] Implement debouncing for rapid URL changes
- [ ] Monitor memory usage (target: <50MB increase)

**Caching Implementation**:
```swift
private var classificationCache = NSCache<NSString, ClassificationResult>()

func classifyText(_ text: String) async throws -> ClassificationResult {
    let cacheKey = text.prefix(200) as NSString
    if let cached = classificationCache.object(forKey: cacheKey) {
        return cached
    }

    let result = try await performClassification(text)
    classificationCache.setObject(result, forKey: cacheKey)
    return result
}
```

**Deliverable**: App runs smoothly with <100ms classification latency

---

#### ✅ MILESTONE 5.4: Documentation & Handoff (15 min)
**Tasks**:
- [ ] Create `MLModels/README.md` with:
  - Model training instructions
  - Dataset format specifications
  - Retraining guide for future updates
  - Performance benchmarks
- [ ] Add inline code comments to `MLContentClassifier.swift`
- [ ] Update main `README.md` with ML features section
- [ ] Create demo video showing ML blocking in action
- [ ] Prepare handoff document with known limitations

**Deliverable**: Complete documentation package

---

## 📦 FINAL DELIVERABLES CHECKLIST

### ✅ Code Artifacts
- [ ] 5 CoreML models (.mlmodel files) in Xcode project
- [ ] `MLContentClassifier.swift` service (200+ lines)
- [ ] Updated `BrowserView.swift` with ML integration
- [ ] Updated `BlockedView.swift` with AI detection UI
- [ ] Updated `BrowserState.swift` model
- [ ] `MLContentClassifierTests.swift` with 15+ tests

### ✅ ML Artifacts
- [ ] 5 Python training scripts
- [ ] 5 CSV datasets (1000+ total samples)
- [ ] 5 trained models with >80% accuracy
- [ ] Training reports (accuracy, precision, recall, F1)

### ✅ Documentation
- [ ] `MLModels/README.md` - Training guide
- [ ] Updated main `README.md` - ML features
- [ ] Code comments in Swift files
- [ ] Test results document
- [ ] Demo video (2-3 min)

### ✅ Git Commits
- [ ] Day 1: "Add ML dataset preparation and Horror classifier"
- [ ] Day 2: "Add Cyberbullying and Parasocial classifiers + Swift service"
- [ ] Day 3: "Add Financial and Mature Content classifiers"
- [ ] Day 4: "Integrate CoreML into BrowserView with real-time classification"
- [ ] Day 5: "Add ML tests, optimization, and documentation"

---

## 🎯 SUCCESS METRICS

1. **Model Performance**: All 5 models achieve >80% accuracy on test sets
2. **Integration**: ML classification runs on every URL navigation without crashes
3. **Performance**: Classification completes in <100ms (90th percentile)
4. **User Experience**: BlockedView clearly shows AI-detected categories
5. **Code Quality**: All unit tests pass, no memory leaks
6. **Documentation**: Future developers can retrain models independently

---

## 🚨 RISK MITIGATION

### If Behind Schedule:
- **Day 1 overrun**: Skip manual labeling, use GPT-4 to generate all 1000+ samples
- **Day 2 overrun**: Use Create ML app (GUI) instead of Python scripts
- **Day 3 overrun**: Merge Financial + Mature into single model (4 total models)
- **Day 4 overrun**: Skip caching, use synchronous classification
- **Day 5 overrun**: Reduce test coverage to 5 core tests

### If Model Accuracy Low:
- Increase dataset size (use data augmentation)
- Try different algorithms (SVM, Random Forest, BERT embeddings)
- Adjust confidence threshold (lower from 0.7 to 0.5)
- Fall back to rule-based filtering for low-confidence predictions

### If CoreML Conversion Fails:
- Use Apple's Create ML for direct .mlmodel output
- Simplify model (use smaller vocabulary, simpler features)
- Manual conversion using coremltools tutorials

---

## 📞 DAILY STANDUPS (15 min each day)

**9:00 AM - Check-in Questions**:
1. What did you complete yesterday?
2. What blockers do you have?
3. What will you deliver today?

**11:00 AM - Check-out**:
1. Demo what you built
2. Show test results
3. Confirm tomorrow's goals

---

## 🎓 DEVELOPER RESOURCES

### CoreML Tutorials:
- [Apple CoreML Documentation](https://developer.apple.com/documentation/coreml)
- [coremltools Python Package](https://coremltools.readme.io/)
- [Create ML App Guide](https://developer.apple.com/documentation/createml)

### SwiftUI + ML Integration:
- [Integrating CoreML in SwiftUI](https://developer.apple.com/videos/play/wwdc2022/10027/)
- [NaturalLanguage Framework](https://developer.apple.com/documentation/naturallanguage)

### Dataset Resources:
- [Hate Speech Detection Dataset](https://huggingface.co/datasets/hate_speech18)
- [Toxic Comments Dataset](https://www.kaggle.com/c/jigsaw-toxic-comment-classification-challenge)
- [Reddit Comments Dataset](https://www.reddit.com/r/datasets/)

---

**END OF PLAN**

*Total Time: 10 hours | Total Models: 5 | Total Tests: 15+ | Total Commits: 5*
