# 🧪 Testing Guide for Komalios CoreML Integration

## Test URLs by Category

### ✅ SAFE CONTENT (Should Always Allow)
These URLs should NEVER be blocked:
```
https://www.khanacademy.org/math/algebra
https://en.wikipedia.org/wiki/Science
https://www.bbc.com/news/science-environment
https://www.nasa.gov/
https://www.nationalgeographic.com/animals
https://scratch.mit.edu/
https://code.org/
https://www.codecademy.com/learn/learn-python
https://www.duolingo.com/
https://www.pbskids.org/
```

**Expected Result**: ✅ Allow - No blocking

---

### 🎃 HORROR / PARANORMAL CONTENT (Should Block)
Test the Horror Classifier:
```
https://www.reddit.com/r/nosleep
https://www.creepypasta.com/
https://www.reddit.com/r/LetsNotMeet
https://www.scaryforkids.com/
https://www.ghostvillage.com/
Search: "scary ghost stories that will give you nightmares"
Search: "paranormal activity caught on camera 3am"
Search: "jumpscare compilation horror"
Search: "creepypasta scariest stories"
```

**Expected Result**: 🚫 Block - Category: "Horror/Paranormal", Confidence: >70%

---

### 😢 CYBERBULLYING / HARASSMENT (Should Block)
Test the Cyberbullying Classifier:
```
Search: "you're so ugly and worthless"
Search: "slut shaming examples"
Search: "body shaming comments social media"
Search: "cyberbullying insults appearance"
Search: "harassment online teenagers"
Twitter/X posts with: "nobody likes you kill yourself"
Reddit threads about: "online bullying victims"
YouTube videos: "mean comments makeup tutorial"
```

**Expected Result**: 🚫 Block - Category: "Cyberbullying", Confidence: >70%

---

### 📱 PARASOCIAL / MANIPULATIVE CONTENT (Should Block)
Test the Parasocial Classifier:
```
https://www.youtube.com/watch?v=mr-beast-challenge (if exists)
Search: "YOU MUST WATCH THIS NOW or you'll regret it"
Search: "don't miss out FOMO limited time only"
Search: "influencer challenges kids copy dangerous"
Search: "clickbait thumbnail tricks"
Search: "parasocial relationship streamers unhealthy"
Search: "manipulative content creators tactics"
YouTube titles: "I GAVE AWAY $100,000!! (YOU WON'T BELIEVE)"
TikTok/Instagram: "viral challenge everyone is doing"
```

**Expected Result**: 🚫 Block - Category: "Parasocial/Manipulative", Confidence: >65%

---

### 💰 FINANCIAL ADVICE (Should Block)
Test the Financial Advice Classifier:
```
Search: "buy this crypto now before it's too late"
Search: "stock tips get rich quick"
Search: "forex trading strategy guaranteed wins"
Search: "investment opportunity passive income"
Search: "crypto pump and dump groups"
https://www.reddit.com/r/CryptoMoonShots
https://www.reddit.com/r/wallstreetbets (financial advice without disclaimers)
YouTube: "How I made $10,000 in ONE DAY trading crypto"
Telegram groups: "VIP crypto signals"
```

**Expected Result**: 🚫 Block - Category: "Financial Advice", Confidence: >70%

---

### 🔞 MATURE CONTENT (Should Block or Gate)
Test the Mature Content Classifier (multi-label):

#### Sexual Content:
```
Search: "kissing scenes romantic movies"
Search: "sexual education anatomy lesson"
Search: "mature themes HBO series"
Search: "intimate relationship advice"
YouTube: "Sex education Netflix clips"
```
**Expected**: 🔒 Gate (requires PIN) - Category: "Mature Content (Sexual)"

#### LGBTQ+ Content:
```
Search: "LGBTQ pride parade celebration"
Search: "coming out story personal experience"
Search: "gay marriage equality discussion"
Search: "transgender journey transition story"
Search: "queer representation in media"
https://www.pride.com/
YouTube: "LGBTQ+ rights activism"
```
**Expected**: ✅ Allow OR 🔒 Gate (depending on age settings)
**Note**: Should NOT block unless age <10 with strict settings

#### Religious Content:
```
Search: "religious sermon Sunday worship"
Search: "prayer meeting faith gathering"
Search: "scripture reading Bible study"
Search: "Christian worship music gospel"
Search: "Islamic call to prayer"
YouTube: "Religious teaching moral lessons"
```
**Expected**: ✅ Allow OR 🔒 Gate (depending on age settings)

#### Religious Extremism (Should ALWAYS Block):
```
Search: "religious extremism hate violence"
Search: "aggressive proselytizing children"
Search: "religious hate speech discrimination"
Search: "faith-based terrorism ideology"
```
**Expected**: 🚫 Block - Category: "Mature Content (Religious)" with high confidence

---

## 🎯 Age-Based Threshold Testing

### Age Group: <10 (Strictest)
- Confidence threshold: 0.5 (blocks more content)
- Test with borderline content (e.g., "mildly scary story")
- **Expected**: Blocks even low-confidence detections

### Age Group: 10-13 (Moderate)
- Confidence threshold: 0.65
- Test with mild horror (e.g., "ghost story for kids")
- **Expected**: Blocks moderate-confidence detections

### Age Group: 13-16 (Relaxed)
- Confidence threshold: 0.75
- Test with teen-appropriate content
- **Expected**: Only blocks high-confidence harmful content

### Age Group: 16+ (Very Relaxed)
- Confidence threshold: 0.85
- Test with mature but educational content
- **Expected**: Only blocks very high-confidence harmful content

---

## 🧪 Edge Case Testing

### Empty/Invalid Input:
```
Empty URL: ""
Special characters: "https://example.com/!@#$%^&*()"
Very long URL: "https://example.com/" + "a"*10000
Non-English: "https://例え.jp/テスト"
Emojis: "https://example.com/🎃👻💀"
```
**Expected**: ✅ Allow (graceful handling, no crashes)

### Rapid Navigation:
Navigate to 10 different URLs within 10 seconds:
```
1. https://khanacademy.org
2. https://reddit.com/r/nosleep
3. https://wikipedia.org
4. https://creepypasta.com
5. https://nasa.gov
6. https://youtube.com (horror video)
7. https://bbc.com
8. (Repeat)
```
**Expected**: All classifications complete, no crashes, <100ms each

### Offline Testing:
1. Enable Airplane Mode
2. Navigate to cached page
3. Try to classify content
**Expected**: Models still work (on-device processing)

### Memory Warnings:
1. Open app
2. Load all 5 models
3. Simulate memory warning in Xcode
4. Continue classification
**Expected**: Graceful handling, models reload if needed

---

## 📊 Performance Benchmarks

### Classification Latency:
- **Target**: <100ms per URL
- **Test**: Use XCTest `measure {}` block
- **Command**: Run performance test 10 times, average latency

```swift
func testClassificationPerformance() {
    measure {
        let text = "Test horror content scary ghost"
        _ = try? await classifier.classifyText(text)
    }
}
```

### Memory Usage:
- **Target**: <150MB total (app + 5 models)
- **Tool**: Xcode Instruments - Allocations
- **Test**: Load app, navigate to 50 URLs, check peak memory

### Battery Impact:
- **Target**: <2% increase over 30 minutes
- **Tool**: Xcode Energy Log
- **Test**: Continuous browsing for 30 minutes with ML on vs. off

---

## ✅ Manual Testing Checklist (Day 5)

### Unit Tests (XCTest):
- [ ] `testHorrorClassifierWithHorrorContent()` - Should detect horror
- [ ] `testHorrorClassifierWithSafeContent()` - Should not detect
- [ ] `testCyberbullyingDetection()` - Should detect bullying
- [ ] `testParasocialDetection()` - Should detect manipulation
- [ ] `testFinancialAdviceDetection()` - Should detect risky advice
- [ ] `testMatureContentDetection()` - Should detect mature themes
- [ ] `testEmptyInput()` - Should handle gracefully
- [ ] `testVeryLongInput()` - Should truncate/handle
- [ ] `testSpecialCharacters()` - Should not crash
- [ ] `testCachingBehavior()` - Should cache results
- [ ] `testModelLoadingFailure()` - Should handle errors
- [ ] `testCoreDataStorage()` - Should save/fetch correctly
- [ ] `testPerformance()` - Should complete <100ms

**Target**: 30+ tests, 100% pass rate

### Integration Tests:
- [ ] Open app → Navigate to horror site → Blocked
- [ ] Open app → Navigate to Khan Academy → Allowed
- [ ] Switch age to <10 → Horror site blocked with lower threshold
- [ ] Switch age to 16+ → Horror site allowed if low confidence
- [ ] Parent mode → View AI Reports → See blocked categories
- [ ] Parent mode → Export CSV → File downloads correctly
- [ ] Clear history → History cleared
- [ ] App backgrounded for 10 min → Resume → Models still work

### Real-World URLs (Day 5):
- [ ] Test all Safe Content URLs (10/10 allowed)
- [ ] Test all Horror URLs (8/10 blocked, 2 may be edge cases)
- [ ] Test all Cyberbullying queries (9/10 blocked)
- [ ] Test all Parasocial URLs (7/10 blocked, may have false negatives)
- [ ] Test all Financial Advice URLs (9/10 blocked)
- [ ] Test all Mature Content URLs (varies by age setting)

**Target**: >90% accuracy across all categories

---

## 🐛 Bug Reporting Template

If you find a bug:
```
**Bug Title**: [Short description]

**Category**: [Horror/Cyberbullying/Parasocial/Financial/Mature]

**URL/Query**: [Exact URL or search query]

**Expected Behavior**: [What should happen]

**Actual Behavior**: [What actually happened]

**Classification Result**:
- Is Harmful: [true/false]
- Categories: [list]
- Confidence: [score]

**Device**: [iPhone model, iOS version]

**Age Setting**: [<10 / 10-13 / 13-16 / 16+]

**Steps to Reproduce**:
1. ...
2. ...

**Screenshots**: [Attach if UI bug]
```

---

## 🎯 Success Criteria

### For Demo (Jan 26):
- [ ] All 5 models working
- [ ] Zero crashes during 30-min continuous use
- [ ] >95% accuracy on curated test URLs
- [ ] <100ms classification latency (90th percentile)
- [ ] Beautiful UI showing AI detections
- [ ] Parent dashboard with insights

### For App Store (Jan 24):
- [ ] Zero known bugs
- [ ] All unit tests passing
- [ ] Privacy manifest complete
- [ ] No validation errors
- [ ] Compliant with App Store guidelines

---

**Testing is not optional - it's critical for success! 🧪**
