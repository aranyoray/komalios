# TypeScript Privacy & Robustness Layer Integration Guide

## Overview

This guide explains how to integrate the comprehensive TypeScript privacy, security, and robustness features into the Komal therapeutic SEL app.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Komal App (React)                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    SensorManager                             │
│  - Detects capabilities (eye, face, mic, touch)             │
│  - Handles permissions gracefully                            │
│  - Emits raw sensor events                                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  SamplingScheduler                           │
│  - Downsamples to optimal Hz (battery-aware)                │
│  - Batches scoring calculations                              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    PrivacyGuard                              │
│  - Processes raw sensor data → derived features             │
│  - Clears raw buffers immediately                            │
│  - NEVER stores raw images/audio/coordinates                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│               Defensive Metric Calculators                   │
│  - Compute subdomain scores safely                           │
│  - Handle empty/null inputs gracefully                       │
│  - Report errors to ErrorBus                                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      IndexedDB                               │
│  - Stores ONLY derived features                              │
│  - Safe for cloud sync                                       │
└─────────────────────────────────────────────────────────────┘
```

## Components

### 1. PrivacyGuard Layer
**Location:** `src/privacy/`

**Purpose:** Ensures no raw sensor data is ever stored or transmitted.

**Key Files:**
- `types.ts` - Type definitions for raw vs safe data
- `PrivacyGuard.ts` - Processing functions and memory management

**Integration:**
```typescript
import {
  processEyeSamples,
  processAudioFrames,
  processFaceFrames,
  PrivacyGuardMemoryManager
} from './privacy/PrivacyGuard';

// Setup
const memoryManager = new PrivacyGuardMemoryManager();
const eyeBuffer: RawEyeSample[] = [];

// Collect raw data (memory only)
eyeBuffer.push({ timestamp: Date.now(), leftEye: {...}, rightEye: {...} });

// Process every 1-2 seconds
const gazeSummaries = processEyeSamples(eyeBuffer); // Auto-clears buffer

// Store ONLY derived features
await db.add('sessionFeatures', {
  sessionId: 'xxx',
  gaze: gazeSummaries,
  // NO raw data!
});
```

**Privacy Guarantees:**
- ✅ No raw eye coordinates stored
- ✅ No raw face images stored
- ✅ No raw audio buffers stored
- ✅ Only region labels, emotion labels, prosody metrics
- ✅ Buffers cleared immediately after processing

### 2. SensorManager
**Location:** `src/sensors/SensorManager.ts`

**Purpose:** Robust sensor initialization with graceful degradation.

**Integration:**
```typescript
import { SensorManager } from './sensors/SensorManager';

// Initialize
const sensorManager = new SensorManager();
const capabilities = await sensorManager.init();

console.log('Available sensors:', capabilities);
// { eye: true, face: true, mic: false, touch: true }

// Subscribe to events
sensorManager.subscribe('eye', (sample) => {
  eyeBuffer.push(sample);
});

sensorManager.subscribe('error', (error) => {
  console.warn('Sensor error:', error);
  // Show non-intrusive notification to adult
});

// Start sensors
await sensorManager.start();

// App degrades gracefully if sensors unavailable
if (!capabilities.mic) {
  console.log('Mic unavailable, skipping voice metrics');
}

// Cleanup
sensorManager.stop();
```

**Features:**
- ✅ Automatic capability detection
- ✅ Permission handling
- ✅ Graceful degradation
- ✅ Structured error reporting
- ✅ Automatic sensor recovery

### 3. Performance Schedulers
**Location:** `src/performance/SamplingScheduler.ts`

**Purpose:** Optimize CPU/battery usage with smart sampling.

**Integration:**
```typescript
import {
  createSensorScheduler,
  createScoringScheduler,
  getBatteryAwareConfig
} from './performance/SamplingScheduler';

// Create schedulers
const config = await getBatteryAwareConfig(); // Auto-adjusts based on battery
const sensorScheduler = createSensorScheduler(config);
const scoringScheduler = createScoringScheduler(config);

// In sensor processing loop
sensorManager.subscribe('eye', (sample) => {
  // Only process if scheduler says so
  if (sensorScheduler.shouldProcessEyeFrame(sample.timestamp)) {
    const features = extractEyeFeatures(sample);
    scoringScheduler.queueMetricUpdate('joint-attention', features);
  }
});

// Batch scoring
scoringScheduler.onBatchScore((updates) => {
  console.log(`Processing ${updates.length} metric updates`);

  // Group by metric
  const grouped = groupBy(updates, 'metricId');

  // Compute scores
  for (const [metricId, data] of Object.entries(grouped)) {
    const score = computeMetric(metricId, data);
    updateUI(metricId, score);
  }
});

// Force flush at end of task
scoringScheduler.flush();
```

**Sampling Rates (Justified):**
- **Eye Tracking:** 10-15 Hz (captures all gaze shifts)
- **Face/Emotion:** 5-10 Hz (emotions change slowly)
- **Audio:** 100-200ms chunks (prosody over syllables)
- **Scoring:** Batched every 500-1000ms (reduces CPU)

### 4. ErrorBus
**Location:** `src/core/ErrorBus.ts`

**Purpose:** Global error handling with graceful degradation.

**Integration:**
```typescript
import { ErrorBus, reportSensorFailure, reportScoringFailure } from './core/ErrorBus';

// Subscribe to errors
const unsubscribe = ErrorBus.subscribe((error) => {
  // Only show to adults, never to children
  if (error.severity === 'error' && isAdultView) {
    showToast({
      message: error.message,
      severity: error.severity
    });
  }
});

// Report sensor failure
try {
  await initCamera();
} catch (error) {
  reportSensorFailure('camera', error, {
    permissionDenied: true
  });
  // Continue without camera
}

// Report scoring failure
try {
  const score = computeMetric(data);
} catch (error) {
  reportScoringFailure('joint-attention', error);
  return 50; // Neutral default
}

// Monitor health
const health = ErrorBus.getErrorCounts();
console.log('Errors:', health); // { info: 0, warn: 2, error: 0 }
```

**Error Handling Rules:**
- **Sensor failures:** severity=`warn`, disable channel, continue
- **Scoring failures:** severity=`error`, skip metric, compute others
- **Config issues:** severity=`warn`, use safe defaults

### 5. Defensive Metrics
**Location:** `src/assessment/defensiveMetrics.ts`

**Purpose:** Production-ready metric calculators that never crash.

**Integration:**
```typescript
import { defensiveMetrics } from './assessment/defensiveMetrics';

// Compute metrics safely
const results = {
  jointAttention: defensiveMetrics.computeJointAttention(sessionData),
  responseReadiness: defensiveMetrics.computeResponseReadiness(sessionData),
  dysregulation: defensiveMetrics.computeDysregulation(sessionData),
  selVocabulary: defensiveMetrics.computeSelVocabulary(sessionData),
  attentionSpan: defensiveMetrics.computeAttentionSpan(sessionData),
  goalDirected: defensiveMetrics.computeGoalDirectedBehavior(sessionData)
};

// All metrics return safe defaults on error
console.log('Joint Attention:', results.jointAttention.score0to100);
// Score is always 0-100, never crashes

// Check if metric had issues
if (results.jointAttention.error) {
  console.warn('Metric error:', results.jointAttention.error);
}

// Check confidence
if (results.jointAttention.confidence < 0.5) {
  console.log('Low confidence, more data needed');
}
```

**Features:**
- ✅ Handles null/undefined inputs
- ✅ Returns neutral score (50) on errors
- ✅ Clamps all outputs to [0, 100]
- ✅ Never throws exceptions
- ✅ Includes confidence scores

### 6. BudgetedApiClient
**Location:** `src/api/BudgetedApiClient.ts`

**Purpose:** Control API costs and prevent runaway usage.

**Integration:**
```typescript
import { createBudgetedClient, DEFAULT_BUDGET } from './api/BudgetedApiClient';

// Create client
const apiClient = createBudgetedClient(DEFAULT_BUDGET);

// Check before calling
if (!apiClient.canCall(500)) {
  console.log('Budget exceeded, using fallback');
  return fallbackResponse;
}

// Make API call
try {
  const response = await apiClient.call(
    'https://api.openai.com/v1/chat/completions',
    { model: 'gpt-4o-mini', messages: [...] },
    500, // Estimated tokens
    { headers: { 'Authorization': `Bearer ${API_KEY}` } }
  );

  console.log('Response:', response);
} catch (error) {
  if (error instanceof BudgetExceededError) {
    console.log('Budget exceeded:', error.budgetType);
    // Use local fallback
  }
}

// Monitor usage
const usage = apiClient.getUsage();
console.log('API Usage:', usage);
// { calls: 5, tokens: 2500, callsRemaining: 15, tokensRemaining: 7500 }

// Reset for new session
apiClient.reset();
```

**Budget Limits:**
- **Default:** 20 calls, 10k tokens per session
- **Strict:** 10 calls, 5k tokens (cost control)
- **Generous:** 50 calls, 50k tokens (research)

### 7. QA Test Harness
**Location:** `src/testing/quickTests.ts`

**Purpose:** Quick sanity checks without full testing framework.

**Usage:**
```typescript
import { runQuickTests } from './testing/quickTests';

// Run tests (browser console or Node.js)
runQuickTests();

// Output:
// ✓ Joint Attention - Empty Session
//   Metric: joint-attention
//   Score: 50/100
//   Confidence: 0.00
//
// ✓ Joint Attention - Good Attention
//   Metric: joint-attention
//   Score: 85/100
//   Confidence: 0.30
//
// ========================================
//   Test Summary
// ========================================
//   Passed: 12/12
//   Failed: 0/12
```

**Tests Include:**
- Empty/null input handling
- Good vs poor attention scenarios
- Fast vs slow response scenarios
- Regulated vs dysregulated emotions
- Rich vs limited vocabulary
- Edge cases and outliers

## Complete Integration Example

```typescript
// src/services/robustSessionManager.ts

import { SensorManager } from '../sensors/SensorManager';
import { createSensorScheduler, createScoringScheduler } from '../performance/SamplingScheduler';
import { processEyeSamples, processAudioFrames, processFaceFrames } from '../privacy/PrivacyGuard';
import { defensiveMetrics } from '../assessment/defensiveMetrics';
import { ErrorBus } from '../core/ErrorBus';
import { db } from './db';

export class RobustSessionManager {
  private sensorManager: SensorManager;
  private sensorScheduler: SensorScheduler;
  private scoringScheduler: ScoringScheduler;
  private eyeBuffer: RawEyeSample[] = [];
  private audioBuffer: RawAudioFrame[] = [];
  private faceBuffer: RawFaceFrame[] = [];

  async initialize() {
    // 1. Setup error handling
    ErrorBus.subscribe((error) => {
      if (error.severity === 'error') {
        this.handleError(error);
      }
    });

    // 2. Initialize sensors
    this.sensorManager = new SensorManager();
    const capabilities = await this.sensorManager.init();
    console.log('Capabilities:', capabilities);

    // 3. Setup schedulers
    const config = await getBatteryAwareConfig();
    this.sensorScheduler = createSensorScheduler(config);
    this.scoringScheduler = createScoringScheduler(config);

    // 4. Subscribe to sensor events
    this.sensorManager.subscribe('eye', (sample) => {
      this.eyeBuffer.push(sample);

      // Process when buffer is full or scheduler says so
      if (this.sensorScheduler.shouldProcessEyeFrame(sample.timestamp) ||
          this.eyeBuffer.length > 100) {
        this.processEyeData();
      }
    });

    this.sensorManager.subscribe('audio', (frame) => {
      this.audioBuffer.push(frame);

      if (this.sensorScheduler.shouldProcessAudioChunk(frame.timestamp)) {
        this.processAudioData();
      }
    });

    this.sensorManager.subscribe('face', (frame) => {
      this.faceBuffer.push(frame);

      if (this.sensorScheduler.shouldProcessFaceFrame(frame.timestamp)) {
        this.processFaceData();
      }
    });

    // 5. Setup batch scoring
    this.scoringScheduler.onBatchScore((updates) => {
      this.computeMetrics(updates);
    });
  }

  async start() {
    await this.sensorManager.start();
  }

  private processEyeData() {
    // Extract features (NO raw data stored!)
    const gazeSummaries = processEyeSamples(this.eyeBuffer);

    // Queue for scoring
    for (const summary of gazeSummaries) {
      this.scoringScheduler.queueMetricUpdate('gaze-attention', summary);
    }

    // Buffer already cleared by processEyeSamples
  }

  private processAudioData() {
    const prosody = processAudioFrames(this.audioBuffer);
    if (prosody) {
      this.scoringScheduler.queueMetricUpdate('voice-prosody', prosody);
    }
  }

  private processFaceData() {
    const emotions = processFaceFrames(this.faceBuffer);
    if (emotions) {
      this.scoringScheduler.queueMetricUpdate('emotion-regulation', emotions);
    }
  }

  private computeMetrics(updates: MetricUpdate[]) {
    // Build session data from updates
    const sessionData = this.buildSessionData(updates);

    // Compute all metrics safely
    const scores = {
      jointAttention: defensiveMetrics.computeJointAttention(sessionData),
      responseReadiness: defensiveMetrics.computeResponseReadiness(sessionData),
      dysregulation: defensiveMetrics.computeDysregulation(sessionData),
      selVocabulary: defensiveMetrics.computeSelVocabulary(sessionData)
    };

    // Update UI
    this.updateDashboard(scores);
  }

  async stop() {
    // Force final scoring
    this.scoringScheduler.flush();

    // Stop sensors
    this.sensorManager.stop();

    // Cleanup
    this.scoringScheduler.destroy();
  }
}
```

## Testing

Run quick tests:
```bash
# Browser console
import { runQuickTests } from './testing/quickTests';
runQuickTests();

# Node.js (with ts-node)
npx ts-node src/testing/quickTests.ts
```

## Best Practices

1. **Privacy First:** Never store raw sensor data
2. **Defensive Programming:** All metrics handle null/empty inputs
3. **Graceful Degradation:** App works even if sensors fail
4. **Performance:** Use battery-aware sampling rates
5. **Error Handling:** Report to ErrorBus, never crash
6. **Budget Control:** Monitor API costs
7. **Testing:** Run quick tests before production

## Migration Guide

### Existing Code → TypeScript Layer

**Before:**
```javascript
// Old: Direct sensor access, no privacy guarantees
const eyeData = await eyeTracker.getData();
await db.add('sessions', { eyeData }); // ❌ Stores raw coordinates!
```

**After:**
```typescript
// New: Privacy-safe processing
const eyeBuffer = await eyeTracker.getRawSamples();
const gazeSummaries = processEyeSamples(eyeBuffer); // Auto-clears
await db.add('sessions', { gaze: gazeSummaries }); // ✅ Only regions/scores
```

**Before:**
```javascript
// Old: Metrics crash on bad input
function computeScore(data) {
  return data.fixations.reduce((a, b) => a + b.duration) / data.fixations.length;
  // ❌ Crashes if data.fixations is undefined!
}
```

**After:**
```typescript
// New: Defensive metrics
const result = defensiveMetrics.computeJointAttention(data);
// ✅ Always returns valid score, never crashes
if (result.error) {
  console.warn('Metric error:', result.error);
}
```

## Troubleshooting

**Q: Sensors not initializing?**
A: Check `SensorManager.getCapabilities()` to see what failed. Common issues:
- Camera permission denied → Check browser permissions
- Device not found → No webcam/mic available
- API not supported → Older browser

**Q: High CPU usage?**
A: Adjust sampling rates:
```typescript
sensorScheduler.updateConfig({
  eyeHz: 8,      // Reduce from 12 Hz
  faceHz: 5,     // Reduce from 8 Hz
  scoringDebounceMs: 1500  // Increase from 750ms
});
```

**Q: Budget exceeded errors?**
A: Check API usage:
```typescript
const usage = apiClient.getUsage();
console.log('Calls:', usage.calls, '/', apiClient.config.maxCallsPerSession);

// Increase budget or use fallbacks
apiClient.updateConfig({ maxCallsPerSession: 50 });
```

## Support

For questions or issues:
1. Check ErrorBus history: `ErrorBus.getHistory()`
2. Run quick tests: `runQuickTests()`
3. Review console logs for privacy violations
4. Check sensor capabilities: `sensorManager.getCapabilities()`
