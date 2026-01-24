# 🚀 Quick Start: Generate CoreML Models

## Option 1: Use Create ML (Easiest - Recommended)

Create ML is Apple's GUI tool for training models. It's the easiest way to generate CoreML models.

### Steps:

1. **Open Create ML** (comes with Xcode, search in Spotlight)
2. **Create New Project** → Choose "Text Classifier"
3. **Import Data:**
   - Drag `datasets/horror_dataset.csv` into the training data section
   - Make sure it detects "text" and "label" columns
4. **Train:**
   - Click "Train" button
   - Wait for training to complete (usually 1-2 minutes)
5. **Export:**
   - Click "Get" button
   - Save as `HorrorClassifier.mlmodel`
   - Repeat for other datasets

### Models to Create:
- `HorrorClassifier.mlmodel` (from `horror_dataset.csv`)
- `CyberbullyingClassifier.mlmodel` (from `cyberbullying_dataset.csv`)
- `ParasocialClassifier.mlmodel` (from `parasocial_dataset.csv`)
- `FinancialAdviceClassifier.mlmodel` (from `financial_dataset.csv`)
- `MatureContentClassifier.mlmodel` (from `mature_dataset.csv`)

### After Exporting:
1. Drag `.mlmodel` files into Xcode project
2. Ensure "Copy items if needed" is checked
3. Xcode will auto-generate Swift classes
4. Models are ready to use!

---

## Option 2: Python Script (Advanced)

If you have Python and coremltools installed:

```bash
cd MLModels
pip install coremltools scikit-learn pandas
python train_models.py
```

This will attempt to generate all models automatically.

**Note:** Text classification conversion can be tricky. Create ML is more reliable.

---

## Option 3: I Can Help Train Them

If you want, I can:
1. Create a more robust training script
2. Help you set up the Python environment
3. Generate models using your datasets

Just let me know which option you prefer!

---

## After Models Are Created

Once you have `.mlmodel` files:

1. **Add to Xcode:**
   - Drag files into project navigator
   - Check "Copy items if needed"
   - Add to target "Komalios"

2. **Verify:**
   - Xcode should show model info when you click on `.mlmodel`
   - Swift classes are auto-generated (e.g., `HorrorClassifier`)

3. **Test:**
   - The `ContentAnalysisService` will automatically use them
   - Models are loaded in `detectWithCoreML()` method

---

## Troubleshooting

**"Models not found" error:**
- Make sure `.mlmodel` files are in Xcode project
- Check target membership
- Clean build folder (Cmd+Shift+K)

**Low accuracy:**
- Add more training data (aim for 100+ samples per category)
- Balance positive/negative examples
- Review data quality

**Conversion fails:**
- Use Create ML instead (more reliable for text)
- Check dataset format (CSV with "text" and "label" columns)
