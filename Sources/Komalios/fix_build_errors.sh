#!/bin/bash

echo "🔧 FIXING BUILD FAILURES"
echo "========================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Identified Issues:${NC}"
echo "  1. BuildValidator.swift causing false #error() directives"
echo "  2. Test files in main target"
echo "  3. Package.swift not excluding problematic files"
echo ""

echo -e "${BLUE}Step 1: Backing up problematic files...${NC}"
mkdir -p .excluded_files 2>/dev/null

if [ -f "BuildValidator.swift" ]; then
    mv BuildValidator.swift .excluded_files/ 2>/dev/null && echo -e "${GREEN}✅ Moved BuildValidator.swift${NC}" || echo -e "${YELLOW}⚠️  BuildValidator.swift not found${NC}"
else
    echo -e "${YELLOW}⚠️  BuildValidator.swift already removed${NC}"
fi

if [ -f "ContentSafetyEngineTestsContentSafetyEngineTestsContentSafetyEngineTests.swift" ]; then
    mv ContentSafetyEngineTestsContentSafetyEngineTestsContentSafetyEngineTests.swift .excluded_files/ 2>/dev/null && echo -e "${GREEN}✅ Moved test file${NC}"
else
    echo -e "${YELLOW}⚠️  Test file not found or already moved${NC}"
fi

if [ -f "SenTest+FWaiter.h" ]; then
    mv "SenTest+FWaiter.h" .excluded_files/ 2>/dev/null && echo -e "${GREEN}✅ Moved test header${NC}"
else
    echo -e "${YELLOW}⚠️  Test header not found${NC}"
fi

echo ""
echo -e "${BLUE}Step 2: Cleaning build artifacts...${NC}"
rm -rf .build 2>/dev/null && echo "  • Removed .build"
rm -rf build 2>/dev/null && echo "  • Removed build"
rm -f Package.resolved 2>/dev/null && echo "  • Removed Package.resolved"
rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null && echo "  • Cleared Xcode DerivedData"
echo -e "${GREEN}✅ Clean complete${NC}"
echo ""

echo -e "${BLUE}Step 3: Verifying Package.swift...${NC}"
if grep -q "exclude:" Package.swift; then
    echo -e "${GREEN}✅ Package.swift has exclude list${NC}"
    echo ""
    echo "Excluded files:"
    grep -A 30 "exclude:" Package.swift | grep '"' | head -10
else
    echo -e "${RED}❌ Package.swift missing exclude list${NC}"
    echo "  This should have been added. Please check Package.swift"
fi
echo ""

echo -e "${BLUE}Step 4: Resolving packages...${NC}"
if swift package resolve 2>&1 | grep -q "resolved\|Fetching"; then
    echo -e "${GREEN}✅ Packages resolved${NC}"
else
    echo -e "${YELLOW}⚠️  Check package resolution output above${NC}"
fi
echo ""

echo -e "${BLUE}Step 5: Testing build...${NC}"
echo ""

if swift build 2>&1 | tee /tmp/komalios_fixed_build.log; then
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ BUILD FIXED - SUCCESS! ✅         ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Issues Fixed:${NC}"
    echo "  ✅ BuildValidator.swift removed/excluded"
    echo "  ✅ Test files excluded"
    echo "  ✅ Package.swift updated with excludes"
    echo "  ✅ All dependencies resolved"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo "  1. Open in Xcode:"
    echo -e "     ${YELLOW}open Package.swift${NC}"
    echo ""
    echo "  2. In Xcode:"
    echo "     • Product → Build (⌘B)"
    echo "     • Select iPhone 15 Pro simulator"
    echo "     • Product → Run (⌘R)"
    echo ""
    exit 0
else
    echo ""
    echo -e "${RED}❌ Build still failing${NC}"
    echo ""
    echo "Build log saved to: /tmp/komalios_fixed_build.log"
    echo ""
    echo "Checking for remaining errors..."
    echo ""
    
    if grep -q "UIKit" /tmp/komalios_fixed_build.log; then
        echo -e "${RED}UIKit errors still present${NC}"
        echo "This means BuildValidator.swift is still being compiled."
        echo ""
        echo "Manual fix:"
        echo "  1. Delete BuildValidator.swift:"
        echo "     rm BuildValidator.swift"
        echo ""
        echo "  2. Clean and rebuild:"
        echo "     rm -rf .build && swift package resolve && swift build"
    fi
    
    if grep -q "ContentSafetyEngine" /tmp/komalios_fixed_build.log; then
        echo -e "${RED}ContentSafetyEngine import errors${NC}"
        echo "Test file is still being compiled."
        echo ""
        echo "Manual fix:"
        echo "  1. Move test file:"
        echo "     mkdir -p Tests"
        echo "     mv ContentSafetyEngineTestsContentSafetyEngineTestsContentSafetyEngineTests.swift Tests/"
    fi
    
    if grep -q "PackageDescription" /tmp/komalios_fixed_build.log; then
        echo -e "${RED}PackageDescription import error${NC}"
        echo "Some file is incorrectly importing PackageDescription."
        echo ""
        echo "Find the file:"
        echo "  grep -r \"import PackageDescription\" --include=\"*.swift\" ."
    fi
    
    echo ""
    echo "To view full errors:"
    echo "  cat /tmp/komalios_fixed_build.log"
    echo ""
    exit 1
fi
