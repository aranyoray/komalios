#!/bin/bash
# fix_build.sh - Automated fix for module dependency errors
# Run this script to resolve Firebase/GoogleSignIn import errors

set -e  # Exit on error

echo "🔧 Komalios Build Fix Script"
echo "============================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Clean derived data
echo -e "${YELLOW}Step 1: Cleaning Xcode derived data...${NC}"
rm -rf ~/Library/Developer/Xcode/DerivedData/Komalios-*
rm -rf .build
rm -rf *.xcodeproj/project.xcworkspace/xcuserdata
echo -e "${GREEN}✅ Cleaned${NC}"
echo ""

# Step 2: Verify Package.swift
echo -e "${YELLOW}Step 2: Checking Package.swift...${NC}"
if [ -f "Package.swift" ]; then
    if grep -q "firebase-ios-sdk" Package.swift && grep -q "GoogleSignIn-iOS" Package.swift; then
        echo -e "${GREEN}✅ Package.swift has Firebase and GoogleSignIn dependencies${NC}"
    else
        echo -e "${RED}❌ Package.swift missing dependencies${NC}"
        echo "Please ensure Package.swift includes:"
        echo "  - firebase-ios-sdk"
        echo "  - GoogleSignIn-iOS"
        exit 1
    fi
else
    echo -e "${RED}❌ Package.swift not found${NC}"
    exit 1
fi
echo ""

# Step 3: Resolve packages
echo -e "${YELLOW}Step 3: Resolving Swift packages...${NC}"
swift package resolve
echo -e "${GREEN}✅ Packages resolved${NC}"
echo ""

# Step 4: Update packages
echo -e "${YELLOW}Step 4: Updating packages to latest compatible versions...${NC}"
swift package update
echo -e "${GREEN}✅ Packages updated${NC}"
echo ""

# Step 5: Check for GoogleService-Info.plist
echo -e "${YELLOW}Step 5: Checking Firebase configuration...${NC}"
if [ -f "GoogleService-Info.plist" ] || [ -f "Sources/Komalios/Resources/GoogleService-Info.plist" ]; then
    echo -e "${GREEN}✅ GoogleService-Info.plist found${NC}"
else
    echo -e "${YELLOW}⚠️  GoogleService-Info.plist not found${NC}"
    echo "Download from: https://console.firebase.google.com/"
    echo "Place in project root or Sources/Komalios/Resources/"
fi
echo ""

# Step 6: Check Config.swift
echo -e "${YELLOW}Step 6: Checking API keys configuration...${NC}"
if [ -f "Config.swift" ] || [ -f "Sources/Komalios/Config.swift" ]; then
    echo -e "${GREEN}✅ Config.swift found${NC}"
else
    echo -e "${YELLOW}⚠️  Config.swift not found${NC}"
fi
echo ""

# Step 7: Build
echo -e "${YELLOW}Step 7: Building project...${NC}"
swift build
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Build succeeded!${NC}"
else
    echo -e "${RED}❌ Build failed${NC}"
    echo ""
    echo "If build still fails, try these steps in Xcode:"
    echo "1. Quit Xcode completely"
    echo "2. Reopen project"
    echo "3. File > Packages > Reset Package Caches"
    echo "4. Product > Clean Build Folder (⇧⌘K)"
    echo "5. Product > Build (⌘B)"
    exit 1
fi
echo ""

# Success
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ Build fix completed successfully! ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo "Next steps:"
echo "1. Open project in Xcode"
echo "2. Build and run (⌘R)"
echo "3. Check console for: '✓ Google Cloud API Key: ✅ Set'"
echo ""
echo "If errors persist, see BUILD_FIX_GUIDE.md for detailed troubleshooting."
