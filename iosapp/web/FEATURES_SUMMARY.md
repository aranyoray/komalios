# Komal Web Application - Features Summary

## Overview
Komal is a **Knowledge-Oriented Mental-Health & Affective Learning** platform - a therapeutic SEL (Social-Emotional Learning) application for children ages 3.5-15. The web application is built with React 19, Material-UI v7, and uses Capacitor for mobile deployment.

---

## 🎯 Core Features

### 1. Authentication & User Management
- **Multi-Auth Support**: Phone (OTP), Email, Apple Sign-In, Guest mode
- **Multi-Language**: English, Hindi, Bengali with i18n support
- **Profile Management**: 
  - Create learner profiles with age, gender, focus areas
  - Multiple profiles per parent account
  - Profile switching
  - Parent PIN protection (4-digit PIN, default: 1234)
- **Session Management**: Auto-login within 20 minutes
- **Password Reset**: Email-based password reset flow

### 2. Learner Interface (`/learner`)
- **Home Page Features**:
  - Emoji mood checker (pre-session emotional check-in)
  - Virtual avatar with animated states (idle, talking, happy, thinking, encouraging, celebrating)
  - Text-to-speech using ElevenLabs API
  - Focus area selection (5 areas: Social Skills, Emotion Intelligence, Thought Expression, Cognitive Growth, Life Skills)
  - Mute/unmute audio controls
  - Parent mode access (PIN-protected)
  - Personalized greeting based on profile name

### 3. Session Flow (`/session/:learnerId`)
A comprehensive 15-minute guided therapy session with multiple phases:

#### Phase 1: Face Detection Setup
- Camera permission handling (native & web)
- Face detection using MediaPipe Face Mesh
- Visual guide overlay for face positioning
- Confidence threshold validation
- Stable detection requirement (2 seconds)

#### Phase 2: Eye Calibration
- 9-point calibration grid
- Gaze tracking setup
- Screen dimension configuration
- Calibration data storage

#### Phase 3: Pre-Task Check-In
- Emoji-based emotional check-in
- Multiple check-in types:
  - `feeling_pre_task`: Initial mood assessment
  - `motivation_check`: Motivation level
- Age-band specific prompts (6-10, 11-15, etc.)

#### Phase 4: Activity Phase
- **Storytelling Activities**: 3 pre-defined story activities
  - "The Friendly Forest" - Joint attention, emotion identification
  - "Ocean Adventure" - Turn-taking, working memory
  - "Space Explorer" - Conversation initiation, problem-solving
- **Real-time Tracking**:
  - Eye tracking (attention score, gaze heatmaps)
  - Micro-expression analysis (7 emotions)
  - Touch tracking (goal-directed accuracy)
  - Voice tracking (latency, confidence)
- **Metrics Display**:
  - Attention score (0-100%)
  - Engagement score (0-100%)
  - Current emotion detection
- **Progress Tracking**: Timer, activity completion, task progression

#### Phase 5: Post-Task Check-In
- Post-session emotional assessment
- Check-in types:
  - `difficulty_post_task`: Task difficulty perception
  - `feeling_pre_task`: Post-session mood
  - `understanding_check`: Comprehension check

#### Phase 6: Session Report
- **Session Summary**:
  - Final averaged attention score (session average)
  - Duration
  - Activities completed
  - Engagement quality (0-10 scale)
- **Mood Comparison**: Before vs. after session
- **AI-Generated Insights**: Concise report with highlights
- **Actions**: View full report, Done button

### 4. Parent Dashboard (`/parent/dashboard`)
- **PIN Protection**: 4-digit PIN required (stored per user)
- **Quick Stats Cards**:
  - Sessions this week
  - Average attention score
  - Day streak
  - Improvement trend
- **Latest Session Report**: 
  - Concise session report with AI-enhanced insights
  - Fetches from database with Gemini AI enhancement
  - Fallback to mock data if no sessions found
- **Full Report Dashboard**:
  - Comprehensive analytics
  - Progress trends
  - Domain scores
  - Historical data visualization

### 5. Reports (`/parent/reports`)
- **Report Types**:
  - Concise Session Report (after each session)
  - Extended Monthly Report (detailed analytics)
  - Weekly Progress Report (trends over 7 days)
- **Report Components**:
  - Domain scores visualization
  - Progress trend charts
  - Eye-tracking patterns
  - Micro-expression analysis
  - Touch and voice metrics
  - SEL progress across 5 domains

---

## 🔬 Tracking & Analytics Features

### Eye Tracking (`src/tracking/eyeTracking.js`)
- **Attention Score**: Percentage of time fixating on relevant content (0-100%)
- **Concentration Stability**: Saccade frequency analysis
- **Social Gaze Index**: Eye contact with avatar
- **Gaze Heatmaps**: Visual attention patterns
- **Fixations & Saccades**: Advanced eye movement tracking
- **Calibration Status**: 9-point calibration system

### Micro-Expression Analysis (`src/hooks/useFaceDetection.js`)
- **7 Emotion Detection**: Happy, Sad, Angry, Fearful, Surprised, Disgusted, Neutral
- **Engagement Score**: Calculated from micro-expressions (0-1, converted to 0-100)
- **Affect Diversity**: Range of emotions shown
- **Frustration Tolerance**: Recovery time from negative affect
- **Emotion Timeline**: Temporal emotion tracking

### Touch Tracking (`src/tracking/touchTracking.js`)
- **Goal-Directed Accuracy**: Successful vs random taps
- **Hesitation Detection**: Anxiety, compulsive checking
- **Motor Planning**: Touch pattern analysis
- **Response Time**: Touch latency measurement

### Voice Tracking (`src/tracking/voiceTracking.js`)
- **Voice Latency**: Response time measurement
- **Confidence Analysis**: Voice tone and confidence
- **Speech Recognition**: Optional speech-to-text

### Correlation Engine (`src/tracking/correlationEngine.js`)
- **Multi-Modal Correlation**: Correlates eye, face, touch, and voice data
- **Real-time Analysis**: 500ms correlation window
- **Pattern Detection**: Identifies behavioral patterns

---

## 🎨 UI/UX Features

### Avatar System
- **Virtual Avatar Component**: 
  - Multiple states (idle, talking, listening, happy, thinking, encouraging, celebrating)
  - Human or animal avatar types
  - Animation levels (off, medium, high)
  - Size customization
  - Gradient backgrounds per state
  - CSS animations (bounce, pulse, talk, think)

### Material-UI Components
- Modern gradient designs
- Responsive layout (mobile-first)
- Smooth transitions and animations
- Custom theme with gradients
- Dark/light mode support (via theme)

### Accessibility
- Screen reader support
- Keyboard navigation
- High contrast options
- COPPA compliant design
- GDPR ready (data export & deletion)

---

## 🤖 AI & ML Features

### AI Services
- **Gemini AI Integration** (`src/services/geminiService.ts`):
  - AI-generated session summaries
  - Concise highlights generation
  - Report enhancement
- **ElevenLabs TTS** (`src/services/elevenLabsTTS.js`):
  - Text-to-speech for avatar messages
  - Rate control (0.9x default)
  - Audio playback management

### ML Tracking
- **ONNX Runtime**: Client-side ML inference
- **Web Workers**: Background ML processing
- **Battery Management**: Efficient ML execution
- **Model Caching**: Optimized model loading

---

## 📊 Assessment & Scoring

### Subdomain Framework (`src/assessment/`)
- **5 SEL Domains** (Harvard CASEL):
  1. Self-Awareness
  2. Self-Management
  3. Social Awareness
  4. Relationship Skills
  5. Responsible Decision-Making
- **Subdomain Metrics**: Detailed subdomain scoring
- **Developmental Domains**: Age-appropriate assessments
- **Scoring Engine**: Automated score calculation
- **Report Generation**: Enhanced report generation with AI

### Measurement Tools
- `gaze_stability_score`: Attention control
- `voice_latency`: Communication skills
- `engagement_arc`: Overall engagement
- `emoji_check_in`: Emotional state assessment

---

## 💾 Data Management

### Database (Supabase)
- **Tables**:
  - `sessions`: Full session data
  - `session_analytics`: Aggregated metrics
  - `learners`: Learner profiles
  - `users`: Parent accounts
- **Offline Support**: IndexedDB for offline-first architecture
- **Sync Service**: Background sync to cloud

### Analytics Service (`src/services/analytics.js`)
- **Time Periods**: Session, week, month, 3 months
- **Caching**: 5-minute cache for performance
- **Aggregations**: 
  - Average attention scores
  - Engagement trends
  - Completion rates
  - Streak calculations

---

## 📱 Mobile Features (Capacitor)

### Native Platform Support
- **Android**: Full native camera preview, haptics, device info
- **iOS**: Native camera preview, haptics, device info
- **Deep Linking**: App URL handling for email confirmation
- **AdMob Integration**: Interstitial ads (native platforms only)
- **Edge-to-Edge**: Full-screen immersive experience

### Device Integration
- **Camera Preview**: Native camera overlay (Android/iOS)
- **Haptics**: Tactile feedback (impact styles)
- **Device Info**: Platform detection, screen dimensions
- **Preferences**: Local storage with Capacitor Preferences

---

## 🔐 Security & Privacy

### Security Features
- **PIN Protection**: Parent dashboard access
- **Session Timeout**: Auto-logout after 20 minutes
- **Secure Storage**: Encrypted local storage
- **HTTPS Only**: Secure API communication

### Privacy Features
- **COPPA Compliant**: Child privacy protection
- **GDPR Ready**: Data export & deletion
- **Minimal Data Collection**: Only necessary data
- **Parental Controls**: Full parent oversight

---

## 🌐 Internationalization

### Language Support
- **Languages**: English, Hindi, Bengali
- **Translation System**: `src/i18n/translations-ui.js`
- **Language Context**: React context for language switching
- **Language Selector**: UI component for language selection

---

## 🎮 Activity System

### Story Activities
- **3 Pre-defined Stories**:
  1. The Friendly Forest (180s)
  2. Ocean Adventure (180s)
  3. Space Explorer (180s)
- **Task Types**: Gaze, emotion, touch, memory, turn-taking, speech, problem-solving, attention
- **Adaptive Difficulty**: Adjusts based on performance

### Focus Areas
1. **Social Skills** (🤝) - Joint attention, turn-taking, social cues
2. **Emotion Intelligence** (❤️) - Emotion identification, regulation
3. **Thought Expression** (🗣️) - Communication, language
4. **Cognitive Growth** (🧠) - Memory, problem-solving
5. **Life Skills** (🌟) - Daily living, independence

---

## 📈 Reporting Features

### Report Types
1. **Concise Session Report**: Post-session summary
2. **Extended Report**: Detailed monthly analytics
3. **Progress Dashboard**: Weekly trends
4. **Domain Scores**: SEL competency breakdown

### Report Components
- **Charts**: Chart.js and Recharts integration
- **Heatmaps**: Gaze pattern visualization
- **Timelines**: Emotion and engagement timelines
- **Comparisons**: Before/after mood, progress over time
- **AI Insights**: Gemini-generated highlights and summaries

---

## 🛠️ Technical Stack

### Frontend
- **React 19**: Latest React with hooks
- **Vite**: Fast build tool
- **Material-UI v7**: Component library
- **React Router v7**: Navigation
- **Framer Motion**: Animations
- **Chart.js / Recharts**: Data visualization

### Backend Services
- **Supabase**: Backend-as-a-Service (PostgreSQL, Auth, Storage)
- **ElevenLabs API**: Text-to-speech
- **Google Gemini API**: AI insights
- **AdMob**: Mobile advertising

### Mobile
- **Capacitor 7**: Native mobile wrapper
- **Camera Preview Plugin**: Native camera overlay
- **Haptics Plugin**: Tactile feedback
- **Device Plugin**: Device information

### ML/AI
- **ONNX Runtime Web**: Client-side ML inference
- **MediaPipe Face Mesh**: Face detection
- **Web Workers**: Background processing

---

## 📁 Key File Structure

```
web/src/
├── pages/
│   ├── Auth/              # Authentication pages
│   ├── Learner/           # Child interface
│   ├── Parent/            # Parent dashboard
│   ├── Session/           # Session flow
│   └── Profile/           # Profile management
├── components/
│   ├── Avatar/            # Virtual avatar
│   ├── tracking/          # Tracking setup components
│   ├── Reports/           # Report components
│   └── common/            # Shared UI components
├── tracking/              # Core tracking systems
│   ├── eyeTracking.js     # Eye tracking
│   ├── touchTracking.js   # Touch tracking
│   ├── voiceTracking.js   # Voice tracking
│   └── correlationEngine.js
├── hooks/                 # Custom React hooks
│   ├── useSession.js      # Session management
│   └── useFaceDetection.js
├── services/              # API services
│   ├── analytics.js       # Analytics aggregation
│   ├── supabase.js        # Supabase client
│   ├── geminiService.ts   # AI service
│   └── elevenLabsTTS.js   # TTS service
├── assessment/            # Assessment tools
│   ├── subdomainMetrics.js
│   └── scoringEngine.js
└── contexts/              # React contexts
    └── AuthContext.jsx    # Authentication state
```

---

## 🚀 Deployment

### Build & Deploy
- **Vite Build**: Production-optimized builds
- **Vercel**: Web deployment (root directory: `web`)
- **Capacitor**: Native app builds (Android/iOS)
- **PWA Support**: Progressive Web App capabilities

### Environment
- **Development**: `npm run dev`
- **Production**: `npm run build`
- **Preview**: `npm run preview`

---

## 📝 Notes

- **Session Duration**: 15 minutes (900 seconds)
- **Metrics Collection**: Every 5 seconds during activity
- **Calibration**: 9-point grid, 3 seconds per point
- **Face Detection**: MediaPipe Face Mesh (468 landmarks)
- **Attention Score**: Averaged across entire session
- **Default PIN**: 1234 (can be changed per user)
- **Splash Screen**: Shows once per hour (cooldown)

---

This summary covers the comprehensive feature set of the Komal web application, including authentication, session management, tracking systems, analytics, reporting, and mobile capabilities.

