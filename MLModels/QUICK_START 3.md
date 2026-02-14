# ⚡ QUICK START - Fix Everything Now!

## 🚨 You Have Build Errors? Do This First:

### 1️⃣ Fix Dependencies (2 minutes)
```bash
# Open Terminal in project directory:
cd /path/to/your/project

# Clean everything:
rm -rf ~/Library/Developer/Xcode/DerivedData/Komalios-*

# In Xcode:
# 1. Quit Xcode completely
# 2. Reopen project
# 3. File > Packages > Reset Package Caches
# 4. Wait for packages to resolve
# 5. Clean: ⇧⌘K
# 6. Build: ⌘B
```

**Still broken?** Read `BUILD_FIX_GUIDE.md` for detailed help.

---

### 2️⃣ Add Your API Keys (1 minute)

Open `Config.swift` and replace these 4 lines:

```swift
// Line ~27:
return "YOUR_GOOGLE_CLOUD_API_KEY_HERE"

// Line ~42:
return "YOUR_GOOGLE_CUSTOM_SEARCH_API_KEY_HERE"

// Line ~57:
return "YOUR_GOOGLE_CUSTOM_SEARCH_ENGINE_ID_HERE"

// Line ~72:
return "https://your-moderation-backend.com"
```

**Where are my keys?**
You told me you have them - they're the ones you listed:
- `GOOGLE_CLOUD_API_KEY`
- `GOOGLE_CUSTOM_SEARCH_API_KEY`
- `GOOGLE_CUSTOM_SEARCH_ENGINE_ID`
- `MODERATION_SERVICE_URL`

---

### 3️⃣ Verify It Works (30 seconds)

Add this to `AppDelegate.swift` after `FirebaseApp.configure()`:

```swift
print(Config.configurationStatus)
```

Build and run - should print:
```
✓ Google Cloud API Key: ✅ Set
✓ Custom Search API Key: ✅ Set
✓ Custom Search Engine ID: ✅ Set
✓ Moderation Service URL: https://...
```

---

## ✅ Done! Now What?

You now have:
- ✅ Firebase + GoogleSignIn dependencies fixed
- ✅ API keys centrally managed in `Config.swift`
- ✅ Google Cloud services ready (Vision, NLP, Search)
- ✅ CoreML-first architecture (GCP as backup)

### Test GCP Integration:

```swift
// Paste in any view:
Task {
    let gcp = GoogleCloudService()
    
    // Test image safety:
    if let testImage = UIImage(systemName: "photo"),
       let imageData = testImage.jpegData(compressionQuality: 0.8) {
        let result = try? await gcp.analyzeImageSafety(imageData: imageData)
        print("Image safe? \(result?.isSafeForChildren ?? false)")
    }
    
    // Test text safety:
    let textResult = try? await gcp.analyzeTextSafety(text: "Hello world")
    print("Text sentiment: \(textResult?.sentimentScore ?? 0)")
}
```

---

## 📖 Full Documentation

| File | When to Read |
|------|-------------|
| **COMPLETE_FIX_SUMMARY.md** | Overview of everything |
| **BUILD_FIX_GUIDE.md** | Build still broken? |
| **Config.swift** | Change API keys or settings |
| **GoogleCloudService.swift** | Use GCP APIs in your code |
| **Models_Masterlist.csv** | Your content filtering rules |

---

## 🆘 Still Stuck?

### Build Error: "Module not found"
→ `BUILD_FIX_GUIDE.md` → Step 4

### API Error: "Invalid key"
→ Double-check keys in `Config.swift` (no typos!)

### Firebase Error
→ Check `GoogleService-Info.plist` is in project

### CoreML Error
→ See `MLModels/README.md`

---

**You're 3 steps away from working!** 🎯

1. Fix dependencies ✅
2. Add API keys ✅  
3. Test it ✅

Total time: **3-5 minutes**
