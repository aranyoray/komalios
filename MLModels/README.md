# 🤖 CoreML Content Classification Models

This folder contains training scripts, datasets, and CoreML models for content safety classification in Komalios.

## 📁 Folder Structure

```
MLModels/
├── datasets/                      # Training datasets (CSV format)
│   ├── horror_dataset.csv         # Horror/paranormal content (200+ samples)
│   ├── cyberbullying_dataset.csv  # Bullying/harassment content (200+ samples)
│   ├── parasocial_dataset.csv     # Manipulative influencer content (200+ samples)
│   ├── financial_dataset.csv      # Risky financial advice (200+ samples)
│   └── mature_dataset.csv         # Mature content multi-label (300+ samples)
├── train_template.py              # Training script template
├── MLContentClassifier_template.swift  # Swift integration template
└── README.md                      # This file
```

## 🚀 Quick Start

### Prerequisites
```bash
# Install Python dependencies
pip install coremltools scikit-learn pandas numpy
```

### Training Models

**Option 1: Use Python Script (Traditional ML)**
```bash
cd MLModels
python train_template.py horror
python train_template.py cyberbullying
python train_template.py parasocial
python train_template.py financial
python train_template.py mature
```

**Option 2: Use Create ML (Recommended for beginners)**
1. Open Create ML app on macOS
2. Create new **Text Classifier** project
3. Drag CSV file into training data
4. Click Train
5. Export as `.mlmodel` file

### Model Names
After training, you should have these 5 CoreML models:
- `HorrorClassifier.mlmodel`
- `CyberbullyingClassifier.mlmodel`
- `ParasocialClassifier.mlmodel`
- `FinancialAdviceClassifier.mlmodel`
- `MatureContentClassifier.mlmodel`

## 📊 Dataset Format

All datasets follow this CSV structure:
```csv
text,label
"Example harmful content",harmful_label
"Example safe content",safe
```

**Special Case: Mature Content (Multi-label)**
```csv
text,label_sexual,label_lgbtq,label_religious
"Example text",0,1,0
```

### Dataset Statistics
| Dataset | Total Samples | Positive Samples | Negative Samples |
|---------|--------------|------------------|------------------|
| Horror | 60 | 30 | 30 |
| Cyberbullying | 60 | 30 | 30 |
| Parasocial | 60 | 30 | 30 |
| Financial | 60 | 30 | 30 |
| Mature Content | 60 | 20/20/20 (multi) | 20 |

**⚠️ WARNING: These are STARTER datasets!** For production, you need 1000+ samples per category.

## 🔧 Expanding Datasets

To improve model accuracy, add more samples:

### Manual Labeling
1. Open CSV in Excel/Sheets
2. Add rows with `text,label` format
3. Ensure balanced distribution (50/50 harmful/safe)
4. Save as CSV

### Synthetic Data Generation
Use GPT-4 or Claude to generate examples:
```
Prompt: "Generate 50 examples of horror-related content descriptions
that would be inappropriate for children under 10. Format as CSV with
columns: text, label (where label=horror)"
```

### Web Scraping (Legal sources only)
- Reddit comments with content warnings
- YouTube video titles/descriptions with age restrictions
- Content moderation datasets (Kaggle, HuggingFace)

## 🎯 Model Performance Targets

| Model | Target Accuracy | Actual Accuracy |
|-------|----------------|-----------------|
| Horror | >85% | TBD after training |
| Cyberbullying | >85% | TBD after training |
| Parasocial | >80% | TBD after training |
| Financial | >85% | TBD after training |
| Mature Content | >80% per label | TBD after training |

## 📱 Integration with iOS App

### Step 1: Add Models to Xcode
1. Drag `.mlmodel` files into Xcode project
2. Ensure "Copy items if needed" is checked
3. Verify models compile (Xcode auto-generates Swift classes)

### Step 2: Use MLContentClassifier Service
```swift
import SwiftUI

struct BrowserView: View {
    @StateObject private var mlClassifier = MLContentClassifier()

    func checkURL(_ url: URL) {
        Task {
            let text = "\(url.host ?? "") \(url.path)"
            let result = try await mlClassifier.classifyText(text)

            if result.isHarmful {
                // Show BlockedView
                blockedCategories = result.categories
                showBlocked = true
            }
        }
    }
}
```

### Step 3: Test Models
```bash
# Run unit tests in Xcode
cmd+U
```

## 🔄 Retraining Models

When to retrain:
- Accuracy drops below 80%
- False positives/negatives are reported
- New content patterns emerge
- Dataset expands significantly

How to retrain:
1. Update CSV files with new samples
2. Re-run training script: `python train_template.py <model_name>`
3. Replace old `.mlmodel` in Xcode
4. Clean build: `cmd+shift+K`
5. Test thoroughly

## 🧪 Testing Checklist

Before deploying models:
- [ ] All 5 models achieve >80% accuracy
- [ ] Test with 20+ real-world examples per category
- [ ] Measure inference latency (<100ms per classification)
- [ ] Test edge cases (empty strings, very long text, special chars)
- [ ] Verify no memory leaks (Instruments profiling)
- [ ] Check false positive rate (<10%)
- [ ] Check false negative rate (<10%)

## 📚 Resources

### CoreML Documentation
- [Apple CoreML Guide](https://developer.apple.com/documentation/coreml)
- [Create ML Documentation](https://developer.apple.com/documentation/createml)
- [coremltools Python Package](https://coremltools.readme.io/)

### Dataset Sources
- [HuggingFace Datasets](https://huggingface.co/datasets)
- [Kaggle Competitions](https://www.kaggle.com/competitions)
- [UCI ML Repository](https://archive.ics.uci.edu/ml/index.php)

### ML Tutorials
- [Text Classification with Create ML](https://www.youtube.com/watch?v=a905KIBw1hs)
- [CoreML in SwiftUI](https://www.hackingwithswift.com/books/ios-swiftui/integrating-core-ml-into-swiftui)

## ⚠️ Limitations

Current models have these limitations:
1. **Language**: Only English supported (requires multilingual datasets for other languages)
2. **Context**: Limited context window (500 chars max for performance)
3. **Nuance**: May miss sarcasm, cultural references, coded language
4. **Adversarial**: Vulnerable to intentional obfuscation (l33t speak, etc.)
5. **Bias**: Reflect biases in training data (requires diverse datasets)

## 🚧 Future Improvements

- [ ] Expand datasets to 1000+ samples each
- [ ] Add multilingual support (Spanish, French, etc.)
- [ ] Implement transfer learning with BERT embeddings
- [ ] Add explainability (highlight harmful words)
- [ ] Create model versioning system
- [ ] Implement A/B testing for model updates
- [ ] Add feedback loop (user reports → retraining)
- [ ] Optimize model size (quantization, pruning)

## 📞 Support

For questions about ML integration:
- Check main project README.md
- Review DEVELOPMENT_PLAN.md for detailed implementation steps
- Consult Apple Developer Forums for CoreML issues

---

**Last Updated**: 2026-01-18
**Models Version**: 1.0.0
**Maintainer**: Development Team
