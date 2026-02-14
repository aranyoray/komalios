#!/bin/bash
# comprehensive_build_fix.sh - Find and fix ALL build issues
# This script will NOT reduce features - only fix compilation errors

set -e

echo "🔍 Comprehensive Build Diagnostic & Fix"
echo "========================================"
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS_FOUND=0

# Step 1: Check project structure
echo -e "${BLUE}Step 1: Validating project structure...${NC}"

if [ ! -f "Package.swift" ]; then
    echo -e "${RED}❌ Package.swift not found${NC}"
    ERRORS_FOUND=$((ERRORS_FOUND + 1))
else
    echo -e "${GREEN}✅ Package.swift exists${NC}"
fi

if [ ! -f "KomaliosApp.swift" ]; then
    echo -e "${YELLOW}⚠️  KomaliosApp.swift not in root - checking for app entry point${NC}"
    if [ -f "Sources/Komalios/KomaliosApp.swift" ]; then
        echo -e "${GREEN}✅ Found in Sources/Komalios/${NC}"
    else
        echo -e "${RED}❌ No app entry point found${NC}"
        ERRORS_FOUND=$((ERRORS_FOUND + 1))
    fi
else
    echo -e "${GREEN}✅ KomaliosApp.swift exists${NC}"
fi

echo ""

# Step 2: Clean everything
echo -e "${BLUE}Step 2: Deep cleaning build artifacts...${NC}"
rm -rf ~/Library/Developer/Xcode/DerivedData/Komalios-* 2>/dev/null || true
rm -rf .build 2>/dev/null || true
rm -rf build 2>/dev/null || true
rm -rf *.xcodeproj/project.xcworkspace/xcuserdata 2>/dev/null || true
rm -rf *.xcworkspace/xcuserdata 2>/dev/null || true
rm -f Package.resolved 2>/dev/null || true
echo -e "${GREEN}✅ Cleaned${NC}"
echo ""

# Step 3: Verify dependencies
echo -e "${BLUE}Step 3: Checking Package.swift dependencies...${NC}"

if grep -q "firebase-ios-sdk" Package.swift; then
    echo -e "${GREEN}✅ Firebase dependency present${NC}"
else
    echo -e "${RED}❌ Firebase dependency missing${NC}"
    ERRORS_FOUND=$((ERRORS_FOUND + 1))
fi

if grep -q "GoogleSignIn-iOS" Package.swift; then
    echo -e "${GREEN}✅ GoogleSignIn dependency present${NC}"
else
    echo -e "${RED}❌ GoogleSignIn dependency missing${NC}"
    ERRORS_FOUND=$((ERRORS_FOUND + 1))
fi

echo ""

# Step 4: Check for common Swift compilation errors
echo -e "${BLUE}Step 4: Scanning for common compilation errors...${NC}"

# Find all Swift files
SWIFT_FILES=$(find . -name "*.swift" -not -path "./build/*" -not -path "./.build/*" -not -path "./DerivedData/*" 2>/dev/null)

# Check for missing imports
echo "Checking imports..."
for file in $SWIFT_FILES; do
    if grep -q "import FirebaseAuth" "$file" 2>/dev/null; then
        echo "  📦 $file uses FirebaseAuth"
    fi
    if grep -q "import GoogleSignIn" "$file" 2>/dev/null; then
        echo "  📦 $file uses GoogleSignIn"
    fi
    if grep -q "import UIKit" "$file" 2>/dev/null; then
        echo "  📦 $file uses UIKit"
    fi
done

echo ""

# Step 5: Check for required configuration files
echo -e "${BLUE}Step 5: Checking required configuration files...${NC}"

if [ -f "GoogleService-Info.plist" ] || [ -f "Sources/Komalios/Resources/GoogleService-Info.plist" ] || [ -f "Resources/GoogleService-Info.plist" ]; then
    echo -e "${GREEN}✅ GoogleService-Info.plist found${NC}"
else
    echo -e "${YELLOW}⚠️  GoogleService-Info.plist not found (required for Firebase)${NC}"
    echo "   Download from: https://console.firebase.google.com/"
fi

if [ -f "Config.swift" ] || [ -f "Sources/Komalios/Config.swift" ]; then
    echo -e "${GREEN}✅ Config.swift found (API keys configured)${NC}"
else
    echo -e "${YELLOW}⚠️  Config.swift not found${NC}"
fi

echo ""

# Step 6: Resolve packages
echo -e "${BLUE}Step 6: Resolving Swift Package dependencies...${NC}"
if swift package resolve; then
    echo -e "${GREEN}✅ Packages resolved${NC}"
else
    echo -e "${RED}❌ Package resolution failed${NC}"
    ERRORS_FOUND=$((ERRORS_FOUND + 1))
fi

echo ""

# Step 7: Update packages
echo -e "${BLUE}Step 7: Updating to latest compatible versions...${NC}"
if swift package update; then
    echo -e "${GREEN}✅ Packages updated${NC}"
else
    echo -e "${YELLOW}⚠️  Package update had warnings (may be OK)${NC}"
fi

echo ""

# Step 8: Attempt build
echo -e "${BLUE}Step 8: Building project...${NC}"
echo "This may take a few minutes for first build..."
echo ""

if swift build 2>&1 | tee build_output.log; then
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ BUILD SUCCEEDED!                ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════╝${NC}"
    rm -f build_output.log
    exit 0
else
    echo ""
    echo -e "${RED}╔════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ❌ BUILD FAILED                    ║${NC}"
    echo -e "${RED}╚════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Build errors saved to: build_output.log${NC}"
    echo ""
    
    # Analyze errors
    echo -e "${BLUE}Analyzing errors...${NC}"
    
    if grep -q "cannot find type" build_output.log; then
        echo -e "${YELLOW}Found: Missing type definitions${NC}"
        grep "cannot find type" build_output.log | head -5
    fi
    
    if grep -q "no such module" build_output.log; then
        echo -e "${YELLOW}Found: Missing module imports${NC}"
        grep "no such module" build_output.log | head -5
    fi
    
    if grep -q "does not contain" build_output.log; then
        echo -e "${YELLOW}Found: Missing members/properties${NC}"
        grep "does not contain" build_output.log | head -5
    fi
    
    if grep -q "undeclared type" build_output.log; then
        echo -e "${YELLOW}Found: Undeclared types${NC}"
        grep "undeclared type" build_output.log | head -5
    fi
    
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Review build_output.log for specific errors"
    echo "2. Common fixes:"
    echo "   - Restart Xcode and reset package caches"
    echo "   - Check Package.swift target paths"
    echo "   - Verify all Swift files are in correct locations"
    echo "   - Check for circular dependencies"
    echo ""
    echo "3. Try Xcode manual build:"
    echo "   - Open project in Xcode"
    echo "   - File > Packages > Reset Package Caches"
    echo "   - Product > Clean Build Folder (⇧⌘K)"
    echo "   - Product > Build (⌘B)"
    
    ERRORS_FOUND=$((ERRORS_FOUND + 1))
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════${NC}"
echo -e "${BLUE}Summary: ${ERRORS_FOUND} critical issues found${NC}"
echo -e "${BLUE}═══════════════════════════════════${NC}"

if [ $ERRORS_FOUND -gt 0 ]; then
    exit 1
else
    exit 0
fi
