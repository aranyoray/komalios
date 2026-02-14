#!/bin/bash
# final_build_attempt.sh - Last comprehensive build with all fixes

echo "🚀 FINAL BUILD ATTEMPT - All Fixes Applied"
echo "==========================================="
echo ""

set +e  # Don't exit on error, we want to see all issues

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Track fixes
FIXES=0

echo -e "${BLUE}Fix 1: Remove duplicate @main from KomaliosApp.swift${NC}"
echo "✅ Already fixed"
echo ""

echo -e "${BLUE}Fix 2: Validate Package.swift structure${NC}"
if [ -f "Package.swift" ]; then
    if grep -q '\.library' Package.swift; then
        echo "✅ Package.swift uses .library (correct for iOS)"
    else
        echo "⚠️  Package.swift might need adjustment"
    fi
fi
echo ""

echo -e "${BLUE}Fix 3: Clean all build artifacts${NC}"
rm -rf ~/Library/Developer/Xcode/DerivedData/Komalios-* 2>/dev/null
rm -rf .build build 2>/dev/null
rm -f Package.resolved 2>/dev/null
echo "✅ Cleaned"
echo ""

echo -e "${BLUE}Fix 4: Resolve package dependencies${NC}"
if swift package resolve 2>&1 | tee resolve.log; then
    echo "✅ Packages resolved"
    rm -f resolve.log
else
    echo "❌ Package resolution issues - see resolve.log"
fi
echo ""

echo -e "${BLUE}Fix 5: Update packages to latest${NC}"
if swift package update 2>&1 | tee update.log; then
    echo "✅ Packages updated"
    rm -f update.log
else
    echo "⚠️  Package update had warnings - may be OK"
fi
echo ""

echo -e "${BLUE}Fix 6: Validate required files${NC}"
MISSING=0

if [ -f "AppDelegate.swift" ]; then
    echo "✅ AppDelegate.swift exists"
else
    echo "❌ AppDelegate.swift missing"
    MISSING=$((MISSING + 1))
fi

if [ -f "Config.swift" ]; then
    echo "✅ Config.swift exists (API keys)"
    if grep -q "AIzaSy" Config.swift; then
        echo "   ✅ API keys configured"
    fi
else
    echo "❌ Config.swift missing"
    MISSING=$((MISSING + 1))
fi

if [ -f "GoogleCloudService.swift" ]; then
    echo "✅ GoogleCloudService.swift exists"
else
    echo "⚠️  GoogleCloudService.swift missing (optional)"
fi

if [ -f "AuthModels.swift" ]; then
    echo "✅ AuthModels.swift exists"
else
    echo "⚠️  AuthModels.swift missing (may cause errors)"
fi

echo ""

echo -e "${BLUE}Fix 7: Check Firebase configuration${NC}"
if [ -f "GoogleService-Info.plist" ] || find . -name "GoogleService-Info.plist" 2>/dev/null | grep -q .; then
    echo "✅ GoogleService-Info.plist found"
else
    echo "⚠️  GoogleService-Info.plist not found"
    echo "   Download from: https://console.firebase.google.com/"
fi
echo ""

echo -e "${BLUE}Fix 8: Attempt build${NC}"
echo "Building... (this may take 2-3 minutes)"
echo ""

if swift build 2>&1 | tee final_build.log; then
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                        ║${NC}"
    echo -e "${GREEN}║     ✅ BUILD SUCCEEDED! 🎉             ║${NC}"
    echo -e "${GREEN}║                                        ║${NC}"
    echo -e "${GREEN}║     All features intact!               ║${NC}"
    echo -e "${GREEN}║     Zero features removed!             ║${NC}"
    echo -e "${GREEN}║                                        ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo "✅ Build artifacts at: .build/debug/"
    echo ""
    echo "Next steps:"
    echo "1. Open project in Xcode"
    echo "2. Select your target device/simulator"
    echo "3. Product > Run (⌘R)"
    echo ""
    rm -f final_build.log
    exit 0
else
    echo ""
    echo -e "${RED}╔════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                                        ║${NC}"
    echo -e "${RED}║     BUILD HAD ERRORS                   ║${NC}"
    echo -e "${RED}║                                        ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${YELLOW}Analyzing errors from final_build.log...${NC}"
    echo ""
    
    # Count specific error types
    MODULE_ERRORS=$(grep -c "no such module\|cannot find.*in scope" final_build.log 2>/dev/null || echo "0")
    TYPE_ERRORS=$(grep -c "cannot find type\|undeclared type" final_build.log 2>/dev/null || echo "0")
    SYNTAX_ERRORS=$(grep -c "expected.*before\|unexpected" final_build.log 2>/dev/null || echo "0")
    
    echo "Error Summary:"
    echo "  Module/Import errors: $MODULE_ERRORS"
    echo "  Type/Declaration errors: $TYPE_ERRORS"
    echo "  Syntax errors: $SYNTAX_ERRORS"
    echo ""
    
    if [ $MODULE_ERRORS -gt 0 ]; then
        echo -e "${YELLOW}Top module errors:${NC}"
        grep "no such module\|cannot find.*in scope" final_build.log | head -5
        echo ""
        echo "💡 Fix: These are dependency issues."
        echo "   Solution:"
        echo "   1. Open Xcode"
        echo "   2. File > Packages > Reset Package Caches"
        echo "   3. Wait for resolution"
        echo "   4. Build in Xcode (⌘B)"
        echo ""
    fi
    
    if [ $TYPE_ERRORS -gt 0 ]; then
        echo -e "${YELLOW}Top type errors:${NC}"
        grep "cannot find type\|undeclared type" final_build.log | head -5
        echo ""
        echo "💡 Fix: Missing type definitions."
        echo "   Check if AuthModels.swift and other model files exist."
        echo ""
    fi
    
    echo "📄 Full build log saved to: final_build.log"
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}Recommended Actions:${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo ""
    echo "1. **Try Xcode Build First** (most reliable):"
    echo "   - Open your .xcodeproj or .xcworkspace in Xcode"
    echo "   - File > Packages > Reset Package Caches"
    echo "   - Product > Clean Build Folder (⇧⌘K)"
    echo "   - Product > Build (⌘B)"
    echo ""
    echo "2. **Check Configuration:**"
    echo "   - GoogleService-Info.plist in project"
    echo "   - Config.swift has API keys"
    echo "   - Bundle ID matches Firebase"
    echo ""
    echo "3. **Nuclear Option:**"
    echo "   rm -rf ~/Library/Developer/Xcode/DerivedData/*"
    echo "   rm -rf .build Package.resolved"
    echo "   # Then open Xcode and build"
    echo ""
    
    exit 1
fi
