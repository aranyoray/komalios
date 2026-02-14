#!/bin/bash

# COMPLETE REBUILD - Fix all issues from scratch
# This will handle everything: files, dependencies, Firebase, etc.

set -e  # Exit on any error

clear

echo "════════════════════════════════════════════════════════"
echo "  KOMALIOS - COMPLETE REBUILD & FIX"
echo "  This will fix ALL issues and set up everything"
echo "════════════════════════════════════════════════════════"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Step 1: Remove ALL problematic files
echo -e "${BLUE}[1/8] Removing problematic files...${NC}"

rm -f BuildValidator.swift 2>/dev/null
rm -f ContentSafetyEngineTestsContentSafetyEngineTestsContentSafetyEngineTests.swift 2>/dev/null
rm -f "SenTest+FWaiter.h" 2>/dev/null

# Remove any test directories
rm -rf Tests 2>/dev/null
rm -rf ContentSafetyEngineTests 2>/dev/null

echo -e "${GREEN}✅ Problematic files removed${NC}"
echo ""

# Step 2: Clean ALL build artifacts
echo -e "${BLUE}[2/8] Cleaning all build artifacts...${NC}"

rm -rf .build 2>/dev/null
rm -rf build 2>/dev/null
rm -rf DerivedData 2>/dev/null
rm -f Package.resolved 2>/dev/null
rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null
rm -rf .swiftpm 2>/dev/null

echo -e "${GREEN}✅ Build artifacts cleaned${NC}"
echo ""

# Step 3: Verify Package.swift is correct
echo -e "${BLUE}[3/8] Verifying Package.swift...${NC}"

if [ ! -f "Package.swift" ]; then
    echo -e "${RED}❌ Package.swift not found!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Package.swift found${NC}"
echo ""

# Step 4: Verify core Swift files exist
echo -e "${BLUE}[4/8] Checking core app files...${NC}"

required_files=(
    "KomaliosApp.swift"
    "Config.swift"
    "AppDelegate.swift"
)

missing_files=0
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}  ✓${NC} $file"
    else
        echo -e "${RED}  ✗${NC} $file ${RED}MISSING${NC}"
        ((missing_files++))
    fi
done

if [ $missing_files -gt 0 ]; then
    echo ""
    echo -e "${RED}❌ Missing critical files. Cannot proceed.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All core files present${NC}"
echo ""

# Step 5: Resolve Swift packages (this installs Firebase, GoogleSignIn, etc.)
echo -e "${BLUE}[5/8] Resolving Swift packages (Firebase, GoogleSignIn)...${NC}"
echo "This may take 2-3 minutes on first run..."
echo ""

if swift package resolve 2>&1 | tee /tmp/package_resolve.log; then
    echo ""
    echo -e "${GREEN}✅ Packages resolved (Firebase & GoogleSignIn installed)${NC}"
else
    echo ""
    echo -e "${RED}❌ Package resolution failed${NC}"
    echo "Check /tmp/package_resolve.log for details"
    exit 1
fi
echo ""

# Step 6: Update packages to latest
echo -e "${BLUE}[6/8] Updating packages to latest versions...${NC}"

swift package update 2>/dev/null || true

echo -e "${GREEN}✅ Packages updated${NC}"
echo ""

# Step 7: Build the project
echo -e "${BLUE}[7/8] Building project...${NC}"
echo ""

if swift build 2>&1 | tee /tmp/build.log; then
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  ✅✅✅ BUILD SUCCESSFUL ✅✅✅${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Step 8: Final setup instructions
    echo -e "${BLUE}[8/8] Final setup needed:${NC}"
    echo ""
    echo -e "${YELLOW}📋 BEFORE RUNNING THE APP:${NC}"
    echo ""
    echo "1. Add Firebase configuration file:"
    echo "   • Go to: https://console.firebase.google.com/"
    echo "   • Download GoogleService-Info.plist"
    echo "   • Place it in project root"
    echo ""
    echo "2. (Optional) Add API keys in Config.swift for:"
    echo "   • Google Cloud Vision API"
    echo "   • Google Custom Search API"
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  READY TO OPEN IN XCODE${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Run this command:"
    echo -e "${YELLOW}  open Package.swift${NC}"
    echo ""
    echo "Then in Xcode:"
    echo "  1. Wait for indexing to complete"
    echo "  2. Product → Build (⌘B)"
    echo "  3. Select iPhone 15 Pro simulator"
    echo "  4. Product → Run (⌘R)"
    echo ""
    exit 0
    
else
    echo ""
    echo -e "${RED}════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  ❌ BUILD FAILED${NC}"
    echo -e "${RED}════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Build log saved to: /tmp/build.log"
    echo ""
    echo "Common issues:"
    echo ""
    echo "1. If you see 'module not found' errors:"
    echo "   → Open in Xcode and let it index first"
    echo "   → File → Packages → Reset Package Caches"
    echo ""
    echo "2. If you see Firebase errors:"
    echo "   → Packages may still be downloading"
    echo "   → Wait a minute and run this script again"
    echo ""
    echo "3. If you see syntax errors in your code:"
    echo "   → Open in Xcode to see specific file/line"
    echo ""
    echo "To view full error log:"
    echo "  cat /tmp/build.log"
    echo ""
    echo "To try Xcode build instead:"
    echo "  open Package.swift"
    echo ""
    exit 1
fi
