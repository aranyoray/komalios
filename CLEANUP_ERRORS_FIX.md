# Quick Fix for Directory Not Empty Errors

## The Problem
The cleanup script encountered "Directory not empty" errors because:
- Xcode or related processes were still running
- Some files in DerivedData were locked or in use

## Solution

### Option 1: Close Xcode First (Recommended)

1. **Completely quit Xcode** (Cmd + Q)
2. Run the updated cleanup script:
   ```bash
   chmod +x clean_xcode_warnings.sh
   ./clean_xcode_warnings.sh
   ```

The script will now:
- Check if Xcode is running
- Kill any remaining Xcode processes
- Use more aggressive cleanup methods
- Handle locked files gracefully

### Option 2: Force Delete Everything (If script still fails)

If you still see errors, run this one-liner in Terminal:

```bash
# Close Xcode first, then run:
pkill -9 Xcode; sleep 2; sudo rm -rf ~/Library/Developer/Xcode/DerivedData/komalios-*; rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex; rm -rf ~/Library/Caches/com.apple.dt.Xcode
```

**Note:** You'll be prompted for your password (sudo).

### Option 3: Reboot (Nuclear option)

If nothing else works:
1. Close Xcode
2. Restart your Mac
3. Run the cleanup script again

## After Cleanup

Once the cleanup is successful:
1. ✅ Reopen your project in Xcode
2. ✅ Press **Shift + Cmd + K** (Clean Build Folder)
3. ✅ Press **Cmd + B** (Build)
4. ✅ Warnings should be gone!

## Why This Happened

The "Directory not empty" error occurs when:
- Files are locked by running processes
- Xcode's indexing service has open file handles
- File system metadata hasn't been updated

The updated script handles all these scenarios.
