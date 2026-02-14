# 🔧 Build Fix Guide - January 27, 2026

## 🚨 Current Errors

```
error: Unable to find module dependency: 'UIKit'
error: Unable to find module dependency: 'GoogleSignIn'
error: Unable to find module dependency: 'FirebaseAuth'
error: Unable to find module dependency: 'FirebaseFirestore'
error: Unable to find module dependency: 'FirebaseCore'
```

---

## ✅ Solution: Complete Fix Steps

### **Step 1: Clean Everything** 🧹

```bash
# In Terminal, navigate to your project directory
cd /path/to/Komalios

# Clean build artifacts
rm -rf ~/Library/Developer/Xcode/DerivedData/Komalios-*
rm -rf .build
rm -rf *.xcodeproj/project.xcworkspace/xcuserdata
```

**Or in Xcode:**
1. `⇧⌘K` - Clean Build Folder
2. `File > Close Workspace` (if using workspace)
3. `File > Packages > Reset Package Caches`
4. Quit Xcode completely

---

### **Step 2: Verify Package.swift is Correct** ✓

Your `Package.swift` should look like this:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Komalios",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .executable(name: "Komalios", targets: ["Komalios"])
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.20.0"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "7.0.0")
    ],
    targets: [
        .executableTarget(
            name: "Komalios",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
                .product(name: "GoogleSignInSwift", package: "GoogleSignIn-iOS")
            ],
            path: "Sources/Komalios",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
```

✅ This has been updated in your project already.

---

### **Step 3: Check if Using Xcode Project vs SPM** 🔍

**Your project is a HYBRID** - it has both:
- ✅ `Package.swift` (Swift Package Manager)
- ✅ `*.xcodeproj` (Xcode project)

**The issue:** You likely have an Xcode project that's NOT properly linked to Package.swift dependencies.

---

### **Step 4: Fix in Xcode Project** 🛠️

#### **Option A: If using .xcodeproj file (RECOMMENDED)**

1. **Open Xcode**
2. **Click your project** in the navigator (top blue icon)
3. **Select your app target** (Komalios)
4. **Go to "Frameworks, Libraries, and Embedded Content"** section
5. **Click the "+"** button
6. **Add these frameworks:**
   - FirebaseAuth
   - FirebaseCore
   - FirebaseFirestore
   - GoogleSignIn
   - GoogleSignInSwift

7. **If they don't appear in the list:**
   - Go to `File > Add Package Dependencies...`
   - Add these URLs:
     - `https://github.com/firebase/firebase-ios-sdk.git` (10.20.0+)
     - `https://github.com/google/GoogleSignIn-iOS` (7.0.0+)
   - Select the products you need

#### **Option B: If using Package.swift only**

```bash
# Resolve packages from command line
swift package resolve
swift package update

# Build from command line
swift build
```

---

### **Step 5: Fix UIKit Import** 🍎

UIKit is a **built-in iOS framework** - it should work automatically. If it doesn't:

1. **Check your build target:**
   - Open project settings
   - Verify **iOS** is selected (not macOS)
   - Deployment target should be **iOS 16.0+**

2. **Check file membership:**
   - Select files with UIKit imports
   - Ensure they're added to the correct target in File Inspector (⌥⌘1)

3. **Last resort - explicitly import:**

```swift
#if canImport(UIKit)
import UIKit
#else
#error("UIKit is required for iOS")
#endif
```

---

### **Step 6: Configure API Keys** 🔑

#### **Method 1: Update Config.swift (Quick & Easy)**

Edit the newly created `Config.swift` file:

```swift
// Replace these placeholder strings:
static let googleCloudAPIKey = "AIza..." // Your actual GCP key
static let googleCustomSearchAPIKey = "AIza..." // Your search key
static let googleCustomSearchEngineID = "abc123..." // Your search engine ID
static let moderationServiceURL = "https://your-backend.com" // Your Flask API
```

#### **Method 2: Use Info.plist (More Secure)**

1. Open `Info.plist` in Xcode
2. Add these keys:

```xml
<key>GOOGLE_CLOUD_API_KEY</key>
<string>AIza...YOUR_KEY_HERE</string>

<key>GOOGLE_CUSTOM_SEARCH_API_KEY</key>
<string>AIza...YOUR_KEY_HERE</string>

<key>GOOGLE_CUSTOM_SEARCH_ENGINE_ID</key>
<string>abc123...YOUR_ID_HERE</string>

<key>MODERATION_SERVICE_URL</key>
<string>https://your-backend.com</string>
```

3. Add `Info.plist` to `.gitignore` to keep keys secret

#### **Method 3: Environment Variables (CI/CD)**

```bash
# Add to your Xcode scheme
# Edit Scheme > Run > Arguments > Environment Variables
GOOGLE_CLOUD_API_KEY = "AIza..."
GOOGLE_CUSTOM_SEARCH_API_KEY = "AIza..."
GOOGLE_CUSTOM_SEARCH_ENGINE_ID = "abc123..."
MODERATION_SERVICE_URL = "https://your-backend.com"
```

---

### **Step 7: Verify Firebase Setup** 🔥

1. **Ensure `GoogleService-Info.plist` exists:**
   - Should be in project root
   - Should be added to Xcode target (check File Inspector)
   - Download from [Firebase Console](https://console.firebase.google.com/)

2. **Verify Firebase initialization in `AppDelegate.swift`:**

```swift
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        print("✅ Firebase configured")
        return true
    }
}
```

✅ This is already correct in your project.

---

### **Step 8: Rebuild** 🔨

1. **Restart Xcode**
2. **Open your project**
3. **Wait for package resolution** (status bar shows "Resolving Packages...")
4. **Clean Build Folder:** `⇧⌘K`
5. **Build:** `⌘B`

---

## 🎯 Expected Result

After these steps, you should see:

```
✅ Build succeeded
✅ All imports resolved
✅ No dependency errors
```

---

## 🐛 Still Having Issues?

### **Error: "Package resolution failed"**

```bash
# Force update packages
rm -rf .build
rm Package.resolved
swift package resolve
```

### **Error: "Module compiled with Swift X, expected Swift Y"**

- All packages must use same Swift version (5.9)
- Update Xcode to latest version
- Update package dependencies to latest compatible versions

### **Error: "Circular dependency detected"**

- Check `Package.swift` for circular references
- Ensure no target depends on itself

### **Error: "GoogleService-Info.plist not found"**

1. Download from Firebase Console
2. Drag into Xcode project root
3. Check "Copy items if needed"
4. Verify target membership

---

## 📋 Verification Checklist

After fixing, verify:

- [ ] Xcode builds without errors (`⌘B`)
- [ ] All Firebase imports work
- [ ] GoogleSignIn imports work
- [ ] UIKit imports work
- [ ] Config.swift has all 4 API keys set
- [ ] App launches without crashes
- [ ] Firebase authentication works
- [ ] Can print `Config.configurationStatus` in console

---

## 🚀 Next Steps After Build Success

1. **Test API integrations:**
```swift
// Add to AppDelegate or app launch
print(Config.configurationStatus)
```

2. **Set up CoreML models** (see MLModels/README.md)

3. **Test content filtering** with sample URLs

4. **Verify GCP fallback** works when CoreML confidence is low

---

## 📞 Emergency Fix

If nothing else works, try creating a **new Xcode project**:

1. File > New > Project
2. Choose "App" template
3. Add Package Dependencies (Firebase, GoogleSignIn)
4. Copy your source files over
5. Add `GoogleService-Info.plist`

Sometimes Xcode project files get corrupted and starting fresh is fastest.

---

**Last Updated:** January 27, 2026  
**Status:** Ready to fix build errors
