#!/bin/bash

# 🚨 EMERGENCY DUPLICATE FIX
# Automatically resolves "Filename used twice" errors

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚨 DUPLICATE FILE EMERGENCY FIX"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Files that were auto-created and might be duplicates
AUTO_CREATED=(
    "AppState.swift"
    "Routes.swift"
    "PathManager.swift"
    "AuthViewModel.swift"
    "Nonce.swift"
    "AppleSignInResult.swift"
    "KomalColors.swift"
    "GradientBackground.swift"
    "SocialSignInButton.swift"
    "PillButtonStyle.swift"
    "SplashScreenView.swift"
    "OnboardingView.swift"
    "RootView.swift"
    "SettingsView.swift"
    "ContentCategory.swift"
    "ScanResponse.swift"
    "KomalInterventionTrigger.swift"
    "ContentSafetyTextClassifier.swift"
)

# Create archive folder with timestamp
ARCHIVE_DIR=".duplicates/auto-fix-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$ARCHIVE_DIR"

echo "📂 Archive folder: $ARCHIVE_DIR"
echo ""

# Strategy: Keep files in organized subdirectories, move root-level duplicates
MOVED_COUNT=0
KEPT_COUNT=0

for filename in "${AUTO_CREATED[@]}"; do
    # Find all instances
    instances=$(find Sources -name "$filename" -type f 2>/dev/null || echo "")
    
    if [ -z "$instances" ]; then
        continue
    fi
    
    count=$(echo "$instances" | wc -l | tr -d ' ')
    
    if [ "$count" -gt 1 ]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "⚠️  $filename (found $count instances)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # Priority: Keep files in deeper subdirectories (more organized)
        # Move files in root or Models/ to archive
        
        while IFS= read -r filepath; do
            # Check if file is in root level or Models/
            if [[ "$filepath" =~ Sources/Komalios/[^/]+\.swift$ ]] || \
               [[ "$filepath" =~ Sources/Komalios/Models/[^/]+\.swift$ ]]; then
                echo "  🗑️  MOVE: $filepath"
                mkdir -p "$ARCHIVE_DIR/$(dirname "$filepath")"
                mv "$filepath" "$ARCHIVE_DIR/$filepath"
                ((MOVED_COUNT++))
            else
                echo "  ✅ KEEP: $filepath (organized in subdirectory)"
                ((KEPT_COUNT++))
            fi
        done <<< "$instances"
        
        echo ""
    else
        echo "✅ $filename (no duplicates)"
    fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Moved to archive: $MOVED_COUNT files"
echo "  Kept in place: $KEPT_COUNT files"
echo ""

if [ "$MOVED_COUNT" -gt 0 ]; then
    echo "📁 Archived files location:"
    echo "   $ARCHIVE_DIR"
    echo ""
    echo "💡 TIP: Review archived files before deleting"
    echo "   Some may have content not present in existing files"
    echo ""
fi

echo "🧹 Cleaning build artifacts..."
rm -rf .build Package.resolved build DerivedData

echo ""
echo "✅ FIX COMPLETE!"
echo ""
echo "🔄 Next steps:"
echo "   1. Review moved files in: $ARCHIVE_DIR"
echo "   2. Run: swift build"
echo "   3. If build succeeds, you can delete: $ARCHIVE_DIR"
echo ""
