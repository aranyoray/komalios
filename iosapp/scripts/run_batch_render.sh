#!/bin/bash
# Batch render script for Komal Emoji Avatar Engine

set -e

# Default values
COUNT=${1:-10}
COMPUTE_HEAVY=${2:-false}
OUTPUT_DIR="batch_outputs"

echo "Komal Batch Render"
echo "=================="
echo "Count: $COUNT"
echo "Compute Heavy: $COMPUTE_HEAVY"
echo "Output: $OUTPUT_DIR"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Build command
CMD="python emoji_avatar_engine.py --batch_generate $COUNT"

if [ "$COMPUTE_HEAVY" == "true" ]; then
    CMD="$CMD --compute_heavy"
fi

# Run
echo "Starting batch render..."
start_time=$(date +%s)

$CMD

end_time=$(date +%s)
duration=$((end_time - start_time))

echo ""
echo "Batch render complete!"
echo "Duration: ${duration}s"
echo "Output: $OUTPUT_DIR/"

# List outputs
echo ""
echo "Generated files:"
ls -lh "$OUTPUT_DIR"/*.mp4 2>/dev/null | head -20 || echo "No MP4 files found"
