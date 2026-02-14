#!/bin/bash

# Clean Xcode Warnings - Removes cached build data that references missing files

echo "🧹 Cleaning Xcode build artifacts and cache..."

# Navigate to project directory
cd "$(dirname "$0")"

# Clean local build folder if it exists
if [ -d "build" ]; then
    echo "Removing local build folder..."
    rm -rf build
fi

# Clean DerivedData
echo "Cleaning DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/komalios-*

# Clean module cache
echo "Cleaning module cache..."
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex

# Clean Xcode cache
echo "Cleaning Xcode cache..."
rm -rf ~/Library/Caches/com.apple.dt.Xcode

echo "✅ Cleanup complete!"
echo ""
echo "Next steps:"
echo "1. Reopen your project in Xcode"
echo "2. Run Product → Clean Build Folder (Shift + Cmd + K)"
echo "3. Build your project"
