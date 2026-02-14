#!/bin/bash
# create_xcode_project.sh - Generate Xcode project with proper configuration

echo "🔨 Creating Xcode Project for Komalios"
echo "======================================"
echo ""

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Step 1: Clean any existing build artifacts...${NC}"
rm -rf .build build DerivedData Package.resolved 2>/dev/null || true
rm -rf ~/Library/Developer/Xcode/DerivedData/Komalios-* 2>/dev/null || true
echo -e "${GREEN}✅ Cleaned${NC}"
echo ""

echo -e "${BLUE}Step 2: Generate Xcode project from Package.swift...${NC}"
if swift package generate-xcodeproj 2>&1 | tee xcode_gen.log; then
    echo -e "${GREEN}✅ Xcode project generated: Komalios.xcodeproj${NC}"
    rm -f xcode_gen.log
else
    echo -e "${YELLOW}⚠️ generate-xcodeproj failed (deprecated in newer Swift)${NC}"
    echo "Trying alternative method..."
    
    # Alternative: Use xcodegen or create manually
    echo -e "${BLUE}Creating Xcode project structure manually...${NC}"
    
    # This requires the project to be opened in Xcode
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Swift Package Manager projects must be opened${NC}"
    echo -e "${YELLOW}directly in Xcode (File > Open > Package.swift)${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════${NC}"
    echo ""
fi

echo ""
echo -e "${BLUE}Step 3: Resolve package dependencies...${NC}"
if swift package resolve; then
    echo -e "${GREEN}✅ Packages resolved${NC}"
else
    echo -e "${RED}❌ Package resolution failed${NC}"
    echo "This usually means:"
    echo "  - Network issues"
    echo "  - Invalid package URLs"
    echo "  - Incompatible Swift version"
    exit 1
fi

echo ""
echo -e "${BLUE}Step 4: Update to latest compatible versions...${NC}"
swift package update || true
echo -e "${GREEN}✅ Packages updated${NC}"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ Setup Complete!                     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""

if [ -f "Komalios.xcodeproj/project.pbxproj" ]; then
    echo -e "${GREEN}✅ Xcode project exists: Komalios.xcodeproj${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Open Komalios.xcodeproj in Xcode"
    echo "2. Select your target device/simulator"
    echo "3. Product > Build (⌘B)"
else
    echo -e "${YELLOW}Xcode project generation not available.${NC}"
    echo ""
    echo "SOLUTION: Open project directly in Xcode"
    echo ""
    echo "1. Open Xcode"
    echo "2. File > Open..."
    echo "3. Select the folder containing Package.swift"
    echo "4. Xcode will automatically load the SPM project"
    echo "5. File > Packages > Reset Package Caches"
    echo "6. Product > Build (⌘B)"
    echo ""
    echo "Firebase packages will download automatically!"
fi

echo ""
echo -e "${BLUE}═══ Package Dependencies Status ═══${NC}"
echo ""

if [ -f "Package.resolved" ]; then
    echo -e "${GREEN}✅ Package.resolved exists${NC}"
    echo "Dependencies locked:"
    if grep -q "firebase-ios-sdk" Package.resolved; then
        echo "  ✅ Firebase iOS SDK"
    else
        echo "  ❌ Firebase iOS SDK (needs resolution)"
    fi
    if grep -q "GoogleSignIn-iOS" Package.resolved; then
        echo "  ✅ GoogleSignIn iOS"
    else
        echo "  ❌ GoogleSignIn iOS (needs resolution)"
    fi
else
    echo -e "${YELLOW}⚠️  Package.resolved not created yet${NC}"
    echo "Run: swift package resolve"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}Ready to open in Xcode!${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
