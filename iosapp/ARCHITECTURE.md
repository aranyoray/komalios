# Komal - Architecture Documentation

**Knowledge-Oriented Mental-Health & Affective Learning**

Hyper-personalized virtual humans for child therapy and social-emotional learning (SEL) for ages 3.5-15.

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Komal Mobile/Web App                      │
│                     (React + Vite + Material-UI)                 │
└─────────────────────────────────────────────────────────────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                        │                        │
        ▼                        ▼                        ▼
┌───────────────┐      ┌──────────────────┐    ┌─────────────────┐
│  Client-Side  │      │   Virtual Avatar │    │  Authentication │
│  ML Tracking  │      │     Engine       │    │   & Profiles    │
└───────────────┘      └──────────────────┘    └─────────────────┘
        │                        │                        │
        │                        │                        │
        ▼                        ▼                        ▼
┌──────────────────────────────────────────────────────────────────┐
│              Local Storage + IndexedDB (Offline-First)           │
│  - Session Data    - User Profiles    - Tracking Metrics         │
└──────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │    Backend API (AWS)    │
                    │  - Auth Service         │
                    │  - Data Sync            │
                    │  - Report Generation    │
                    └─────────────────────────┘
```

## Core Components

### 1. Authentication & Profile Management

**User Types:**
- **Learner Profile** (Child): No PIN on quick access, age-appropriate UI
- **Parent/Guardian Profile**: PIN/Face ID protected, full access to analytics

**Sign-In Methods:**
- Phone number (SMS OTP)
- Email + Password
- Apple Sign-In
- Guest mode (limited features)

**Languages:** English, Bengali, Hindi (hardcoded)

### 2. Client-Side ML Tracking System

All tracking happens on-device for privacy and low latency.

```
┌─────────────────────────────────────────────────────────────────┐
│                     ML Tracking Pipeline                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌─────────────────┐  │
│  │ Eye Tracking │    │ Micro-Expr   │    │ Touch Tracking  │  │
│  │ (Webcam ML)  │    │ (Face ML)    │    │ (Touch Events)  │  │
│  └──────┬───────┘    └──────┬───────┘    └────────┬────────┘  │
│         │                    │                     │            │
│         └────────────────────┼─────────────────────┘            │
│                              ▼                                   │
│                    ┌──────────────────┐                         │
│                    │  Voice Tracking  │                         │
│                    │  (Web Audio API) │                         │
│                    └─────────┬────────┘                         │
│                              │                                   │
│         ┌────────────────────┴────────────────────┐            │
│         ▼                                          ▼            │
│  ┌─────────────┐                          ┌──────────────┐    │
│  │  Analytics  │                          │   Session    │    │
│  │   Engine    │                          │   Storage    │    │
│  └─────────────┘                          └──────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

#### 2.1 Eye Tracking

**Purpose:** Measure attention, concentration, social gaze, exploration patterns

**Metrics:**
- **Attention Score**: % of time fixated on relevant content
- **Concentration Stability**: Micro-saccade frequency
- **Social Gaze Index**: Eye contact with avatar face/eyes
- **Exploration vs Avoidance Ratio**: Comfort with stimuli
- **Gaze Patterns**: Heatmaps, fixation duration

**Technology:**
- WebGazer.js or custom lightweight model
- Uses existing webcam + face detection
- 5-10 FPS for battery efficiency

#### 2.2 Micro-Expression Analysis

**Purpose:** Emotional regulation, affect diversity, empathy response

**Metrics:**
- **Affect Diversity Score**: Range of detectable emotions
- **Positive-Affect Activation**: Joy, pride during success
- **Frustration Tolerance Index**: Recovery time from negative affect
- **Empathy Response**: Reaction to avatar distress
- **Emotion Timeline**: Frame-by-frame emotion tracking

**Technology:**
- Lightweight facial expression recognition model
- 7 basic emotions: Happy, Sad, Angry, Fearful, Surprised, Disgusted, Neutral
- Uses existing face detection infrastructure

#### 2.3 Touch Tracking

**Purpose:** Motor intent, frustration indicators, interaction patterns

**Metrics:**
- **Goal-Directed Accuracy**: Successful taps vs random tapping
- **Hesitation Taps**: Anxiety, doubt, compulsive checking
- **Touch Pressure** (if supported): Impulsivity vs control
- **Self-Soothing Gestures**: Stress-reduction behaviors
- **Touch Heatmaps**: Where child interacts most

**Technology:**
- Touch event listeners (touchstart, touchmove, touchend)
- Pressure sensitivity (3D Touch on iOS)
- Pattern analysis algorithms

#### 2.4 Voice Tracking

**Purpose:** Communication development, emotional state, engagement

**Metrics:**
- **Vocal Activity**: Speaking duration, pauses
- **Pitch Variation**: Emotional arousal
- **Speech Rate**: Confidence, anxiety
- **Volume Patterns**: Assertiveness
- **Vocabulary Diversity** (basic): Unique words used

**Technology:**
- Web Audio API for audio analysis
- Speech Recognition API for transcription (optional)
- Pitch detection algorithms
- No server upload - all local processing

### 3. Virtual Avatar System

**Avatar Types:**
- Animal avatars (for younger children, comfort)
- Human avatars (for social skills practice)

**Avatar Capabilities:**
- **Emotional expressions**: Mirror child's emotions or teach regulation
- **Speech synthesis**: Text-to-speech with emotion
- **Gesture animations**: Pointing, waving, celebrating
- **Interactive responses**: React to child's actions and emotions

**Technology:**
- 2D/3D animated sprites or models
- Ready Player Me API (optional for custom avatars)
- React Three Fiber for 3D (if needed)
- Framer Motion for 2D animations

### 4. SEL Framework (Harvard CASEL)

**Five Core Domains:**

1. **Self-Awareness**
   - Recognizing emotions
   - Identifying triggers
   - Self-assessment

2. **Self-Management**
   - Emotion regulation
   - Impulse control
   - Coping strategies

3. **Social Awareness**
   - Empathy
   - Perspective-taking
   - Recognizing social cues

4. **Relationship Skills**
   - Communication
   - Cooperation
   - Conflict resolution

5. **Responsible Decision-Making**
   - Problem-solving
   - Evaluating consequences
   - Ethical reasoning

### 5. Analytics & Reporting System

**Session Tracking:**
```javascript
{
  sessionId: "uuid",
  learnerId: "uuid",
  startTime: timestamp,
  endTime: timestamp,
  focusArea: ["Social Skills", "Emotional Intelligence"],
  avatarMode: "Animal",

  // Tracking data
  eyeTracking: {
    attentionScore: 72,
    concentrationStability: 0.85,
    socialGazeIndex: 0.68,
    explorationAvoidanceRatio: 0.45
  },

  microExpressions: {
    affectDiversityScore: 6,
    positiveAffectActivation: 0.72,
    frustrationToleranceIndex: 0.65,
    empathyResponse: 0.58,
    emotionTimeline: [...]
  },

  touchTracking: {
    goalDirectedAccuracy: 0.85,
    hesitationTaps: 12,
    touchPressure: {...},
    touchHeatmap: [...]
  },

  voiceTracking: {
    vocalActivity: 0.45,
    pitchVariation: {...},
    speechRate: 120, // words per minute
    volumePatterns: [...]
  },

  // SEL progress
  selMetrics: {
    selfAwareness: 7.2,
    selfManagement: 6.8,
    socialAwareness: 7.5,
    relationshipSkills: 6.9,
    responsibleDecisionMaking: 7.0
  },

  // Performance
  tasksCompleted: 8,
  tasksTotal: 10,
  engagementQuality: 8.5,
  keySkillPracticed: "Managing frustration calmly"
}
```

**Report Types:**

1. **Session Snapshot** (Immediate, after each session)
   - Quick metrics
   - Highlights
   - Next tiny goal

2. **Weekly Progress Report**
   - Trends over last 7 days
   - Improvement areas
   - Home practice suggestions

3. **Extended Progress Report** (Monthly)
   - Detailed analytics across all domains
   - Clinician review zone
   - Escalation flags

### 6. Data Storage Strategy

**Offline-First Architecture:**

```
┌─────────────────────────────────────────────────────────┐
│                    Browser Storage                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  localStorage:                                          │
│  - User preferences                                     │
│  - Last login                                           │
│  - UI state                                             │
│                                                         │
│  IndexedDB:                                             │
│  - User profiles (encrypted)                            │
│  - Session data (pending sync)                          │
│  - Tracking metrics                                     │
│  - ML models cache                                      │
│                                                         │
│  SessionStorage:                                        │
│  - Current session state                                │
│  - Temporary tracking data                              │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼ (Background sync when online)
                    ┌──────────┐
                    │   AWS    │
                    │ Backend  │
                    └──────────┘
```

## Technology Stack

### Frontend
- **Framework**: React 19 + Vite
- **UI Library**: Material-UI v7
- **Animations**: Framer Motion
- **Routing**: React Router v7
- **State Management**: React Context + Hooks
- **ML Runtime**: ONNX Runtime Web
- **Avatar Rendering**: Canvas API / React Three Fiber (optional)

### Client-Side ML
- **Face Detection**: Browser Face Detection API + fallback
- **Expression Recognition**: Custom lightweight ONNX model
- **Eye Tracking**: WebGazer.js or custom model
- **Voice Analysis**: Web Audio API
- **Touch Analytics**: Custom algorithms

### Backend (AWS)
- **Auth**: AWS Cognito
- **API**: AWS API Gateway + Lambda
- **Database**: DynamoDB
- **Storage**: S3 (for avatars, assets)
- **Analytics**: AWS Kinesis (optional)
- **Email/SMS**: SES + SNS

### Mobile
- **iOS**: Safari WebView with native permissions
- **Android**: Chrome WebView
- **Progressive Web App**: Service Workers for offline

## Security & Privacy

### Data Protection
- ✅ **All tracking happens client-side** - no video/audio sent to server
- ✅ **Encrypted storage** for sensitive data
- ✅ **PIN/Face ID** for parent access
- ✅ **COPPA compliant** - minimal data collection
- ✅ **GDPR ready** - data export, deletion

### Permission Management
- Camera: Required for eye tracking, micro-expressions
- Microphone: Required for voice tracking
- Storage: Required for offline functionality
- Notifications: Optional for reminders

## Performance Targets

### Loading
- First Contentful Paint: < 1.5s
- Time to Interactive: < 3.5s
- ML Model Load: < 2s

### Runtime
- Eye Tracking: 5-10 FPS
- Face Detection: 5-10 FPS
- Touch Tracking: Real-time (60 FPS)
- Voice Analysis: Real-time
- Battery Impact: < 5% per 30min session

### Storage
- App Size: < 10 MB
- ML Models: < 50 MB total
- Session Data: ~500 KB per session
- IndexedDB: < 100 MB total

## Development Phases

### Phase 1: Core Infrastructure ✅
- [x] ML tracking foundation
- [x] Battery-aware throttling
- [x] Model caching
- [ ] Authentication system
- [ ] Profile management

### Phase 2: Tracking Systems
- [ ] Eye tracking implementation
- [ ] Micro-expression analysis
- [ ] Touch tracking analytics
- [ ] Voice tracking analytics
- [ ] Session recording

### Phase 3: Avatar & Interaction
- [ ] Virtual avatar system
- [ ] Avatar animations
- [ ] Speech synthesis
- [ ] Interactive games/modules

### Phase 4: Analytics & Reports
- [ ] Session analytics engine
- [ ] Parent dashboard
- [ ] Report generation
- [ ] Email reports
- [ ] Data visualization

### Phase 5: Backend Integration
- [ ] AWS setup
- [ ] Auth integration
- [ ] Data sync
- [ ] Cloud backup

## File Structure

```
komal/
├── public/
│   ├── models/           # ML models
│   ├── avatars/          # Avatar assets
│   └── assets/           # Images, sounds
├── src/
│   ├── auth/             # Authentication
│   ├── components/
│   │   ├── avatar/       # Virtual avatar
│   │   ├── common/       # Shared components
│   │   ├── dashboard/    # Parent dashboard
│   │   └── tracking/     # Tracking displays
│   ├── contexts/         # React contexts
│   ├── hooks/
│   │   ├── tracking/     # Tracking hooks
│   │   ├── useAuth.js
│   │   └── useProfile.js
│   ├── ml/               # ML infrastructure
│   ├── pages/
│   │   ├── Auth/
│   │   ├── Learner/
│   │   └── Parent/
│   ├── services/         # API services
│   ├── tracking/         # Tracking engines
│   ├── utils/
│   └── workers/          # Web Workers
├── ARCHITECTURE.md       # This file
├── ML_README.md          # ML documentation
└── README.md             # Project overview
```

## API Design

### Authentication
```
POST /auth/signup          - Create account
POST /auth/login           - Login
POST /auth/verify-otp      - Verify phone OTP
POST /auth/refresh-token   - Refresh JWT
POST /auth/logout          - Logout
```

### Profiles
```
GET  /profiles             - List all profiles
POST /profiles             - Create profile
GET  /profiles/:id         - Get profile
PUT  /profiles/:id         - Update profile
DEL  /profiles/:id         - Delete profile
```

### Sessions
```
GET  /sessions             - List sessions
POST /sessions             - Create session
GET  /sessions/:id         - Get session
PUT  /sessions/:id         - Update session
POST /sessions/:id/complete - Complete session
```

### Analytics
```
GET  /analytics/learner/:id        - Learner analytics
GET  /analytics/learner/:id/report - Generate report
POST /analytics/email-report       - Email report
```

## Deployment

### Development
```bash
npm install
npm run dev
```

### Production Build
```bash
npm run build
# Outputs to dist/
```

### Hosting Options
- Vercel (recommended for React)
- Netlify
- AWS Amplify
- AWS S3 + CloudFront

## Next Steps for Developer

1. Review this architecture document
2. Set up AWS account and services
3. Implement authentication system
4. Build profile management
5. Integrate tracking systems
6. Develop avatar system
7. Create dashboard components
8. Test on real devices (iOS/Android)
9. Deploy to staging
10. User testing and iteration

## Questions for Product Team

1. Which avatar style preferred? (2D sprite / 3D model / Ready Player Me)
2. Backend preference? (AWS / Firebase / Supabase)
3. Real-time requirements? (WebSocket for live monitoring)
4. Multi-device support? (Sync across phone/tablet/web)
5. Offline-first priority? (How long should app work offline)
