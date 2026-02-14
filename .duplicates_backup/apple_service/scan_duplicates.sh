#!/bin/bash

# 🔍 DUPLICATE FILE REPORT
# Scans the project and reports all duplicate Swift files

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 DUPLICATE FILE SCANNER"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Function to find duplicates
find_duplicates() {
    local base_dir=$1
    
    # Find all .swift files
    find "$base_dir" -name "*.swift" -type f 2>/dev/null | \
        awk -F/ '{print $NF}' | \
        sort | \
        uniq -d
}

# Get list of duplicate filenames
duplicates=$(find_duplicates "Sources")

if [ -z "$duplicates" ]; then
    echo "✅ No duplicate filenames found!"
    echo ""
    exit 0
fi

echo "⚠️  DUPLICATES FOUND:"
echo ""

# For each duplicate, show all locations
while IFS= read -r filename; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📄 $filename"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Find all instances
    find Sources -name "$filename" -type f 2>/dev/null | while read -r filepath; do
        echo "  📍 $filepath"
        
        # Show first few lines to identify the file
        echo "     First 10 lines:"
        head -10 "$filepath" | sed 's/^/       /'
        echo ""
    done
    
    echo ""
done <<< "$duplicates"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

duplicate_count=$(echo "$duplicates" | wc -l | tr -d ' ')
echo "Total duplicate filenames: $duplicate_count"
echo ""

echo "🔧 RECOMMENDED ACTIONS:"
echo ""
echo "Option 1: Rename files to make them unique"
echo "  Example: AppState.swift → PreAuthAppState.swift"
echo ""
echo "Option 2: Delete/move older duplicates"
echo "  Run: ./fix_duplicates.sh"
echo ""
echo "Option 3: Manually review and decide which to keep"
echo "  Review the file contents above"
echo ""
