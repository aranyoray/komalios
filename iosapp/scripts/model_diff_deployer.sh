#!/bin/bash
# model_diff_deployer.sh — Server-side delta builder for CI
# Builds full model and delta patches, uploads to CDN, generates manifest

set -e

# Configuration
MODEL_DIR="${MODEL_DIR:-./models}"
OUTPUT_DIR="${OUTPUT_DIR:-./deploy}"
CDN_BUCKET="${CDN_BUCKET:-s3://komal-models}"
DELTA_THRESHOLD="${DELTA_THRESHOLD:-20}"  # Minimum % savings required
VERSION_FILE="${MODEL_DIR}/version.txt"

echo "==================================="
echo "Model Diff Deployer"
echo "==================================="

# Parse arguments
FORCE_FULL=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force-full) FORCE_FULL=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --threshold) DELTA_THRESHOLD="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Get current and previous versions
CURRENT_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "1.0.0")
PREV_VERSION=$(aws s3 cp "$CDN_BUCKET/latest/version.txt" - 2>/dev/null || echo "")

echo "Current version: $CURRENT_VERSION"
echo "Previous version: ${PREV_VERSION:-none}"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Find model files
MODEL_FILES=$(find "$MODEL_DIR" -name "*.pt" -o -name "*.onnx" -o -name "*.tflite" 2>/dev/null)

if [ -z "$MODEL_FILES" ]; then
    echo "No model files found in $MODEL_DIR"
    exit 1
fi

# Initialize manifest
MANIFEST_FILE="$OUTPUT_DIR/manifest.json"
echo '{"version":"'"$CURRENT_VERSION"'","files":[],"deltas":[]}' > "$MANIFEST_FILE"

total_full_size=0
total_delta_size=0
delta_count=0

for model_file in $MODEL_FILES; do
    filename=$(basename "$model_file")
    echo ""
    echo "Processing: $filename"

    # Copy full model
    cp "$model_file" "$OUTPUT_DIR/$filename"
    full_size=$(stat -f%z "$OUTPUT_DIR/$filename" 2>/dev/null || stat -c%s "$OUTPUT_DIR/$filename")
    total_full_size=$((total_full_size + full_size))

    # Compute hash
    hash=$(sha256sum "$model_file" | cut -d' ' -f1)

    # Update manifest with full file
    jq --arg name "$filename" --arg hash "$hash" --arg size "$full_size" \
       '.files += [{"name":$name,"hash":$hash,"size":($size|tonumber)}]' \
       "$MANIFEST_FILE" > "$MANIFEST_FILE.tmp" && mv "$MANIFEST_FILE.tmp" "$MANIFEST_FILE"

    # Create delta if previous version exists
    if [ -n "$PREV_VERSION" ] && [ "$FORCE_FULL" = false ]; then
        prev_file="/tmp/prev_$filename"

        if aws s3 cp "$CDN_BUCKET/$PREV_VERSION/$filename" "$prev_file" 2>/dev/null; then
            delta_file="$OUTPUT_DIR/${filename}.delta"

            # Create delta using bsdiff or xdelta
            if command -v bsdiff &> /dev/null; then
                bsdiff "$prev_file" "$model_file" "$delta_file"
            elif command -v xdelta3 &> /dev/null; then
                xdelta3 -e -s "$prev_file" "$model_file" "$delta_file"
            else
                echo "Warning: No diff tool available, skipping delta"
                continue
            fi

            delta_size=$(stat -f%z "$delta_file" 2>/dev/null || stat -c%s "$delta_file")
            savings=$(echo "scale=2; (1 - $delta_size / $full_size) * 100" | bc)

            echo "  Delta size: $delta_size bytes (${savings}% savings)"

            # Check threshold
            if (( $(echo "$savings < $DELTA_THRESHOLD" | bc -l) )); then
                echo "  Warning: Savings below threshold ($DELTA_THRESHOLD%)"
                if [ "$DRY_RUN" = false ]; then
                    echo "  Failing build - delta not efficient enough"
                    exit 1
                fi
            fi

            total_delta_size=$((total_delta_size + delta_size))
            delta_count=$((delta_count + 1))

            # Update manifest with delta
            prev_hash=$(sha256sum "$prev_file" | cut -d' ' -f1)
            jq --arg name "${filename}.delta" --arg from "$prev_hash" --arg to "$hash" \
               --arg size "$delta_size" --arg savings "$savings" \
               '.deltas += [{"name":$name,"from_hash":$from,"to_hash":$to,"size":($size|tonumber),"savings":$savings}]' \
               "$MANIFEST_FILE" > "$MANIFEST_FILE.tmp" && mv "$MANIFEST_FILE.tmp" "$MANIFEST_FILE"

            rm -f "$prev_file"
        fi
    fi
done

# Add summary to manifest
overall_savings=0
if [ $total_full_size -gt 0 ] && [ $delta_count -gt 0 ]; then
    overall_savings=$(echo "scale=2; (1 - $total_delta_size / $total_full_size) * 100" | bc)
fi

jq --arg total_full "$total_full_size" --arg total_delta "$total_delta_size" \
   --arg savings "$overall_savings" --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '. + {"summary":{"total_full_size":($total_full|tonumber),"total_delta_size":($total_delta|tonumber),"overall_savings":$savings,"timestamp":$timestamp}}' \
   "$MANIFEST_FILE" > "$MANIFEST_FILE.tmp" && mv "$MANIFEST_FILE.tmp" "$MANIFEST_FILE"

echo ""
echo "==================================="
echo "Summary"
echo "==================================="
echo "Full model size: $total_full_size bytes"
echo "Delta size: $total_delta_size bytes"
echo "Overall savings: ${overall_savings}%"
echo "Manifest: $MANIFEST_FILE"

# Upload to CDN
if [ "$DRY_RUN" = false ]; then
    echo ""
    echo "Uploading to CDN..."

    # Upload versioned files
    aws s3 sync "$OUTPUT_DIR" "$CDN_BUCKET/$CURRENT_VERSION/" --exclude "*.tmp"

    # Update latest pointer
    echo "$CURRENT_VERSION" | aws s3 cp - "$CDN_BUCKET/latest/version.txt"
    aws s3 cp "$MANIFEST_FILE" "$CDN_BUCKET/latest/manifest.json"

    echo "Upload complete: $CDN_BUCKET/$CURRENT_VERSION/"
else
    echo ""
    echo "[DRY RUN] Would upload to: $CDN_BUCKET/$CURRENT_VERSION/"
fi

echo ""
echo "Done!"
