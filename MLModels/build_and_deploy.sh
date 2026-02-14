#!/bin/bash
# build_and_deploy.sh
# Complete end-to-end pipeline from CSV to deployed iOS app

set -e  # Exit on error

echo "=================================================="
echo "Content Safety Engine - Build & Deploy Pipeline"
echo "=================================================="

# Configuration
CSV_FILE="Models_Masterlist_Fixed.csv"
RESOURCES_DIR="ContentSafetyEngine/Sources/ContentSafetyEngine/Resources"
TRAINING_DATA="Training/datasets"
OUTPUT_DIR="Training/output"

# ============================================================================
# Step 1: Generate Policy Bundle
# ============================================================================

echo ""
echo "Step 1: Generating policy bundle from CSV..."
python3 Tools/policy_generator.py "$CSV_FILE" "$RESOURCES_DIR"

if [ $? -ne 0 ]; then
    echo "❌ Policy generation failed!"
    exit 1
fi

echo "✓ Policy bundle generated"

# ============================================================================
# Step 2: Regenerate Keywords (Optional - for training)
# ============================================================================

echo ""
echo "Step 2: Regenerating keywords from data..."

# This script would:
# - Load all datasets
# - Extract TF-IDF n-grams
# - Run KeyBERT for keyphrases
# - Filter by MI / log-odds
# - Update keywords_major.json + keywords_sub.json

# python3 Tools/regenerate_keywords.py \
#     --data "$TRAINING_DATA" \
#     --csv "$CSV_FILE" \
#     --output "$RESOURCES_DIR"

echo "✓ Keywords regenerated (skipped for now - using CSV keywords)"

# ============================================================================
# Step 3: Train Text Model
# ============================================================================

echo ""
echo "Step 3: Training text classification model..."

mkdir -p "$OUTPUT_DIR"

python3 Training/train_text_model.py \
    --data "$TRAINING_DATA" \
    --keywords "$RESOURCES_DIR/keywords_major.json" \
    --output "$OUTPUT_DIR/SafetyClassifier.mlpackage" \
    --model "distilbert-base-uncased" \
    --epochs 3 \
    --batch-size 16 \
    --lr 2e-5 \
    --max-length 384 \
    --quantize w8a8

if [ $? -ne 0 ]; then
    echo "❌ Text model training failed!"
    exit 1
fi

echo "✓ Text model trained and quantized"

# ============================================================================
# Step 4: Train Vision Models
# ============================================================================

echo ""
echo "Step 4: Training NSFW detector..."

python3 Training/train_nsfw_model.py \
    --data "$TRAINING_DATA/nsfw" \
    --output "$OUTPUT_DIR/NSFWDetector.mlpackage" \
    --arch mobilenet_v3_small \
    --epochs 5 \
    --quantize int8

if [ $? -ne 0 ]; then
    echo "❌ NSFW model training failed!"
    exit 1
fi

echo "✓ NSFW detector trained and quantized"

# Optional: Train violence detector
# python3 Training/train_violence_model.py \
#     --data "$TRAINING_DATA/violence" \
#     --output "$OUTPUT_DIR/ViolenceDetector.mlpackage" \
#     --quantize int8

# ============================================================================
# Step 5: Compile CoreML Models
# ============================================================================

echo ""
echo "Step 5: Compiling CoreML models..."

xcrun coremlcompiler compile \
    "$OUTPUT_DIR/SafetyClassifier.mlpackage" \
    "$OUTPUT_DIR"

xcrun coremlcompiler compile \
    "$OUTPUT_DIR/NSFWDetector.mlpackage" \
    "$OUTPUT_DIR"

echo "✓ Models compiled to .mlmodelc"

# ============================================================================
# Step 6: Copy to Resources
# ============================================================================

echo ""
echo "Step 6: Copying models to Resources..."

cp "$OUTPUT_DIR/SafetyClassifier.mlmodelc" "$RESOURCES_DIR/"
cp "$OUTPUT_DIR/NSFWDetector.mlmodelc" "$RESOURCES_DIR/"

echo "✓ Models copied to Resources"

# ============================================================================
# Step 7: Run Tests
# ============================================================================

echo ""
echo "Step 7: Running tests..."

cd ContentSafetyEngine
swift test

if [ $? -ne 0 ]; then
    echo "❌ Tests failed!"
    exit 1
fi

echo "✓ All tests passed"

# ============================================================================
# Step 8: Build Swift Package
# ============================================================================

echo ""
echo "Step 8: Building Swift package..."

swift build -c release

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo "✓ Swift package built"

# ============================================================================
# Step 9: Profile Performance
# ============================================================================

echo ""
echo "Step 9: Profiling performance..."

# Run performance tests
swift test --filter PerformanceTests

echo "✓ Performance profiling complete"

# ============================================================================
# Step 10: Package for Distribution
# ============================================================================

echo ""
echo "Step 10: Packaging for distribution..."

# Create XCFramework
swift build -c release --arch arm64 --arch x86_64

# Create archive
tar -czf ContentSafetyEngine-1.0.0.tar.gz \
    ContentSafetyEngine/Sources \
    ContentSafetyEngine/Package.swift \
    ContentSafetyEngine/README.md

echo "✓ Package created: ContentSafetyEngine-1.0.0.tar.gz"

# ============================================================================
# Done!
# ============================================================================

echo ""
echo "=================================================="
echo "✅ Build pipeline completed successfully!"
echo "=================================================="
echo ""
echo "Next steps:"
echo "  1. Review test results"
echo "  2. Profile on real devices (iPhone 12-15)"
echo "  3. Verify ANE usage with Instruments"
echo "  4. Integrate into your app"
echo ""
echo "Integration example:"
echo "  import ContentSafetyEngine"
echo "  let engine = try await ContentSafetyEngine()"
echo "  let verdict = try await engine.analyze(content, for: .age10to13)"
echo ""
echo "For more info, see:"
echo "  - ContentSafetyEngine/README.md"
echo "  - IMPLEMENTATION_SUMMARY.md"
echo ""
