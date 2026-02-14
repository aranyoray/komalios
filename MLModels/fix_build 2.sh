#!/bin/bash

echo "🔧 Komalios Build Fixer"
echo "======================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Clean build artifacts
echo "🧹 Step 1: Cleaning build artifacts..."
rm -rf .build
rm -rf build
rm -rf DerivedData
rm -f Package.resolved
rm -rf ~/Library/Developer/Xcode/DerivedData/*
echo "${GREEN}✅ Cleaned${NC}"
echo ""

# Step 2: Resolve packages
echo "📦 Step 2: Resolving Swift packages..."
if swift package resolve; then
    echo "${GREEN}✅ Packages resolved${NC}"
else
    echo "${RED}❌ Package resolution failed${NC}"
    echo "Try running: swift package update"
    exit 1
fi
echo ""

# Step 3: Update packages (optional)
echo "🔄 Step 3: Updating packages..."
swift package update
echo "${GREEN}✅ Packages updated${NC}"
echo ""

# Step 4: Check for required files
echo "📁 Step 4: Checking required files..."

required_files=(
    "KomaliosApp.swift"
    "AppDelegate.swift"
    "Models_Masterlist_Fixed.csv"
    "Package.swift"
)

all_found=true
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "${GREEN}✅${NC} Found: $file"
    else
        echo "${RED}❌${NC} Missing: $file"
        all_found=false
    fi
done
echo ""

if [ "$all_found" = false ]; then
    echo "${YELLOW}⚠️  Some required files are missing${NC}"
fi

# Step 5: Check for GoogleService-Info.plist
echo "🔍 Step 5: Checking Firebase configuration..."
if [ -f "GoogleService-Info.plist" ]; then
    echo "${GREEN}✅${NC} GoogleService-Info.plist found"
else
    echo "${YELLOW}⚠️${NC}  GoogleService-Info.plist not found"
    echo "   Download from: https://console.firebase.google.com/"
fi
echo ""

# Step 6: Try building
echo "🔨 Step 6: Attempting build..."
if swift build; then
    echo ""
    echo "${GREEN}✅✅✅ BUILD SUCCESSFUL! ✅✅✅${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Open your project in Xcode"
    echo "2. Clean build folder (⇧⌘K)"
    echo "3. Build (⌘B)"
    echo "4. Run on simulator (⌘R)"
else
    echo ""
    echo "${RED}❌ Build failed${NC}"
    echo ""
    echo "Common fixes:"
    echo "1. Open Xcode → File → Packages → Reset Package Caches"
    echo "2. Clean build (⇧⌘K)"
    echo "3. Quit Xcode and reopen"
    echo "4. Make sure you have Xcode 14+ installed"
    echo "5. Check that all Swift files are in the project root"
    echo ""
    echo "If you see 'module not found' errors:"
    echo "- Wait for Xcode to finish indexing"
    echo "- File → Packages → Resolve Package Versions"
    echo ""
fi

echo ""
echo "📊 Project structure:"
echo "===================="
find . -name "*.swift" -not -path "./.build/*" -not -path "./build/*" | head -20
echo ""

echo "🎯 Package dependencies:"
echo "========================"
swift package show-dependencies
echo ""

echo "✅ Done! Check the output above for any errors."
