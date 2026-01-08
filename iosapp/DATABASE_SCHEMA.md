# Komal - Database Schema

## Overview

Offline-first design with IndexedDB for local storage and AWS DynamoDB for cloud backup.

## IndexedDB Schema (Client-Side)

### Store: `users`
```javascript
{
  id: "uuid",
  phoneNumber: "+1234567890",
  email: "parent@example.com",
  authMethod: "phone|email|apple",
  createdAt: timestamp,
  lastLogin: timestamp,
  language: "en|hi|bn",
  pin: "hashed-pin", // For parent access
  faceIdEnabled: boolean
}
```

### Store: `learners`
```javascript
{
  id: "uuid",
  userId: "parent-uuid", // Reference to parent
  name: "Child Name",
  dateOfBirth: "YYYY-MM-DD",
  age: 7, // Calculated
  gender: "male|female|other|prefer-not-to-say",

  // Focus areas (multi-select)
  focusAreas: [
    "social-skills",
    "language-skills",
    "cognitive-development",
    "emotional-intelligence",
    "life-skills"
  ],

  // Sensitivity settings
  settings: {
    soundVolume: 0.7, // 0.0 - 1.0
    animationLevel: "off|medium|high",
    preferredAvatar: "animal|human",
    colorScheme: "default|high-contrast"
  },

  // Permissions granted
  permissions: {
    camera: boolean,
    microphone: boolean,
    storage: boolean
  },

  pin: "4-digit-pin", // Optional, for multi-learner households
  profileImage: "base64-image",

  createdAt: timestamp,
  updatedAt: timestamp,
  isActive: boolean
}
```

### Store: `sessions`
```javascript
{
  id: "uuid",
  learnerId: "uuid",

  // Session metadata
  startTime: timestamp,
  endTime: timestamp,
  duration: 1234, // seconds
  focusArea: "social-skills",
  avatarMode: "animal|human",
  avatarName: "Friendly Bear",

  // Tasks/activities
  tasksCompleted: 8,
  tasksTotal: 10,
  activitiesLog: [
    {
      activityId: "emotion-recognition-1",
      activityName: "Emotion Recognition",
      startTime: timestamp,
      endTime: timestamp,
      score: 0.85,
      attempts: 2,
      completed: true
    }
  ],

  // Tracking data
  eyeTracking: {
    attentionScore: 72, // 0-100
    concentrationStability: 0.85, // 0-1
    socialGazeIndex: 0.68, // 0-1
    explorationAvoidanceRatio: 0.45, // 0-1
    avgFixationDuration: 2.3, // seconds
    gazeHeatmap: [...], // Coordinate data
    gazeAversions: [
      { timestamp: 123, scene: "avatar-distressed", duration: 2.1 }
    ],
    metrics: {
      totalFixations: 156,
      avgSaccadeSpeed: 45.2,
      blinkRate: 18 // per minute
    }
  },

  microExpressions: {
    affectDiversityScore: 6, // 0-7 (7 emotions)
    positiveAffectActivation: 0.72, // 0-1
    frustrationToleranceIndex: 0.65, // 0-1
    empathyResponse: 0.58, // 0-1

    emotionTimeline: [
      { timestamp: 123, emotion: "happy", confidence: 0.85 },
      { timestamp: 456, emotion: "neutral", confidence: 0.92 }
    ],

    emotionDistribution: {
      happy: 0.35,
      sad: 0.05,
      angry: 0.02,
      fearful: 0.08,
      surprised: 0.15,
      disgusted: 0.01,
      neutral: 0.34
    },

    frustrationEpisodes: [
      {
        timestamp: 789,
        duration: 5.2, // seconds
        triggerActivity: "puzzle-hard",
        recoveryTime: 3.1 // seconds to return to neutral/positive
      }
    ],

    positiveExpressions: 45, // count
    negativeExpressions: 12 // count
  },

  touchTracking: {
    goalDirectedAccuracy: 0.85, // 0-1
    hesitationTaps: 12, // count
    totalTaps: 142,
    averageTapDuration: 0.25, // seconds

    touchPressure: {
      avg: 0.6, // 0-1 (if supported)
      max: 0.95,
      variability: 0.23
    },

    touchHeatmap: [
      { x: 100, y: 200, count: 5 },
      { x: 150, y: 250, count: 8 }
    ],

    selfSoothingGestures: [
      { timestamp: 234, type: "repeated-tap", count: 5 }
    ],

    patterns: {
      accurateTouches: 121,
      missedTouches: 8,
      accidentalTouches: 13,
      hesitantTouches: 12,
      forcefulTouches: 6
    }
  },

  voiceTracking: {
    vocalActivity: 0.45, // 0-1 (% of session)
    totalSpeechDuration: 234, // seconds

    pitchVariation: {
      avg: 220, // Hz
      min: 180,
      max: 280,
      stdDev: 25
    },

    speechRate: 120, // words per minute
    pauseDuration: {
      avg: 1.2, // seconds
      max: 5.6
    },

    volumePatterns: {
      avg: 0.65, // 0-1
      variability: 0.18
    },

    vocalizationTypes: {
      words: 85,
      sounds: 12, // non-word vocalizations
      silence: 0.55 // % of session
    },

    confidence: 0.72, // Derived from speech characteristics
    hesitations: 8 // "um", "uh", long pauses before speaking
  },

  // Response patterns
  responsePatterns: {
    initiationLatency: {
      avg: 2.3, // seconds
      min: 0.5,
      max: 8.2
    },

    retryCount: {
      total: 15,
      successful: 12,
      abandoned: 3
    },

    conversationalTurnTaking: 0.68, // 0-1 score

    errorCorrection: {
      selfCorrected: 8,
      needsPrompt: 4,
      gaveUp: 2
    },

    patterns: {
      freezeMode: 2, // Long latency, no retry
      impulsiveGuessing: 3, // Short latency, many retries
      healthyPersistence: 10 // Moderate latency, reasonable retries
    }
  },

  // SEL metrics (Harvard CASEL framework)
  selMetrics: {
    selfAwareness: {
      score: 7.2, // 0-10
      observations: [
        "Correctly identified own emotion 6/8 times",
        "Recognized trigger pattern for frustration"
      ]
    },

    selfManagement: {
      score: 6.8,
      observations: [
        "Used breathing technique when frustrated",
        "Took breaks appropriately"
      ]
    },

    socialAwareness: {
      score: 7.5,
      observations: [
        "Recognized avatar's distress",
        "Responded empathetically to scenarios"
      ]
    },

    relationshipSkills: {
      score: 6.9,
      observations: [
        "Initiated conversation with avatar",
        "Turn-taking improved"
      ]
    },

    responsibleDecisionMaking: {
      score: 7.0,
      observations: [
        "Considered consequences in choice game",
        "Made ethical choices consistently"
      ]
    }
  },

  // Engagement quality
  engagementQuality: 8.5, // 0-10 overall score
  keySkillPracticed: "Managing frustration calmly",

  // Highlights and notes
  highlights: [
    "Started conversation with avatar without prompt 🎉",
    "Stayed focused even during harder activities",
    "Great recovery after challenges"
  ],

  concerns: [
    "Gaze aversion during conflict scenarios",
    "Long pause before responding to social questions"
  ],

  // Mood tracking
  moodChecks: [
    { timestamp: 0, mood: "neutral", emoji: "😐" },
    { timestamp: 600, mood: "happy", emoji: "😊" },
    { timestamp: 1200, mood: "happy", emoji: "😃" }
  ],

  // Technical metadata
  deviceInfo: {
    platform: "iOS|Android|Web",
    browserAgent: "...",
    screenSize: "390x844",
    batteryLevel: 0.65 // at session start
  },

  // Sync status
  syncedToCloud: boolean,
  lastSyncAttempt: timestamp,

  createdAt: timestamp,
  updatedAt: timestamp
}
```

### Store: `analytics`
```javascript
{
  id: "uuid",
  learnerId: "uuid",

  // Time range
  startDate: "YYYY-MM-DD",
  endDate: "YYYY-MM-DD",

  // Aggregated metrics
  totalSessions: 12,
  totalDuration: 14400, // seconds
  avgSessionDuration: 1200,

  // Trends (compared to previous period)
  trends: {
    attentionScore: { current: 72, previous: 65, change: +7 },
    engagementQuality: { current: 8.5, previous: 7.8, change: +0.7 },
    frustrationEpisodes: { current: 3, previous: 5, change: -2 },
    positiveExpressions: { current: 45, previous: 38, change: +7 }
  },

  // SEL progress
  selProgress: {
    selfAwareness: [6.5, 6.8, 7.0, 7.2], // Weekly scores
    selfManagement: [6.0, 6.3, 6.5, 6.8],
    socialAwareness: [7.0, 7.2, 7.3, 7.5],
    relationshipSkills: [6.2, 6.5, 6.7, 6.9],
    responsibleDecisionMaking: [6.5, 6.7, 6.9, 7.0]
  },

  // Improvement areas
  strengths: [
    "Social awareness showing consistent growth",
    "Emotional regulation improving steadily"
  ],

  challenges: [
    "Response initiation still shows hesitation",
    "Attention span shorter during abstract tasks"
  ],

  // Recommendations
  homePractice: [
    "Ask: 'What helped you keep going when it got hard?'",
    "Practice deep breathing together before bedtime"
  ],

  nextGoals: [
    "Maintain eye contact during conversation moments",
    "Reduce initiation latency by 1 second"
  ],

  // Clinician flags (auto-generated)
  flags: {
    escalate: false,
    reasons: [],

    monitor: true,
    monitorReasons: [
      "Attention drops during social scenarios - track for 2 more sessions"
    ]
  },

  createdAt: timestamp
}
```

### Store: `mlModels`
```javascript
{
  name: "face-expression-v1",
  version: "1.0.0",
  url: "/models/face-expression.onnx",
  size: 5242880, // bytes

  metadata: {
    inputShape: [1, 3, 224, 224],
    outputShape: [1, 7],
    labels: ["angry", "disgust", "fear", "happy", "sad", "surprise", "neutral"]
  },

  cached: true,
  lastUsed: timestamp,
  downloadedAt: timestamp
}
```

## AWS DynamoDB Schema (Cloud)

### Table: `Users`
```
Partition Key: userId (String)

Attributes:
- phoneNumber
- email
- authMethod
- createdAt
- lastLogin
- language
- subscriptionStatus
- subscriptionTier
```

### Table: `Learners`
```
Partition Key: userId (String)
Sort Key: learnerId (String)

Attributes:
- name
- dateOfBirth
- gender
- focusAreas (List)
- settings (Map)
- permissions (Map)
- createdAt
- updatedAt
- isActive
```

### Table: `Sessions`
```
Partition Key: learnerId (String)
Sort Key: sessionId (String)

GSI: sessionDate-index (for date range queries)
- Partition Key: learnerId
- Sort Key: startTime

Attributes:
- All session data (see IndexedDB schema)
- Compressed tracking data for storage efficiency
```

### Table: `Analytics`
```
Partition Key: learnerId (String)
Sort Key: analyticsId (String) // Format: YYYY-MM-DD-weekly|monthly

Attributes:
- All analytics data (see IndexedDB schema)
```

## Data Flow

```
┌─────────────────────┐
│   React Component   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   React Hook        │
│   (useSession)      │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   IndexedDB Service │
│   (Local Storage)   │
└──────────┬──────────┘
           │
           ▼ (Background sync when online)
┌─────────────────────┐
│   API Service       │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   AWS DynamoDB      │
│   (Cloud Backup)    │
└─────────────────────┘
```

## Indexing Strategy

### IndexedDB Indexes

**learners:**
- `userId` - For querying all learners of a parent
- `isActive` - For filtering active learners

**sessions:**
- `learnerId` - For querying all sessions of a learner
- `startTime` - For sorting by date
- `focusArea` - For filtering by focus area
- `syncedToCloud` - For finding unsynced sessions

**analytics:**
- `learnerId` - For querying learner analytics
- `startDate, endDate` - For date range queries

### DynamoDB Indexes

**GSI: sessionDate-index**
- Query sessions by learner and date range
- Efficient for analytics queries

**GSI: userId-createdAt-index**
- Query learners by parent and creation date

## Data Retention

- **Sessions**: Keep locally for 30 days, cloud indefinitely
- **Analytics**: Keep locally for 90 days, cloud indefinitely
- **ML Models**: Cache until new version available
- **User Data**: Keep until account deletion

## Privacy Considerations

1. **No raw tracking data uploaded**
   - Only aggregated metrics sent to cloud
   - Raw video/audio never leaves device

2. **Encryption**
   - IndexedDB encrypted with Web Crypto API
   - Transit encryption (HTTPS)
   - At-rest encryption (AWS)

3. **Data minimization**
   - Only collect necessary metrics
   - Anonymous session IDs
   - No personally identifiable information in tracking data

4. **User control**
   - Export all data (GDPR)
   - Delete all data (GDPR)
   - Opt-out of cloud sync

## Backup & Sync Strategy

```javascript
// Sync priority queue
{
  high: ["session-completion", "profile-update"],
  medium: ["analytics-update"],
  low: ["settings-change"]
}

// Sync rules
- Sync on WiFi by default
- Allow cellular with user permission
- Retry failed syncs with exponential backoff
- Queue operations offline
- Conflict resolution: server wins for profiles, merge for sessions
```
