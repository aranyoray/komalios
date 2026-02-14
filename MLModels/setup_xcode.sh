#!/bin/bash
# setup_xcode.sh
# Quick setup script for the iOS app

echo "=================================================="
echo "Content Safety iOS App - Quick Setup"
echo "=================================================="

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode is not installed. Please install Xcode from the App Store."
    exit 1
fi

echo "✅ Xcode found"

# Check if project exists
if [ ! -f "iOSApp/ContentSafetyTest.xcodeproj/project.pbxproj" ]; then
    echo "❌ Xcode project not found. Make sure you're in the /repo directory."
    exit 1
fi

echo "✅ Project found"

# Open project in Xcode
echo ""
echo "Opening project in Xcode..."
open iOSApp/ContentSafetyTest.xcodeproj

echo ""
echo "=================================================="
echo "✅ Project opened in Xcode!"
echo "=================================================="
echo ""
echo "Next steps:"
echo "  1. Select 'iPhone 15 Pro' simulator"
echo "  2. Press Cmd+R to build and run"
echo "  3. Grant microphone and speech permissions"
echo ""
echo "Backend setup:"
echo "  1. Make sure your Flask backend is running:"
echo "     cd path/to/komalweb"
echo "     python app.py"
echo ""
echo "  2. Test endpoint:"
echo "     curl http://localhost:5000/api/health"
echo ""
echo "For more info, see: iOSApp/README.md"
echo ""
