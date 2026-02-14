#!/bin/bash

echo "╔════════════════════════════════════════════════════════╗"
echo "║     KOMALIOS - FINAL CHECKS & DEBUGGING               ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Check counters
passed=0
failed=0
warnings=0

echo -e "${BLUE}${BOLD}1. PROJECT STRUCTURE CHECK${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check Package.swift
if [ -f "Package.swift" ]; then
    echo -e "${GREEN}✅ Package.swift exists${NC}"
    ((passed++))
    
    # Validate content
    if grep -q "macOS(.v10_15)" Package.swift; then
        echo -e "${GREEN}✅ macOS platform version correct${NC}"
        ((passed++))
    else
        echo -e "${RED}❌ macOS platform version missing${NC}"
        ((failed++))
    fi
    
    if grep -q "FirebaseCore" Package.swift; then
        echo -e "${RED}❌ FirebaseCore still listed (should be removed)${NC}"
        ((failed++))
    else
        echo -e "${GREEN}✅ FirebaseCore not listed (correct)${NC}"
        ((passed++))
    fi
    
    if grep -q "exclude:" Package.swift; then
        echo -e "${YELLOW}⚠️  Exclude statement found (may cause issues)${NC}"
        ((warnings++))
    else
        echo -e "${GREEN}✅ No invalid excludes${NC}"
        ((passed++))
    fi
else
    echo -e "${RED}❌ Package.swift NOT FOUND${NC}"
    ((failed++))
    exit 1
fi
echo ""

echo -e "${BLUE}${BOLD}2. REQUIRED FILES CHECK${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check for main app entry
if [ -f "KomaliosApp.swift" ]; then
    echo -e "${GREEN}✅ KomaliosApp.swift exists${NC}"
    ((passed++))
    
    # Check for @main
    if grep -q "@main" KomaliosApp.swift; then
        echo -e "${GREEN}✅ @main annotation found${NC}"
        ((passed++))
    else
        echo -e "${RED}❌ @main annotation missing${NC}"
        ((failed++))
    fi
else
    echo -e "${RED}❌ KomaliosApp.swift NOT FOUND${NC}"
    ((failed++))
fi

# Check Config.swift
if [ -f "Config.swift" ]; then
    echo -e "${GREEN}✅ Config.swift exists${NC}"
    ((passed++))
    
    # Check for placeholder API keys
    if grep -q "YOUR_GOOGLE_CLOUD_API_KEY_HERE" Config.swift; then
        echo -e "${YELLOW}⚠️  API keys not configured (will work for build, not runtime)${NC}"
        ((warnings++))
    else
        echo -e "${GREEN}✅ API keys appear to be configured${NC}"
        ((passed++))
    fi
else
    echo -e "${RED}❌ Config.swift NOT FOUND${NC}"
    ((failed++))
fi

# Check AppDelegate
if [ -f "AppDelegate.swift" ]; then
    echo -e "${GREEN}✅ AppDelegate.swift exists${NC}"
    ((passed++))
    
    if grep -q "FirebaseApp.configure()" AppDelegate.swift; then
        echo -e "${GREEN}✅ Firebase initialization found${NC}"
        ((passed++))
    else
        echo -e "${YELLOW}⚠️  Firebase initialization may be missing${NC}"
        ((warnings++))
    fi
else
    echo -e "${YELLOW}⚠️  AppDelegate.swift not found (may be optional)${NC}"
    ((warnings++))
fi

# Check for Firebase plist
if [ -f "GoogleService-Info.plist" ]; then
    echo -e "${GREEN}✅ GoogleService-Info.plist exists${NC}"
    ((passed++))
else
    echo -e "${YELLOW}⚠️  GoogleService-Info.plist NOT FOUND${NC}"
    echo "   📝 Download from: https://console.firebase.google.com/"
    echo "   This is needed for Firebase to work at runtime."
    ((warnings++))
fi
echo ""

echo -e "${BLUE}${BOLD}3. SWIFT FILES CHECK${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

swift_count=$(find . -name "*.swift" -not -path "./.build/*" -not -path "./build/*" -not -path "./DerivedData/*" | wc -l | tr -d ' ')

if [ "$swift_count" -gt 0 ]; then
    echo -e "${GREEN}✅ Found $swift_count Swift files${NC}"
    ((passed++))
    
    echo ""
    echo "Key Swift files:"
    for file in KomaliosApp.swift AppDelegate.swift Config.swift ContentView.swift LoginView.swift; do
        if [ -f "$file" ]; then
            size=$(wc -c < "$file" | tr -d ' ')
            echo -e "   ${GREEN}✓${NC} $file (${size} bytes)"
        fi
    done
else
    echo -e "${RED}❌ No Swift files found${NC}"
    ((failed++))
fi
echo ""

echo -e "${BLUE}${BOLD}4. SYNTAX CHECK (Swift files)${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check key files for common syntax issues
syntax_errors=0

if [ -f "KomaliosApp.swift" ]; then
    # Check for unmatched braces
    open_braces=$(grep -o "{" KomaliosApp.swift | wc -l)
    close_braces=$(grep -o "}" KomaliosApp.swift | wc -l)
    
    if [ "$open_braces" -eq "$close_braces" ]; then
        echo -e "${GREEN}✅ KomaliosApp.swift - Braces balanced${NC}"
        ((passed++))
    else
        echo -e "${RED}❌ KomaliosApp.swift - Unmatched braces ($open_braces open, $close_braces close)${NC}"
        ((syntax_errors++))
        ((failed++))
    fi
fi

if [ -f "Config.swift" ]; then
    open_braces=$(grep -o "{" Config.swift | wc -l)
    close_braces=$(grep -o "}" Config.swift | wc -l)
    
    if [ "$open_braces" -eq "$close_braces" ]; then
        echo -e "${GREEN}✅ Config.swift - Braces balanced${NC}"
        ((passed++))
    else
        echo -e "${RED}❌ Config.swift - Unmatched braces${NC}"
        ((syntax_errors++))
        ((failed++))
    fi
fi

if [ "$syntax_errors" -eq 0 ]; then
    echo -e "${GREEN}✅ No obvious syntax errors detected${NC}"
    ((passed++))
fi
echo ""

echo -e "${BLUE}${BOLD}5. IMPORT STATEMENTS CHECK${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check for required imports
if [ -f "KomaliosApp.swift" ]; then
    imports_ok=true
    
    if grep -q "import SwiftUI" KomaliosApp.swift; then
        echo -e "${GREEN}✅ SwiftUI imported${NC}"
        ((passed++))
    else
        echo -e "${RED}❌ SwiftUI import missing${NC}"
        imports_ok=false
        ((failed++))
    fi
    
    if grep -q "import FirebaseAuth\|import FirebaseCore" KomaliosApp.swift; then
        echo -e "${GREEN}✅ Firebase imported${NC}"
        ((passed++))
    else
        echo -e "${YELLOW}⚠️  Firebase import may be missing${NC}"
        ((warnings++))
    fi
fi
echo ""

echo -e "${BLUE}${BOLD}6. BUILD ARTIFACTS CHECK${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check for stale build artifacts that could cause issues
if [ -d ".build" ]; then
    echo -e "${YELLOW}⚠️  .build directory exists (stale build artifacts)${NC}"
    echo "   💡 Recommend: rm -rf .build"
    ((warnings++))
else
    echo -e "${GREEN}✅ No .build directory (clean)${NC}"
    ((passed++))
fi

if [ -f "Package.resolved" ]; then
    echo -e "${YELLOW}⚠️  Package.resolved exists (may be outdated)${NC}"
    echo "   💡 Recommend: rm Package.resolved"
    ((warnings++))
else
    echo -e "${GREEN}✅ No Package.resolved (will resolve fresh)${NC}"
    ((passed++))
fi

if [ -d "~/Library/Developer/Xcode/DerivedData" ]; then
    derived_size=$(du -sh ~/Library/Developer/Xcode/DerivedData 2>/dev/null | cut -f1)
    if [ ! -z "$derived_size" ]; then
        echo -e "${YELLOW}⚠️  Xcode DerivedData exists ($derived_size)${NC}"
        echo "   💡 Recommend: rm -rf ~/Library/Developer/Xcode/DerivedData/*"
        ((warnings++))
    fi
fi
echo ""

echo -e "${BLUE}${BOLD}7. DEPENDENCIES CHECK${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Checking Package.swift dependencies..."

if grep -q "firebase-ios-sdk" Package.swift; then
    echo -e "${GREEN}✅ Firebase SDK declared${NC}"
    ((passed++))
else
    echo -e "${RED}❌ Firebase SDK missing${NC}"
    ((failed++))
fi

if grep -q "GoogleSignIn-iOS" Package.swift; then
    echo -e "${GREEN}✅ GoogleSignIn declared${NC}"
    ((passed++))
else
    echo -e "${RED}❌ GoogleSignIn missing${NC}"
    ((failed++))
fi
echo ""

echo -e "${BLUE}${BOLD}8. XCODE COMPATIBILITY CHECK${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v xcodebuild &> /dev/null; then
    xcode_version=$(xcodebuild -version | head -1)
    echo -e "${GREEN}✅ Xcode installed: $xcode_version${NC}"
    ((passed++))
    
    # Check version number
    version_number=$(echo "$xcode_version" | grep -o '[0-9]\+' | head -1)
    if [ "$version_number" -ge 14 ]; then
        echo -e "${GREEN}✅ Xcode version 14+ (compatible)${NC}"
        ((passed++))
    else
        echo -e "${RED}❌ Xcode version < 14 (may have issues)${NC}"
        ((failed++))
    fi
else
    echo -e "${RED}❌ Xcode not found or not in PATH${NC}"
    ((failed++))
fi

if command -v swift &> /dev/null; then
    swift_version=$(swift --version | head -1)
    echo -e "${GREEN}✅ Swift installed: $swift_version${NC}"
    ((passed++))
else
    echo -e "${RED}❌ Swift compiler not found${NC}"
    ((failed++))
fi
echo ""

echo -e "${BLUE}${BOLD}9. POTENTIAL ISSUES SCAN${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

issues_found=0

# Check for common problematic patterns
if grep -r "#if canImport(SwiftUI)" --include="*.swift" . 2>/dev/null | grep -v "Binary" | head -1; then
    echo -e "${YELLOW}⚠️  Conditional SwiftUI imports found (may cause issues)${NC}"
    ((issues_found++))
    ((warnings++))
fi

if grep -r "FirebaseCore" --include="*.swift" . 2>/dev/null | grep -v "Binary" | grep "import FirebaseCore" | head -1; then
    echo -e "${YELLOW}⚠️  FirebaseCore imported in Swift files (may be redundant)${NC}"
    ((issues_found++))
    ((warnings++))
fi

if [ "$issues_found" -eq 0 ]; then
    echo -e "${GREEN}✅ No common issues detected${NC}"
    ((passed++))
fi
echo ""

echo -e "${BLUE}${BOLD}10. PACKAGE RESOLUTION TEST${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Testing package resolution (this may take a moment)..."
echo ""

if swift package resolve 2>&1 | tee /tmp/package_resolve.log; then
    echo ""
    echo -e "${GREEN}✅ Packages resolved successfully${NC}"
    ((passed++))
    
    # Show resolved packages
    if [ -f ".build/workspace-state.json" ]; then
        echo ""
        echo "Resolved packages:"
        cat .build/workspace-state.json 2>/dev/null | grep -o '"identity".*' | head -5 || echo "   (details in .build/workspace-state.json)"
    fi
else
    echo ""
    echo -e "${RED}❌ Package resolution failed${NC}"
    ((failed++))
    echo "Check /tmp/package_resolve.log for details"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BOLD}FINAL REPORT${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "Tests Passed:    ${GREEN}${BOLD}$passed${NC}"
echo -e "Tests Failed:    ${RED}${BOLD}$failed${NC}"
echo -e "Warnings:        ${YELLOW}${BOLD}$warnings${NC}"
echo ""

if [ "$failed" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║     ✅ ALL CHECKS PASSED - READY TO BUILD ✅      ║${NC}"
    echo -e "${GREEN}${BOLD}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}${BOLD}🚀 Next Steps:${NC}"
    echo ""
    echo "1. Open in Xcode:"
    echo -e "   ${YELLOW}open Package.swift${NC}"
    echo ""
    echo "2. Wait for indexing to complete"
    echo ""
    echo "3. Build:"
    echo "   Product → Build (⌘B)"
    echo ""
    echo "4. Run on simulator:"
    echo "   Select iPhone 15 Pro"
    echo "   Product → Run (⌘R)"
    echo ""
    
    if [ "$warnings" -gt 0 ]; then
        echo -e "${YELLOW}Note: $warnings warning(s) found - see above for details${NC}"
        echo "These are not blocking, but you may want to address them."
        echo ""
    fi
    
    exit 0
else
    echo -e "${RED}${BOLD}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║     ❌ ISSUES FOUND - NEEDS ATTENTION ❌         ║${NC}"
    echo -e "${RED}${BOLD}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}${BOLD}🔧 Required Fixes:${NC}"
    echo ""
    
    if grep -q "Package.swift NOT FOUND" /tmp/final_check.log 2>/dev/null || [ ! -f "Package.swift" ]; then
        echo "❌ Package.swift is missing - this is critical"
    fi
    
    if grep -q "KomaliosApp.swift NOT FOUND" /tmp/final_check.log 2>/dev/null || [ ! -f "KomaliosApp.swift" ]; then
        echo "❌ KomaliosApp.swift is missing - app entry point required"
    fi
    
    if grep -q "Config.swift NOT FOUND" /tmp/final_check.log 2>/dev/null || [ ! -f "Config.swift" ]; then
        echo "❌ Config.swift is missing - create it for API configuration"
    fi
    
    echo ""
    echo "Review the errors above and fix them before building."
    echo ""
    exit 1
fi
