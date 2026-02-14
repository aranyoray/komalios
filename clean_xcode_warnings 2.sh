#!/bin/bash

# Clean Xcode Warnings - Removes cached build data that references missing files

echo "🧹 Cleaning Xcode build artifacts and cache..."
echo ""

# Check if Xcode is running
if pgrep -x "Xcode" > /dev/null; then
    echo "⚠️  Xcode is currently running!"
    echo "Please close Xcode completely before running this script."
    echo ""
    read -p "Press Enter after closing Xcode, or Ctrl+C to cancel..."
fi

# Double-check Xcode is closed
if pgrep -x "Xcode" > /dev/null; then
    echo "❌ Xcode is still running. Please close it and try again."
    exit 1
fi

echo "✓ Xcode is closed, proceeding with cleanup..."
echo ""

# Navigate to project directory
cd "$(dirname "$0")"

# Clean local build folder if it exists
if [ -d "build" ]; then
    echo "📂 Removing local build folder..."
    rm -rf build
    echo "   ✓ Done"
fi

# Kill any remaining Xcode processes
echo "🛑 Stopping Xcode-related processes..."
pkill -9 com.apple.dt.Xcode 2>/dev/null
pkill -9 ibtoold 2>/dev/null
pkill -9 ibtool 2>/dev/null
pkill -9 actool 2>/dev/null
sleep 2
echo "   ✓ Done"

# Clean DerivedData with force
echo "🗑️  Cleaning DerivedData..."
if [ -d ~/Library/Developer/Xcode/DerivedData/komalios-* ]; then
    # Use find and delete to handle locked files
    find ~/Library/Developer/Xcode/DerivedData/komalios-* -mindepth 1 -delete 2>/dev/null || true
    # Remove the directory itself
    rm -rf ~/Library/Developer/Xcode/DerivedData/komalios-* 2>/dev/null || true
    echo "   ✓ Done"
else
    echo "   ℹ️  No DerivedData found for komalios"
fi

# Clean module cache
echo "📦 Cleaning module cache..."
if [ -d ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex ]; then
    rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex 2>/dev/null || true
    echo "   ✓ Done"
else
    echo "   ℹ️  Module cache not found"
fi

# Clean Xcode cache
echo "💾 Cleaning Xcode cache..."
if [ -d ~/Library/Caches/com.apple.dt.Xcode ]; then
    rm -rf ~/Library/Caches/com.apple.dt.Xcode 2>/dev/null || true
    echo "   ✓ Done"
else
    echo "   ℹ️  Xcode cache not found"
fi

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "📋 Next steps:"
echo "   1. Reopen your project in Xcode"
echo "   2. Run Product → Clean Build Folder (Shift + Cmd + K)"
echo "   3. Build your project (Cmd + B)"
echo ""
echo "The 'Invalid Exclude' warnings should now be gone! 🎉"
