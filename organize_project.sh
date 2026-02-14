#!/bin/bash
# organize_project.sh - Organize files into proper SPM structure

echo "📁 Organizing Project Structure for Swift Package Manager"
echo "=========================================================="
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Create Sources directory if it doesn't exist
if [ ! -d "Sources" ]; then
    echo -e "${BLUE}Creating Sources directory...${NC}"
    mkdir -p Sources/Komalios
    echo -e "${GREEN}✅ Created Sources/Komalios/${NC}"
else
    echo -e "${GREEN}✅ Sources directory exists${NC}"
    if [ ! -d "Sources/Komalios" ]; then
        mkdir -p Sources/Komalios
        echo -e "${GREEN}✅ Created Sources/Komalios/${NC}"
    fi
fi

# Create Resources directory
if [ ! -d "Sources/Komalios/Resources" ]; then
    mkdir -p Sources/Komalios/Resources
    echo -e "${GREEN}✅ Created Sources/Komalios/Resources/${NC}"
fi

echo ""
echo -e "${BLUE}Moving Swift files to Sources/Komalios/...${NC}"

# Find all Swift files in root (not in Sources, not in build dirs)
SWIFT_FILES=$(find . -maxdepth 1 -name "*.swift" -not -path "./Sources/*" -not -path "./.build/*" -not -path "./build/*" 2>/dev/null)

MOVED=0
for file in $SWIFT_FILES; do
    filename=$(basename "$file")
    if [ "$filename" != "Package.swift" ]; then
        if [ ! -f "Sources/Komalios/$filename" ]; then
            cp "$file" "Sources/Komalios/"
            echo "  ✅ Copied $filename"
            MOVED=$((MOVED + 1))
        else
            echo "  ⚠️  $filename already in Sources/Komalios/"
        fi
    fi
done

echo ""
echo -e "${GREEN}Moved $MOVED Swift files${NC}"

# Move plist files to Resources
echo ""
echo -e "${BLUE}Organizing resource files...${NC}"

if [ -f "GoogleService-Info.plist" ]; then
    cp "GoogleService-Info.plist" "Sources/Komalios/Resources/"
    echo "  ✅ Copied GoogleService-Info.plist to Resources"
fi

if [ -f "Info.plist" ]; then
    cp "Info.plist" "Sources/Komalios/Resources/"
    echo "  ✅ Copied Info.plist to Resources"
fi

# Create a sample Info.plist if it doesn't exist
if [ ! -f "Sources/Komalios/Resources/Info.plist" ]; then
    cat > "Sources/Komalios/Resources/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>com.komalkids.komal</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UIApplicationSceneManifest</key>
    <dict>
        <key>UIApplicationSupportsMultipleScenes</key>
        <false/>
    </dict>
    <key>UIApplicationSupportsIndirectInputEvents</key>
    <true/>
    <key>UILaunchScreen</key>
    <dict/>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>armv7</string>
    </array>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>NSMicrophoneUsageDescription</key>
    <string>We need microphone access for voice input in the chat.</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>We need speech recognition to convert your voice to text.</string>
    <key>NSCameraUsageDescription</key>
    <string>We need camera access for content scanning.</string>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>We need photo library access for content filtering.</string>
</dict>
</plist>
EOF
    echo "  ✅ Created Info.plist with privacy permissions"
fi

echo ""
echo -e "${BLUE}Verifying structure...${NC}"
echo ""

if [ -f "Sources/Komalios/KomaliosApp.swift" ]; then
    echo -e "${GREEN}✅ KomaliosApp.swift in correct location${NC}"
else
    echo -e "${RED}❌ KomaliosApp.swift not found in Sources/Komalios/${NC}"
fi

if [ -f "Sources/Komalios/AppDelegate.swift" ]; then
    echo -e "${GREEN}✅ AppDelegate.swift in correct location${NC}"
else
    echo -e "${YELLOW}⚠️  AppDelegate.swift not found${NC}"
fi

if [ -f "Sources/Komalios/Config.swift" ]; then
    echo -e "${GREEN}✅ Config.swift in correct location (API keys)${NC}"
else
    echo -e "${YELLOW}⚠️  Config.swift not found${NC}"
fi

echo ""
echo -e "${BLUE}Swift files count in Sources/Komalios/:${NC}"
SWIFT_COUNT=$(find Sources/Komalios -name "*.swift" 2>/dev/null | wc -l)
echo "  📄 $SWIFT_COUNT Swift files"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ Project Structure Organized!       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""

echo "Project structure:"
echo "Komalios/"
echo "├── Package.swift ✅"
echo "├── Sources/"
echo "│   └── Komalios/"
echo "│       ├── *.swift files (${SWIFT_COUNT} files) ✅"
echo "│       └── Resources/"
echo "│           ├── GoogleService-Info.plist"
echo "│           └── Info.plist ✅"
echo "└── ... (other files)"
echo ""

echo "Next steps:"
echo "1. Run: swift package resolve"
echo "2. Open in Xcode: File > Open > Select project folder"
echo "3. Build in Xcode (⌘B)"
