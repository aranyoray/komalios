# System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          ContentSafetyEngine                                 │
│                         (Main Orchestrator)                                  │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
                         ┌────────────────────────┐
                         │   Input Validation     │
                         │  ContentInput + Age    │
                         └────────────────────────┘
                                      │
                                      ▼
                    ┌─────────────────────────────────┐
                    │   1. Hard Overrides Check       │
                    │   - Blocked domain? → BLOCK     │
                    │   - Allowed domain? → ALLOW     │
                    │   - Parent keyword? → BLOCK     │
                    └─────────────────────────────────┘
                                      │
                                      ▼
                         ┌────────────────────────┐
                         │   2. Cache Lookup      │
                         │   (LRU by ID + age)    │
                         └────────────────────────┘
                              │              │
                         Hit ─┤              ├─ Miss
                              ▼              ▼
                    ┌──────────────┐   ┌──────────────────────────┐
                    │ Return       │   │  3. TEXT STAGE           │
                    │ Cached       │   │  (Always runs)           │
                    │ Verdict      │   │                          │
                    └──────────────┘   │  ┌───────────────────┐   │
                                      │  │ Preprocessor      │   │
                                      │  │ - Extract snippets│   │
                                      │  │ - Tokenize        │   │
                                      │  │ - Pad to 384      │   │
                                      │  └───────────────────┘   │
                                      │           ▼              │
                                      │  ┌───────────────────┐   │
                                      │  │ W8A8 BERT-lite    │   │
                                      │  │ Multi-label       │   │
                                      │  │ 6 major + 50 sub  │   │
                                      │  └───────────────────┘   │
                                      │           ▼              │
                                      │  ┌───────────────────┐   │
                                      │  │ TextStage.Result  │   │
                                      │  │ - categories      │   │
                                      │  │ - confidence      │   │
                                      │  │ - keywords        │   │
                                      │  └───────────────────┘   │
                                      └──────────────────────────┘
                                                 │
                                                 ▼
                                   ┌──────────────────────┐
                                   │ 4. needsVision?      │
                                   │ - Ban-sensitive >0.3?│
                                   │ - Confidence <0.6?   │
                                   │ - High-risk domain?  │
                                   └──────────────────────┘
                                    │                  │
                               No ──┤                  ├── Yes
                                    │                  │
                                    │                  ▼
                                    │        ┌──────────────────────────┐
                                    │        │  5. VISION STAGE         │
                                    │        │  (Conditional)           │
                                    │        │                          │
                                    │        │  ┌───────────────────┐   │
                                    │        │  │ Sample frames     │   │
                                    │        │  │ 1-3 images        │   │
                                    │        │  │ 3-6 video frames  │   │
                                    │        │  └───────────────────┘   │
                                    │        │           ▼              │
                                    │        │  ┌───────────────────┐   │
                                    │        │  │ Downscale 224px   │   │
                                    │        │  └───────────────────┘   │
                                    │        │           ▼              │
                                    │        │  ┌───────────────────┐   │
                                    │        │  │ NSFW Detector     │   │
                                    │        │  │ (Int8, 17kB)      │   │
                                    │        │  └───────────────────┘   │
                                    │        │           ▼              │
                                    │        │  ┌───────────────────┐   │
                                    │        │  │ Violence Detector │   │
                                    │        │  │ (Int8, 12MB)      │   │
                                    │        │  └───────────────────┘   │
                                    │        │           ▼              │
                                    │        │  ┌───────────────────┐   │
                                    │        │  │ VisionStage.Result│   │
                                    │        │  │ - nsfwScore       │   │
                                    │        │  │ - violenceScore   │   │
                                    │        │  └───────────────────┘   │
                                    │        └──────────────────────────┘
                                    │                  │
                                    └──────────┬───────┘
                                               │
                                               ▼
                                ┌──────────────────────────────┐
                                │  6. Score Merging            │
                                │  (RuleEngine)                │
                                │                              │
                                │  If ban-sensitive:           │
                                │    0.6 × vision + 0.4 × text │
                                │  Else:                       │
                                │    0.4 × vision + 0.6 × text │
                                └──────────────────────────────┘
                                               │
                                               ▼
                                ┌──────────────────────────────┐
                                │  7. Apply Age Rules          │
                                │  (PolicyEngine lookup)       │
                                │                              │
                                │  Per category:               │
                                │  - Look up policy            │
                                │  - Apply thresholds          │
                                │  - Determine action          │
                                └──────────────────────────────┘
                                               │
                                               ▼
                                ┌──────────────────────────────┐
                                │  8. Most-Restrictive Merge   │
                                │                              │
                                │  BLOCK > GATE > ALLOW        │
                                └──────────────────────────────┘
                                               │
                                               ▼
                                ┌──────────────────────────────┐
                                │  9. Store in Cache           │
                                │  (LRU, 1-hour TTL)           │
                                └──────────────────────────────┘
                                               │
                                               ▼
                                ┌──────────────────────────────┐
                                │  SafetyVerdict               │
                                │  ┌──────────────────────┐    │
                                │  │ action: BLOCK|GATE|  │    │
                                │  │         ALLOW        │    │
                                │  │ confidence: 0.0-1.0  │    │
                                │  │ categories: [...]    │    │
                                │  │ reason: "..."        │    │
                                │  │ details: {...}       │    │
                                │  └──────────────────────┘    │
                                └──────────────────────────────┘


═══════════════════════════════════════════════════════════════════════════════
                              POLICY ENGINE
═══════════════════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────────────────┐
│                         Build-Time Artifacts                                 │
│                   (Generated from Models_Masterlist.csv)                     │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
              ┌───────────────────────┼───────────────────────┐
              │                       │                       │
              ▼                       ▼                       ▼
  ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐
  │ labels_major.json  │  │ keywords_major.json│  │  age_rules.json    │
  │                    │  │                    │  │                    │
  │ violence           │  │ violence:          │  │ violence:          │
  │ explicit           │  │   "blood": 0.9     │  │   <10: BLOCK       │
  │ substances         │  │   "gore": 1.0      │  │   10-13: GATE      │
  │ financial          │  │ explicit:          │  │   13-16: GATE      │
  │ media              │  │   "porn": 1.0      │  │   16+: ALLOW       │
  │ social             │  │   "nude": 0.9      │  └────────────────────┘
  └────────────────────┘  └────────────────────┘
              │                       │
              │                       │
              ▼                       ▼
  ┌────────────────────┐  ┌────────────────────┐
  │ labels_sub.json    │  │ thresholds.json    │
  │                    │  │                    │
  │ graphic_violence:  │  │ violence:          │
  │   parent: violence │  │   block: 0.6       │
  │   id: "gv_01"      │  │   gate: 0.3        │
  │                    │  │   banSensitive: Y  │
  │ nsfw_content:      │  │ explicit:          │
  │   parent: explicit │  │   block: 0.6       │
  │   id: "ex_01"      │  │   gate: 0.3        │
  └────────────────────┘  │   banSensitive: Y  │
                          └────────────────────┘


═══════════════════════════════════════════════════════════════════════════════
                           RUNTIME DATA FLOW
═══════════════════════════════════════════════════════════════════════════════

User Content                    Text Processing               Vision Processing
    │                                 │                              │
    ▼                                 ▼                              ▼
┌─────────┐                  ┌──────────────┐              ┌──────────────┐
│ "Check  │                  │ Extract      │              │ Sample       │
│  out    │ ────────────────▶│ snippets     │              │ 1-3 frames   │
│  this   │                  │ with keyword │              │              │
│  video" │                  │ scoring      │              │ Downscale    │
│         │                  └──────────────┘              │ to 224px     │
│ + 3     │                         │                      └──────────────┘
│ images  │                         ▼                              │
└─────────┘                  ┌──────────────┐                     ▼
                             │ Tokenize     │              ┌──────────────┐
                             │ 256-384      │              │ Run NSFW     │
                             │ tokens       │              │ detector     │
                             └──────────────┘              │ (17kB)       │
                                    │                      └──────────────┘
                                    ▼                              │
                             ┌──────────────┐                     ▼
                             │ BERT-lite    │              ┌──────────────┐
                             │ W8A8         │              │ Run violence │
                             │ inference    │              │ detector     │
                             │ ~45ms        │              │ (12MB)       │
                             └──────────────┘              └──────────────┘
                                    │                              │
                                    │                              │
                                    └──────────┬───────────────────┘
                                               │
                                               ▼
                                    ┌────────────────────┐
                                    │ Weighted merge     │
                                    │ (0.6 / 0.4)        │
                                    └────────────────────┘
                                               │
                                               ▼
                                    ┌────────────────────┐
                                    │ Age rules +        │
                                    │ thresholds         │
                                    └────────────────────┘
                                               │
                                               ▼
                                    ┌────────────────────┐
                                    │ SafetyVerdict      │
                                    │ BLOCK/GATE/ALLOW   │
                                    └────────────────────┘


═══════════════════════════════════════════════════════════════════════════════
                              PERFORMANCE PROFILE
═══════════════════════════════════════════════════════════════════════════════

Path A: Text-Only (70% of requests)
────────────────────────────────────
  Overrides check     ────▶  < 1ms
  Cache lookup        ────▶  < 1ms (miss)
  Text preprocessing  ────▶  ~10ms
  BERT-lite inference ────▶  ~30ms (ANE)
  Score merge         ────▶  < 1ms
  Age rules           ────▶  < 1ms
  Cache store         ────▶  < 1ms
  ─────────────────────────────────
  Total              ────▶  ~45ms ✅


Path B: Text + Vision (30% of requests)
────────────────────────────────────────
  Overrides check     ────▶  < 1ms
  Cache lookup        ────▶  < 1ms (miss)
  Text preprocessing  ────▶  ~10ms
  BERT-lite inference ────▶  ~30ms (ANE)
  needsVision check   ────▶  < 1ms
  Frame sampling      ────▶  ~15ms
  NSFW inference      ────▶  ~20ms (ANE)
  Violence inference  ────▶  ~20ms (ANE)
  Score merge         ────▶  < 1ms
  Age rules           ────▶  < 1ms
  Cache store         ────▶  < 1ms
  ─────────────────────────────────
  Total              ────▶  ~95ms ✅


Path C: Cache Hit (60-70% of repeated requests)
────────────────────────────────────────────────
  Overrides check     ────▶  < 1ms
  Cache lookup        ────▶  < 1ms (HIT!)
  ─────────────────────────────────
  Total              ────▶  < 2ms ✅✅✅


═══════════════════════════════════════════════════════════════════════════════

Legend:
  ┌─┐ = Component/Module
  ▼  = Data flow direction
  │  = Pipeline stage
  ──▶ = Fast path (<5ms)
  ══▶ = Slow path (>50ms)
  ✅ = Performance target met
```
