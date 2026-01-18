# ⚡ QUICKSTART - Developer Onboarding

## 🎯 Your Mission (Jan 19-26)
Integrate 5 pre-trained GCP models into Komalios iOS app using CoreML. Ship to App Store by Jan 24. Demo ready by Jan 26.

---

## 📋 Pre-Flight Checklist (Do This First)

### ✅ Day 1 Morning Setup (30 minutes)
```bash
# 1. Clone the repo (if not done)
git clone https://github.com/aranyoray/komalios.git
cd komalios

# 2. Clone the web demo repo (to understand the flow)
git clone https://github.com/aranyoray/komalweb.git

# 3. Install Python dependencies
pip install coremltools tensorflow torch onnx numpy pandas

# 4. Open Xcode project
open komalios.xcodeproj

# 5. Build and run to verify it works
# cmd+R in Xcode

# 6. Read these files in order:
# - DEVELOPMENT_PLAN.md (your daily roadmap)
# - ARCHITECTURE.md (system design)
# - TESTING.md (test URLs and criteria)
```

### ✅ Tools You'll Use Daily
- **Xcode 15+** - iOS development
- **Cursor Pro** - AI-powered code editor (use for boilerplate, reviews)
- **Claude Pro** - Ask questions, debug issues
- **Instruments** - Performance profiling (Day 5)
- **Simulator** - iPhone SE + iPhone 15 Pro Max testing

---

## 🗺️ Week at a Glance

```
Day 1 (Jan 19, Sun):  Download GCP models → Convert 1 to CoreML → Validate
Day 2 (Jan 20, Mon):  Convert all 5 models → Build ML service layer
Day 3 (Jan 21, Tue):  Integrate first model E2E → Core Data storage → UI
Day 4 (Jan 22, Wed):  Integrate all 5 models → Parent dashboard → Optimize
Day 5 (Jan 23, Thu):  Testing (30+ tests) → Bug fixes → App Store prep
Day 6 (Jan 24, Fri):  App Store submission → Final polish
Day 7 (Jan 25, Sat):  Demo prep (video, deck, script)
Day 8 (Jan 26, Sun):  🎉 DEMO DAY
```

**Daily Check-in**: 11 PM - Report progress (see DEVELOPMENT_PLAN.md for format)

---

## 🔑 Key Files to Work On

### Day 1-2: Model Conversion
```
📁 MLModels/
  └── convert_to_coreml.py  ← EDIT THIS
      - Implement conversion for your GCP model format
      - Run: python convert_to_coreml.py --model horror
```

### Day 2: Service Layer
```
📁 Sources/Komalios/Services/
  └── MLClassificationService.swift  ← CREATE THIS
      - Load 5 CoreML models
      - Implement classifyText() method
      - Add caching, error handling
```

### Day 3: Browser Integration
```
📁 Sources/Komalios/Views/
  └── BrowserView.swift  ← EDIT THIS
      - Hook into WKNavigationDelegate
      - Call ML service on navigation
      - Show BlockedView on harmful content
```

### Day 3: Storage
```
📁 Sources/Komalios/Services/
  └── ClassificationStorageService.swift  ← CREATE THIS
      - Core Data CRUD operations
      - Save classification history
```

### Day 4: Parent Dashboard
```
📁 Sources/Komalios/Views/
  └── AIReportsView.swift  ← CREATE THIS
      - Show classification history
      - Display charts
      - Export CSV
```

### Day 5: Tests
```
📁 Tests/KomaliosTests/
  └── MLClassificationServiceTests.swift  ← CREATE THIS
      - 30+ test cases
      - Performance benchmarks
```

---

## 💡 Pro Tips for Speed

### Use AI Tools Aggressively
**Cursor Pro:**
```
// Type comment, let Cursor autocomplete
// Load CoreML model and handle errors gracefully
[Cursor suggests complete implementation]
```

**Claude Pro:**
```
Prompt: "Review this CoreML service code for thread-safety issues and memory leaks"
[Paste code, get analysis + fixes]
```

### Copy from Web Demo
- komalweb repo has NLP preprocessing logic → **copy it**
- Don't reinvent text cleaning, tokenization, etc.

### Reuse Existing Components
- `KomalTheme.swift` has all UI components → use `BubblyCard`, `PillButtonStyle`
- `BlockedView.swift` exists → just add AI category display
- `AppState.swift` has state management → follow same pattern

### Batch Operations
- Don't test after every line change
- Write 50-100 lines → Build → Fix errors → Test
- Saves time vs. incremental testing

### Shortcuts
- `cmd+shift+K` - Clean build
- `cmd+U` - Run tests
- `cmd+R` - Build and run
- `cmd+/` - Comment/uncomment
- `cmd+shift+O` - Open quickly

---

## 🚨 Common Pitfalls to Avoid

### ❌ Don't Do This:
1. **Train new models** - Use GCP models as-is
2. **Overcomplicate conversion** - Simple coremltools conversion is fine
3. **Block main thread** - Always use async/await for ML
4. **Ignore caching** - Will be too slow without it
5. **Skip error handling** - App Store will reject
6. **Forget privacy manifest** - Must update PrivacyInfo.xcprivacy
7. **Test only on simulator** - Test on real device if available
8. **Skip documentation** - You'll forget what you did

### ✅ Do This Instead:
1. ✅ Download GCP models directly
2. ✅ Use coremltools standard conversion
3. ✅ All ML calls in `Task { await ... }`
4. ✅ Add NSCache from Day 2
5. ✅ Try-catch everywhere, graceful fallbacks
6. ✅ Update manifest on Day 5
7. ✅ Test on both if possible
8. ✅ Comment as you go, update docs daily

---

## 🐛 When You Get Stuck

### Debugging Checklist
```
Problem: Model won't load
→ Check model is in Xcode project
→ Check "Copy items if needed" was checked
→ Check model compiles (no errors in Xcode)
→ Check MLModelConfiguration is correct

Problem: Classification is slow (>100ms)
→ Profile with Instruments Time Profiler
→ Check if running in Debug (use Release)
→ Check if caching is working
→ Verify parallel execution (async let)

Problem: Core Data crashes
→ Check threading (use viewContext on main thread)
→ Check entity relationships
→ Use performBackgroundTask for heavy operations

Problem: App Store validation fails
→ Read error message carefully
→ Check PrivacyInfo.xcprivacy completeness
→ Verify no crashes on iOS 16/17/18
→ Check for rejected APIs
```

### Where to Get Help
1. **Claude Pro** - Ask specific questions with code
2. **Cursor Pro** - Inline suggestions and reviews
3. **Apple Developer Forums** - CoreML specific issues
4. **coremltools docs** - Conversion problems
5. **This repo's docs** - Architecture, testing guides

---

## 📊 Daily Success Indicators

### Day 1 (11 PM Check):
- [ ] komalweb repo understood
- [ ] All 5 GCP models downloaded
- [ ] 1 model converted to .mlmodel
- [ ] Validated in Python

### Day 2 (11 PM Check):
- [ ] All 5 .mlmodel files in Xcode
- [ ] MLClassificationService compiles
- [ ] Models load without errors
- [ ] Can classify test string

### Day 3 (11 PM Check):
- [ ] Horror classifier blocks scary URLs
- [ ] Core Data stores classifications
- [ ] BlockedView shows AI category
- [ ] <100ms latency

### Day 4 (11 PM Check):
- [ ] All 5 models integrated
- [ ] Parent dashboard shows data
- [ ] Age thresholds working
- [ ] Performance optimized

### Day 5 (11 PM Check):
- [ ] 30+ tests passing
- [ ] Zero known bugs
- [ ] Privacy manifest updated
- [ ] App Store ready

### Day 6 (11 PM Check):
- [ ] App submitted to App Store
- [ ] No validation errors
- [ ] Status: "In Review"

### Day 7 (11 PM Check):
- [ ] Demo video recorded
- [ ] Presentation deck done
- [ ] Practiced demo 3 times

---

## 🎯 The Only 3 Things That Matter

1. **App Store submission by Jan 24** → No bugs, no crashes, no rejections
2. **Demo ready by Jan 26** → Working live demo + video + deck
3. **5 models integrated** → All working, tested, documented

Everything else is secondary. Stay focused!

---

## 📞 11 PM Daily Check-In Template

Copy-paste this every night at 11 PM:
```
DAY X CHECK-IN ✅

Completed Today:
- ✅ [Specific task 1]
- ✅ [Specific task 2]
- ✅ [Specific task 3]

In Progress:
- 🟡 [Task 4 - X% done]

Blockers:
- ❌ [Issue if any] → [How I'm resolving it]

Tomorrow's Plan:
- [ ] [Specific task 1]
- [ ] [Specific task 2]

Metrics:
- Demo Readiness: X%
- App Store Readiness: X%
- Known Bugs: X
- Tests Passing: X/30
```

---

## 🚀 First Steps (Start Here)

```bash
# 1. Read DEVELOPMENT_PLAN.md fully (20 min)
cat DEVELOPMENT_PLAN.md

# 2. Read ARCHITECTURE.md (15 min)
cat ARCHITECTURE.md

# 3. Skim TESTING.md (5 min)
cat TESTING.md

# 4. Build the app to verify it works
# Open Xcode, cmd+R

# 5. Explore komalweb demo
cd ../komalweb
# Find the NLP classification logic

# 6. Start Day 1 tasks
# See DEVELOPMENT_PLAN.md → Day 1 section

# 7. Check in at 11 PM
# Post your progress update
```

---

**You got this! 🚀 Let's ship by Jan 24 and demo on Jan 26!**

---

## 📚 Quick Reference Links

- **Main Plan**: `DEVELOPMENT_PLAN.md` - Your daily roadmap
- **Architecture**: `ARCHITECTURE.md` - System design & data flow
- **Testing**: `TESTING.md` - Test URLs and criteria
- **ML Models**: `MLModels/README.md` - Model conversion guide
- **Web Demo**: https://github.com/aranyoray/komalweb - Reference implementation

**Questions?** Ask Claude Pro or check the docs above!
