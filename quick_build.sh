#!/bin/bash
# Quick one-liner to fix and build

echo "🚀 Quick Build Fix"
echo "=================="
echo ""

# Make script executable if needed
chmod +x fix_build_complete.sh 2>/dev/null

# Run the complete fix
if [ -f "fix_build_complete.sh" ]; then
    ./fix_build_complete.sh
else
    echo "Running inline build fix..."
    
    # Clean
    rm -rf .build build DerivedData Package.resolved 2>/dev/null
    rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null
    
    # Resolve and build
    swift package resolve && swift package update && swift build
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ Build successful!"
        echo ""
        echo "Open in Xcode:"
        echo "$ open Package.swift"
    else
        echo ""
        echo "❌ Build failed. Check Package.swift for issues."
        echo ""
        echo "Try in Xcode:"
        echo "1. open Package.swift"
        echo "2. File → Packages → Reset Package Caches"
        echo "3. Product → Build (⌘B)"
    fi
fi
