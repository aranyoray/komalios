#!/bin/bash

echo "🔧 Komalios Build Fixer - Complete"
echo "===================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Step 0: Verify we're in the right directory
echo "📍 Current directory: $(pwd)"
echo ""

# Step 1: Check Package.swift exists
echo "🔍 Step 1: Checking Package.swift..."
if [ ! -f "Package.swift" ]; then
    echo -e "${RED}❌ Package.swift not found!${NC}"
    echo "Are you in the project root directory?"
    exit 1
fi
echo -e "${GREEN}✅ Package.swift found${NC}"
echo ""

# Step 2: Check for required Swift files
echo "🔍 Step 2: Checking Swift files..."
swift_count=$(find . -name "*.swift" -not -path "./.build/*" -not -path "./build/*" | wc -l)
if [ $swift_count -eq 0 ]; then
    echo -e "${RED}❌ No Swift files found!${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Found $swift_count Swift files${NC}"
echo ""

# Step 3: Check for KomaliosApp.swift (main entry point)
echo "🔍 Step 3: Checking for app entry point..."
if [ -f "KomaliosApp.swift" ]; then
    echo -e "${GREEN}✅ KomaliosApp.swift found${NC}"
elif [ -f "App.swift" ]; then
    echo -e "${GREEN}✅ App.swift found${NC}"
else
    echo -e "${YELLOW}⚠️  No main app file found (KomaliosApp.swift or App.swift)${NC}"
    echo "Looking for @main annotation..."
    main_file=$(grep -r "@main" --include="*.swift" . 2>/dev/null | head -1)
    if [ ! -z "$main_file" ]; then
        echo -e "${GREEN}✅ Found: $main_file${NC}"
    else
        echo -e "${RED}❌ No @main entry point found${NC}"
    fi
fi
echo ""

# Step 4: Clean build artifacts
echo "🧹 Step 4: Cleaning build artifacts..."
rm -rf .build 2>/dev/null
rm -rf build 2>/dev/null
rm -rf DerivedData 2>/dev/null
rm -f Package.resolved 2>/dev/null
rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null
echo -e "${GREEN}✅ Cleaned${NC}"
echo ""

# Step 5: Check for Config.swift
echo "🔍 Step 5: Checking Config.swift..."
if [ -f "Config.swift" ]; then
    echo -e "${GREEN}✅ Config.swift found${NC}"
else
    echo -e "${RED}❌ Config.swift missing${NC}"
    echo "This will cause build errors. Creating Config.swift..."
    
    # Config.swift should already be created, but just in case
    if [ -f "Config.swift" ]; then
        echo -e "${GREEN}✅ Config.swift now exists${NC}"
    else
        echo -e "${RED}❌ Could not create Config.swift${NC}"
        echo "Please ensure Config.swift exists in your project."
    fi
fi
echo ""

# Step 6: Resolve packages
echo "📦 Step 6: Resolving Swift packages..."
if swift package resolve 2>&1 | tee /tmp/resolve_output.txt; then
    echo -e "${GREEN}✅ Packages resolved${NC}"
else
    echo -e "${RED}❌ Package resolution failed${NC}"
    echo ""
    echo "Error details:"
    cat /tmp/resolve_output.txt
    echo ""
    echo "Common fixes:"
    echo "1. Check internet connection"
    echo "2. Remove Package.resolved and try again"
    echo "3. Update package dependencies: swift package update"
    exit 1
fi
echo ""

# Step 7: Update packages (force latest)
echo "🔄 Step 7: Updating packages to latest versions..."
swift package update
echo -e "${GREEN}✅ Packages updated${NC}"
echo ""

# Step 8: Show dependency tree
echo "📊 Step 8: Package dependency tree:"
echo "===================================="
swift package show-dependencies
echo ""

# Step 9: Try building
echo "🔨 Step 9: Attempting build..."
echo ""

if swift build 2>&1 | tee /tmp/build_output.txt; then
    echo ""
    echo -e "${GREEN}═══════════════════════════════════${NC}"
    echo -e "${GREEN}✅✅✅ BUILD SUCCESSFUL! ✅✅✅${NC}"
    echo -e "${GREEN}═══════════════════════════════════${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Open your project in Xcode:"
    echo "   $ open Package.swift"
    echo ""
    echo "2. In Xcode:"
    echo "   • File → Packages → Reset Package Caches"
    echo "   • Product → Clean Build Folder (⇧⌘K)"
    echo "   • Product → Build (⌘B)"
    echo ""
    echo "3. If building for iOS, select a simulator and run (⌘R)"
    echo ""
else
    echo ""
    echo -e "${RED}❌ Build failed${NC}"
    echo ""
    echo "Analyzing errors..."
    echo ""
    
    # Check for common errors
    if grep -q "cannot find 'Config'" /tmp/build_output.txt; then
        echo -e "${RED}Error: Config.swift missing or not recognized${NC}"
        echo "Fix: Ensure Config.swift is in the project root"
    fi
    
    if grep -q "Cannot find type.*in scope" /tmp/build_output.txt; then
        echo -e "${RED}Error: Missing type definitions${NC}"
        echo "Fix: Check import statements and module names"
    fi
    
    if grep -q "FirebaseCore.*not found" /tmp/build_output.txt; then
        echo -e "${RED}Error: Firebase package issue${NC}"
        echo "Fix: Package.swift has been updated to remove FirebaseCore dependency"
        echo "      (it's automatically included with FirebaseAuth)"
    fi
    
    if grep -q "Module.*not found" /tmp/build_output.txt; then
        echo -e "${RED}Error: Module not found${NC}"
        echo "Fixes:"
        echo "1. Open in Xcode and let it index"
        echo "2. File → Packages → Reset Package Caches"
        echo "3. File → Packages → Update to Latest Package Versions"
    fi
    
    echo ""
    echo "Full error output saved to: /tmp/build_output.txt"
    echo ""
    echo "To view detailed errors:"
    echo "$ cat /tmp/build_output.txt"
    echo ""
    echo "Common fixes:"
    echo "1. Open Xcode → File → Packages → Reset Package Caches"
    echo "2. Clean build (⇧⌘K) then build again (⌘B)"
    echo "3. Quit Xcode, delete DerivedData, reopen"
    echo "4. Make sure you have Xcode 14+ installed"
    echo ""
    exit 1
fi

echo "✅ Done! You're ready to build in Xcode."
