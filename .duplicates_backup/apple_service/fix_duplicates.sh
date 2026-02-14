#!/bin/bash

# 🔧 DUPLICATE FILES FIX SCRIPT
# Fixes: "Filename used twice" errors in Swift Package Manager

set -e

echo "🔍 Scanning for duplicate Swift files..."

# Known duplicates from error message
DUPLICATES=(
    "AppState.swift"
    "Routes.swift"
    "PathManager.swift"
    "AuthViewModel.swift"
    "Nonce.swift"
    "AppleSignInResult.swift"
)

echo ""
echo "📋 Files to check for duplicates:"
for file in "${DUPLICATES[@]}"; do
    echo "  - $file"
done

echo ""
echo "🔍 Finding all instances..."

for filename in "${DUPLICATES[@]}"; do
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Checking: $filename"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Find all instances
    instances=$(find Sources -name "$filename" 2>/dev/null || echo "")
    
    if [ -z "$instances" ]; then
        echo "  ℹ️  Not found in Sources/"
        continue
    fi
    
    count=$(echo "$instances" | wc -l | tr -d ' ')
    
    if [ "$count" -gt 1 ]; then
        echo "  ⚠️  Found $count instances:"
        echo "$instances" | sed 's/^/      /'
        echo ""
        echo "  🔧 Keeping ONLY the first instance, moving others to .duplicates/"
        
        # Keep first, move rest
        first=true
        while IFS= read -r filepath; do
            if [ "$first" = true ]; then
                echo "      ✅ KEEP: $filepath"
                first=false
            else
                echo "      🗑️  MOVE: $filepath → .duplicates/"
                mkdir -p .duplicates/$(dirname "$filepath")
                mv "$filepath" ".duplicates/$filepath"
            fi
        done <<< "$instances"
    else
        echo "  ✅ Only 1 instance found"
        echo "$instances" | sed 's/^/      /'
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧹 Checking for other duplicate .swift files..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Find all .swift files and check for duplicates
find Sources -name "*.swift" -type f 2>/dev/null | \
    xargs -I {} basename {} | \
    sort | \
    uniq -d | \
    while read -r dup; do
        echo ""
        echo "⚠️  Found duplicate: $dup"
        find Sources -name "$dup" | sed 's/^/    /'
    done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ DUPLICATE CLEANUP COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📂 Moved files are in: .duplicates/"
echo ""
echo "🔄 Next steps:"
echo "   1. Review moved files in .duplicates/"
echo "   2. Clean build: rm -rf .build Package.resolved"
echo "   3. Rebuild: swift build"
echo ""
