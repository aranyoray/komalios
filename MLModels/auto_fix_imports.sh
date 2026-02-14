#!/bin/bash
# auto_fix_imports.sh - Automatically fix common import and dependency issues

echo "🔧 Automatic Import & Dependency Fixer"
echo "======================================"
echo ""

# Find all Swift files with import errors
echo "Scanning for import issues..."

# Create a temporary fix log
FIX_LOG="auto_fix.log"
> "$FIX_LOG"

FIXES_APPLIED=0

# Function to ensure proper imports
fix_imports() {
    local file="$1"
    local temp_file="${file}.tmp"
    local fixed=false
    
    # Check if file needs Foundation
    if ! grep -q "^import Foundation" "$file" && grep -q "String\|Int\|Array\|Dictionary\|Date\|URL" "$file"; then
        echo "import Foundation" > "$temp_file"
        cat "$file" >> "$temp_file"
        mv "$temp_file" "$file"
        echo "✅ Added Foundation import to $file" | tee -a "$FIX_LOG"
        fixed=true
        FIXES_APPLIED=$((FIXES_APPLIED + 1))
    fi
    
    # Check if file needs UIKit for iOS-specific code
    if ! grep -q "^import UIKit" "$file" && grep -q "UIApplication\|UIViewController\|UIView\|UIWindow" "$file"; then
        # Add after Foundation or at top
        if grep -q "^import Foundation" "$file"; then
            sed -i '' '/^import Foundation/a\
import UIKit
' "$file"
        else
            echo "import UIKit" | cat - "$file" > "$temp_file"
            mv "$temp_file" "$file"
        fi
        echo "✅ Added UIKit import to $file" | tee -a "$FIX_LOG"
        fixed=true
        FIXES_APPLIED=$((FIXES_APPLIED + 1))
    fi
    
    # Add platform check for UIKit
    if grep -q "^import UIKit" "$file" && ! grep -q "#if canImport(UIKit)" "$file"; then
        # Wrap UIKit import in platform check
        sed -i '' 's/^import UIKit$/#if canImport(UIKit)\
import UIKit\
#endif/' "$file"
        echo "✅ Added platform check to UIKit import in $file" | tee -a "$FIX_LOG"
        fixed=true
        FIXES_APPLIED=$((FIXES_APPLIED + 1))
    fi
    
    return 0
}

# Find and fix all Swift files
SWIFT_FILES=$(find . -name "*.swift" \
    -not -path "./build/*" \
    -not -path "./.build/*" \
    -not -path "./DerivedData/*" \
    -not -path "./Pods/*" \
    -not -path "./Package.swift" \
    2>/dev/null)

for file in $SWIFT_FILES; do
    fix_imports "$file"
done

echo ""
echo "═══════════════════════════════════"
echo "Fixes applied: $FIXES_APPLIED"
echo "═══════════════════════════════════"
echo ""

if [ $FIXES_APPLIED -gt 0 ]; then
    echo "✅ Auto-fixes applied. Review changes:"
    echo "   cat $FIX_LOG"
    echo ""
    echo "Next: Run comprehensive_build_fix.sh"
else
    echo "No automatic fixes needed."
    echo "If build still fails, check Package.swift dependencies."
fi

exit 0
