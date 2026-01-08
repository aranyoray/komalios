#!/bin/bash
# run_all_generate.sh — Run all generation scripts with synthetic data and dry run modes.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_BASE="${OUTPUT_BASE:-./outputs}"
SYNTHETIC="${SYNTHETIC:-1000}"
DRY_RUN="${DRY_RUN:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --synthetic)
            SYNTHETIC="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_BASE="$2"
            shift 2
            ;;
        *)
            log_error "Unknown argument: $1"
            exit 1
            ;;
    esac
done

DRY_RUN_FLAG=""
if [ "$DRY_RUN" = true ]; then
    DRY_RUN_FLAG="--dry_run"
    log_info "Running in DRY RUN mode"
fi

log_info "Output directory: $OUTPUT_BASE"
log_info "Synthetic samples: $SYNTHETIC"

mkdir -p "$OUTPUT_BASE"

# List of scripts to run
SCRIPTS=(
    "client_side_personalizer.py:--out_dir ${OUTPUT_BASE}/personalizer --synthetic ${SYNTHETIC}"
    "fuse_and_compress.py:--out_dir ${OUTPUT_BASE}/fuse_compress --synthetic ${SYNTHETIC}"
    "latency_auto_optimize.py:--out_dir ${OUTPUT_BASE}/latency_optimize --synthetic ${SYNTHETIC}"
    "touch_gesture_builder.py:--out_dir ${OUTPUT_BASE}/touch_gesture --synthetic ${SYNTHETIC}"
    "sensitivity_calibrator.py:--out_dir ${OUTPUT_BASE}/sensitivity --synthetic ${SYNTHETIC}"
    "explainability_reporter.py:--out_dir ${OUTPUT_BASE}/explainability --synthetic ${SYNTHETIC}"
    "cross_device_validator.py:--out_dir ${OUTPUT_BASE}/cross_device --synthetic ${SYNTHETIC}"
    "battery_simulator.py:--out_dir ${OUTPUT_BASE}/battery"
    "privacy_feature_hash.py:--out_dir ${OUTPUT_BASE}/privacy --synthetic ${SYNTHETIC}"
    "emotion_event_detector.py:--out_dir ${OUTPUT_BASE}/emotion_events --synthetic ${SYNTHETIC}"
    "client_curriculum_rl.py:--out_dir ${OUTPUT_BASE}/curriculum_rl --synthetic ${SYNTHETIC}"
    "camera_noise_stress_test.py:--out_dir ${OUTPUT_BASE}/noise_stress --synthetic ${SYNTHETIC}"
    "attention_decay_predictor.py:--out_dir ${OUTPUT_BASE}/attention_decay --synthetic ${SYNTHETIC}"
    "gaze_kd_fast.py:--out_dir ${OUTPUT_BASE}/gaze_kd --synthetic ${SYNTHETIC}"
    "touch_to_emotion_model.py:--out_dir ${OUTPUT_BASE}/touch_emotion --synthetic ${SYNTHETIC}"
)

# Track results
PASSED=0
FAILED=0
FAILED_SCRIPTS=""

# Run each script
for script_entry in "${SCRIPTS[@]}"; do
    IFS=':' read -r script_name script_args <<< "$script_entry"
    script_path="${SCRIPT_DIR}/${script_name}"

    if [ ! -f "$script_path" ]; then
        log_warn "Script not found: $script_path"
        ((FAILED++))
        FAILED_SCRIPTS="${FAILED_SCRIPTS}\n  - ${script_name} (not found)"
        continue
    fi

    log_info "Running: $script_name"

    if python "$script_path" $script_args $DRY_RUN_FLAG; then
        log_info "  ✓ $script_name completed"
        ((PASSED++))
    else
        log_error "  ✗ $script_name failed"
        ((FAILED++))
        FAILED_SCRIPTS="${FAILED_SCRIPTS}\n  - ${script_name}"
    fi
done

# Summary
echo ""
echo "========================================="
echo "           EXECUTION SUMMARY"
echo "========================================="
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"

if [ $FAILED -gt 0 ]; then
    echo -e "\nFailed scripts:${FAILED_SCRIPTS}"
fi

# Generate master manifest
log_info "Generating master manifest..."
python - << 'EOF'
import pandas as pd
from pathlib import Path
import sys

output_base = Path(sys.argv[1] if len(sys.argv) > 1 else './outputs')
all_manifests = []

for manifest_path in output_base.rglob('artifacts_manifest.csv'):
    try:
        df = pd.read_csv(manifest_path)
        df['source_dir'] = manifest_path.parent.name
        all_manifests.append(df)
    except Exception as e:
        print(f"  Warning: Could not read {manifest_path}: {e}")

if all_manifests:
    master = pd.concat(all_manifests, ignore_index=True)
    master_path = output_base / 'master_manifest.csv'
    master.to_csv(master_path, index=False)
    print(f"  Master manifest: {master_path} ({len(master)} artifacts)")
else:
    print("  No manifests found")
EOF "$OUTPUT_BASE"

echo ""
log_info "All scripts completed. Outputs in: $OUTPUT_BASE"
