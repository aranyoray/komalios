-- ============================================================================
-- Komal Database Schema for Supabase
-- Complete Database Setup with all features from supabase_setup.sql
-- ============================================================================
-- This SQL file contains all tables, indexes, policies, and functions
-- needed to run the Komal web application with Supabase.
--
-- Run this in your Supabase SQL Editor:
-- https://supabase.com/dashboard/project/YOUR_PROJECT/editor
-- ============================================================================
--
-- FEATURE MAPPING TO DATABASE TABLES:
-- ============================================================================
--
-- 1. AUTHENTICATION & USER MANAGEMENT
--    - users: Parent/guardian accounts (phone, email, Apple, Google, guest)
--    - profiles: Parent profile information and settings
--    - learners: Child/learner profiles (multiple per user)
--
-- 2. SESSION MANAGEMENT
--    - sessions: Complete session data with:
--      * Metadata: start_time, end_time, duration, focus_area, avatar_mode
--      * Tasks: tasks_completed, tasks_total, activities_log
--      * Tracking: eye_tracking, micro_expressions, touch_tracking, voice_tracking
--      * Analytics: domain_scores, biomarker_analytics, measurement_results
--      * Reports: concise_report, extended_report
--      * Mood: mood_checks (emoji check-ins)
--
-- 3. TRACKING & ANALYTICS
--    - session_analytics: Session-level metrics:
--      * Core: attention_score, engagement_score, completion_rate, blink_rate
--      * Detailed: emotion_timeline, gaze_metrics, gaze_heatmap
--      * Biomarker: biomarker_summary, clinical_flags
--    - analytics: Aggregated weekly/monthly analytics
--    - subdomain_history: Subdomain assessment scores over time
--
-- 4. SUBDOMAIN ASSESSMENT FRAMEWORK
--    - learners.subdomain_assessment_history: Timestamps of last assessment per subdomain
--    - learners.subdomain_scores_history: Full assessment records with scores
--    - sessions.domain_scores: Computed domain scores (5 main domains)
--    - sessions.measurement_results: Raw measurement results from assessment tools
--    - subdomain_history: Historical tracking of subdomain scores
--
-- 5. BIOMARKER ANALYTICS
--    - sessions.biomarker_analytics: Complete biomarker analysis
--    - session_analytics.biomarker_summary: Summary of biomarker metrics
--    - session_analytics.clinical_flags: Escalation/monitoring flags
--
-- 6. MEASUREMENT TOOLS (stored in sessions.measurement_results)
--    - Eye tracking: eye_tracking_alignment, gaze_stability_score, off_screen_glance_detector
--    - Voice: voice_latency_detector, on_device_prosody_extractor
--    - Touch: sequence_tap_tasks, tap_focus_index, tap_error_rate
--    - NLP: semantic_relevance_nlp, local_nlp_classifier_for_question_detection
--    - Emoji: emoji_check_in_* (feeling, difficulty, motivation, understanding)
--    - Composite: engagement_arc_tracker, fatigue_signal_detector
--
-- 7. DOMAINS & SUBDOMAINS (5 main domains, 15+ subdomains)
--    - social_communication: joint_attention, turn_taking, conversation_initiation, 
--                            conversation_repair, appropriate_responses
--    - emotional_intelligence: emotion_identification, emotion_regulation, social_empathy
--    - cognitive_development: working_memory, attention_control, response_readiness
--    - language_development: vocabulary_growth, fluency_and_prosody, comprehension
--    - life_skills: problem_solving, task_persistence
--
-- 8. EMOJI CHECK-INS (stored in sessions.mood_checks)
--    - feeling_pre_task: How do you feel right now?
--    - difficulty_post_task: How difficult was this task?
--    - motivation_check: Do you want to continue?
--    - understanding_check: Did you understand?
--
-- ============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Note: Row Level Security is enabled by default in Supabase
-- JWT secret is automatically managed by Supabase, no need to set it manually
--
-- IMPORTANT: If you encounter "max_stack_depth" errors, increase it in Supabase:
-- ALTER DATABASE your_database_name SET max_stack_depth = '7MB';
-- Or set it per session: SET max_stack_depth = '7MB';

-- ============================================================================
-- USERS TABLE
-- Stores parent/guardian account information
-- ============================================================================
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  auth_id UUID, -- Foreign key constraint added separately to be DEFERRABLE
  phone_number TEXT UNIQUE,
  email TEXT,
  auth_method TEXT CHECK (auth_method IN ('phone', 'email', 'apple', 'google', 'guest')),
  language TEXT DEFAULT 'en' CHECK (language IN ('en', 'hi', 'bn', 'hi-en', 'te', 'mr', 'ta', 'ur', 'gu', 'kn', 'ml', 'or', 'pa', 'as', 'ne', 'gom', 'mai', 'ks', 'sd', 'doi', 'mni', 'brx', 'sa', 'sat')),
  pin_hash TEXT, -- Hashed PIN for parent access
  face_id_enabled BOOLEAN DEFAULT false,
  subscription_status TEXT DEFAULT 'free' CHECK (subscription_status IN ('free', 'premium', 'trial')),
  subscription_tier TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_login TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Unique constraint on auth_id
  CONSTRAINT users_auth_id_unique UNIQUE(auth_id)
);

-- Add foreign key constraint as DEFERRABLE to avoid timing issues
-- This allows the constraint to be checked at transaction commit, not immediately
ALTER TABLE users 
  DROP CONSTRAINT IF EXISTS users_auth_id_fkey;
ALTER TABLE users 
  ADD CONSTRAINT users_auth_id_fkey 
  FOREIGN KEY (auth_id) REFERENCES auth.users(id) ON DELETE CASCADE 
  DEFERRABLE INITIALLY DEFERRED;

-- ============================================================================
-- LEARNERS TABLE (also referenced as 'profiles' in some code)
-- Stores child/learner profiles
-- ============================================================================
CREATE TABLE IF NOT EXISTS learners (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  date_of_birth DATE,
  age INTEGER, -- Calculated on insert/update, not a generated column
  gender TEXT CHECK (gender IN ('male', 'female', 'other', 'prefer-not-to-say')),

  -- Focus areas (array)
  focus_areas TEXT[] DEFAULT ARRAY['social-skills'],

  -- Settings (JSONB for flexibility)
  settings JSONB DEFAULT '{
    "soundVolume": 0.7,
    "animationLevel": "medium",
    "preferredAvatar": "animal",
    "colorScheme": "default",
    "sessionDuration": 15,
    "difficulty": "adaptive",
    "rewards": true
  }'::jsonb,

  -- Permissions
  permissions JSONB DEFAULT '{
    "camera": false,
    "microphone": false,
    "storage": false
  }'::jsonb,

  -- Subdomain assessment history (stored in learner record)
  -- Format: {"domain.subdomain": timestamp, ...}
  subdomain_assessment_history JSONB DEFAULT '{}'::jsonb,
  
  -- Subdomain scores history (full assessment records with scores, confidence, metrics)
  -- Format: [{"domainKey": "...", "subdomainKey": "...", "score": 85, "confidence": 0.9, "timestamp": "...", "sessionId": "...", "measurements": [...]}, ...]
  subdomain_scores_history JSONB DEFAULT '[]'::jsonb,

  -- Diagnoses (optional, for clinical use)
  diagnoses TEXT[],

  pin_hash TEXT, -- Optional PIN for multi-learner households
  profile_image TEXT, -- URL or base64
  is_active BOOLEAN DEFAULT true,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- SESSIONS TABLE
-- Stores therapy/learning session data with all tracking metrics
-- ============================================================================
CREATE TABLE IF NOT EXISTS sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  learner_id UUID REFERENCES learners(id) ON DELETE CASCADE NOT NULL,

  -- Session metadata
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ,
  duration INTEGER, -- seconds
  focus_area TEXT,
  avatar_mode TEXT CHECK (avatar_mode IN ('animal', 'human')),
  avatar_name TEXT,

  -- Tasks/activities
  tasks_completed INTEGER DEFAULT 0,
  tasks_total INTEGER DEFAULT 0,
  activities_log JSONB DEFAULT '[]'::jsonb,

  -- Tracking data (JSONB for complex nested data)
  eye_tracking JSONB DEFAULT '{}'::jsonb, -- {gazePoints: [], blinkCount: 0, attentionScore: 100, emotionHistory: [], fixationDuration: 0, saccadeCount: 0, lookAwayCount: 0, metrics: {...}}
  micro_expressions JSONB DEFAULT '{}'::jsonb, -- {faceDetected: bool, faceConfidence: num, engagementScore: num, stats: {...}, detectedEmotions: []}
  touch_tracking JSONB DEFAULT '{}'::jsonb, -- {totalTouches: 0, accurateTouches: 0, goalDirectedAccuracy: 0, hesitationTaps: 0, randomTaps: 0, selfSoothingCount: 0, forceVariability: null}
  voice_tracking JSONB DEFAULT '{}'::jsonb, -- {confidence: 0, prosodyFeatures: {pitchMean, pitchVariance, volumeMean, pauseCount, disfluencyCount}, latency: 0}
  response_patterns JSONB DEFAULT '{}'::jsonb, -- {avgLatency: 0, retries: 0, turnTakingScore: 0, selfCorrections: 0, errors: 0, decreasedRetries: bool}
  correlations JSONB DEFAULT '{}'::jsonb, -- Cross-modal correlations: {timeline: [], events: [], patterns: []}
  
  -- Measurement results from subdomain assessment tools
  -- Format: [{tool: "...", subdomain: "...", score: 85, rawData: {...}, timestamp: ..., confidence: 0.9}, ...]
  measurement_results JSONB DEFAULT '[]'::jsonb,
  
  -- Domain scores (5 main domains with overall scores and subdomain breakdowns)
  -- Format: {social_communication: {overallScore: 85, subdomains: {...}}, emotional_intelligence: {...}, ...}
  domain_scores JSONB DEFAULT '{}'::jsonb,
  
  -- Biomarker analytics (comprehensive analytics from biomarkerAnalytics.js)
  -- Format: {eyeTracking: {...}, facialExpression: {...}, gestureTouch: {...}, responsePattern: {...}, timestamp: ...}
  biomarker_analytics JSONB DEFAULT '{}'::jsonb,

  -- SEL metrics (Harvard CASEL framework)
  sel_metrics JSONB DEFAULT '{
    "selfAwareness": {"score": 0, "observations": []},
    "selfManagement": {"score": 0, "observations": []},
    "socialAwareness": {"score": 0, "observations": []},
    "relationshipSkills": {"score": 0, "observations": []},
    "responsibleDecisionMaking": {"score": 0, "observations": []}
  }'::jsonb,

  -- Engagement
  engagement_quality NUMERIC(3,1) CHECK (engagement_quality >= 0 AND engagement_quality <= 10),
  key_skill_practiced TEXT,

  -- Highlights and notes
  highlights TEXT[],
  concerns TEXT[],

  -- Mood tracking
  mood_checks JSONB DEFAULT '[]'::jsonb,

  -- Device info
  device_info JSONB DEFAULT '{}'::jsonb,

  -- Report data
  concise_report JSONB, -- Generated concise report
  extended_report JSONB, -- Generated extended report

  -- Sync status
  synced_to_cloud BOOLEAN DEFAULT false,
  last_sync_attempt TIMESTAMPTZ,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- ANALYTICS TABLE
-- Stores aggregated analytics (weekly/monthly)
-- ============================================================================
CREATE TABLE IF NOT EXISTS analytics (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  learner_id UUID REFERENCES learners(id) ON DELETE CASCADE NOT NULL,

  -- Time range
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  period_type TEXT CHECK (period_type IN ('weekly', 'monthly')),

  -- Aggregated metrics
  total_sessions INTEGER DEFAULT 0,
  total_duration INTEGER DEFAULT 0, -- seconds
  avg_session_duration INTEGER DEFAULT 0,

  -- Trends (JSONB for complex data)
  trends JSONB DEFAULT '{}'::jsonb,

  -- SEL progress (array of scores over time)
  sel_progress JSONB DEFAULT '{
    "selfAwareness": [],
    "selfManagement": [],
    "socialAwareness": [],
    "relationshipSkills": [],
    "responsibleDecisionMaking": []
  }'::jsonb,

  -- Insights
  strengths TEXT[],
  challenges TEXT[],
  home_practice TEXT[],
  next_goals TEXT[],

  -- Clinician flags
  flags JSONB DEFAULT '{
    "escalate": false,
    "monitor": false,
    "reasons": []
  }'::jsonb,

  created_at TIMESTAMPTZ DEFAULT NOW(),

  -- Unique constraint: one analytics record per learner per period
  UNIQUE(learner_id, start_date, end_date)
);

-- ============================================================================
-- SESSION_ANALYTICS TABLE
-- Stores detailed session-level analytics for dashboard and reports
-- Used by analytics.js service
-- ============================================================================
CREATE TABLE IF NOT EXISTS session_analytics (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  learner_id UUID REFERENCES learners(id) ON DELETE CASCADE NOT NULL,
  session_id UUID REFERENCES sessions(id) ON DELETE CASCADE,
  
  -- Session date and duration
  session_date TIMESTAMPTZ NOT NULL,
  duration_minutes INTEGER,
  
  -- Core metrics
  attention_score INTEGER CHECK (attention_score >= 0 AND attention_score <= 100),
  engagement_score INTEGER CHECK (engagement_score >= 0 AND engagement_score <= 100),
  completion_rate INTEGER CHECK (completion_rate >= 0 AND completion_rate <= 100),
  blink_rate NUMERIC(5,2), -- blinks per minute
  
  -- Detailed data (JSONB)
  emotion_data JSONB DEFAULT '{}'::jsonb, -- {happy: count, focused: count, neutral: count, surprised: count, sad: count} or emotion timeline array
  emotion_timeline JSONB DEFAULT '[]'::jsonb, -- [{emotion: "...", confidence: 0.9, timestamp: ...}, ...]
  gaze_heatmap JSONB DEFAULT '[]'::jsonb, -- [{x: num, y: num, intensity: num, timestamp: ...}, ...]
  gaze_metrics JSONB DEFAULT '{}'::jsonb, -- {fixations: [], saccades: [], explorationEvents: 0, avoidanceEvents: 0, avatarFixations: 0, aversionEvents: []}
  activities_completed INTEGER DEFAULT 0,
  focus_areas TEXT[],
  difficulty_level TEXT,
  responses JSONB DEFAULT '[]'::jsonb, -- Response events array
  
  -- Biomarker analytics summary
  biomarker_summary JSONB DEFAULT '{}'::jsonb, -- {eyeTracking: {...}, facialExpression: {...}, gestureTouch: {...}, responsePattern: {...}}
  
  -- Clinical flags from biomarker analytics
  clinical_flags JSONB DEFAULT '[]'::jsonb, -- [{type: "escalate"|"flag"|"strengthen", message: "..."}, ...]
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- SUBDOMAIN_HISTORY TABLE
-- Stores subdomain assessment scores over time for trend analysis
-- Used by useSubdomainTracking hook and historicalData service
-- ============================================================================
CREATE TABLE IF NOT EXISTS subdomain_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  learner_id UUID REFERENCES learners(id) ON DELETE CASCADE NOT NULL,
  session_id UUID REFERENCES sessions(id) ON DELETE SET NULL,
  
  -- Subdomain identification
  subdomain_id TEXT NOT NULL, -- e.g., 'joint_attention', 'emotion_recognition'
  domain_id TEXT NOT NULL, -- e.g., 'social_communication', 'emotional_intelligence'
  
  -- Score and metrics
  score NUMERIC(5,2) CHECK (score >= 0 AND score <= 100),
  confidence NUMERIC(3,2) CHECK (confidence >= 0 AND confidence <= 1),
  metrics JSONB DEFAULT '{}'::jsonb,
  
  -- Timestamp
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  
  -- Indexes for efficient querying
  CONSTRAINT subdomain_history_learner_subdomain_timestamp UNIQUE(learner_id, subdomain_id, timestamp)
);

-- ============================================================================
-- PASSWORD_RESET_CODES TABLE
-- Stores password reset codes for code-based password reset flow
-- Used by forgot password and reset password pages
-- ============================================================================
CREATE TABLE IF NOT EXISTS password_reset_codes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT NOT NULL,
  code TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  used BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Unique constraint on email and code combination
  CONSTRAINT password_reset_codes_email_code_key UNIQUE(email, code)
);

-- ============================================================================
-- INDEXES for Performance
-- ============================================================================

-- Users indexes (from original supabase_setup.sql)
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone_number);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_auth_id ON users(auth_id);
CREATE INDEX IF NOT EXISTS idx_users_last_login ON users(last_login DESC);

-- Learners indexes (from original supabase_setup.sql)
CREATE INDEX IF NOT EXISTS idx_learners_user_id ON learners(user_id);
CREATE INDEX IF NOT EXISTS idx_learners_active ON learners(is_active);
CREATE INDEX IF NOT EXISTS idx_learners_created_at ON learners(created_at DESC);

-- Sessions indexes (from original supabase_setup.sql + enhancements)
CREATE INDEX IF NOT EXISTS idx_sessions_learner_id ON sessions(learner_id);
CREATE INDEX IF NOT EXISTS idx_sessions_start_time ON sessions(start_time DESC);
CREATE INDEX IF NOT EXISTS idx_sessions_focus_area ON sessions(focus_area);
CREATE INDEX IF NOT EXISTS idx_sessions_created_at ON sessions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sessions_synced ON sessions(synced_to_cloud) WHERE synced_to_cloud = false;
CREATE INDEX IF NOT EXISTS idx_sessions_learner_start_time ON sessions(learner_id, start_time DESC);

-- Analytics indexes
CREATE INDEX IF NOT EXISTS idx_analytics_learner_id ON analytics(learner_id);
CREATE INDEX IF NOT EXISTS idx_analytics_date_range ON analytics(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_analytics_period_type ON analytics(period_type);

-- Session analytics indexes
CREATE INDEX IF NOT EXISTS idx_session_analytics_learner_id ON session_analytics(learner_id);
CREATE INDEX IF NOT EXISTS idx_session_analytics_session_id ON session_analytics(session_id) WHERE session_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_session_analytics_date ON session_analytics(session_date DESC);
CREATE INDEX IF NOT EXISTS idx_session_analytics_learner_date ON session_analytics(learner_id, session_date DESC);

-- Subdomain history indexes
CREATE INDEX IF NOT EXISTS idx_subdomain_history_learner_id ON subdomain_history(learner_id);
CREATE INDEX IF NOT EXISTS idx_subdomain_history_subdomain_id ON subdomain_history(subdomain_id);
CREATE INDEX IF NOT EXISTS idx_subdomain_history_domain_id ON subdomain_history(domain_id);
CREATE INDEX IF NOT EXISTS idx_subdomain_history_timestamp ON subdomain_history(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_subdomain_history_learner_subdomain ON subdomain_history(learner_id, subdomain_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_subdomain_history_session_id ON subdomain_history(session_id) WHERE session_id IS NOT NULL;

-- Password reset codes indexes
CREATE INDEX IF NOT EXISTS idx_password_reset_codes_email ON password_reset_codes(email);
CREATE INDEX IF NOT EXISTS idx_password_reset_codes_code ON password_reset_codes(code);
CREATE INDEX IF NOT EXISTS idx_password_reset_codes_expires ON password_reset_codes(expires_at);
CREATE INDEX IF NOT EXISTS idx_password_reset_codes_email_used ON password_reset_codes(email, used) WHERE used = false;

-- Sessions indexes for new fields
CREATE INDEX IF NOT EXISTS idx_sessions_domain_scores ON sessions USING GIN (domain_scores);
CREATE INDEX IF NOT EXISTS idx_sessions_biomarker_analytics ON sessions USING GIN (biomarker_analytics);
CREATE INDEX IF NOT EXISTS idx_sessions_measurement_results ON sessions USING GIN (measurement_results);

-- Session analytics indexes for new fields
CREATE INDEX IF NOT EXISTS idx_session_analytics_emotion_timeline ON session_analytics USING GIN (emotion_timeline);
CREATE INDEX IF NOT EXISTS idx_session_analytics_gaze_metrics ON session_analytics USING GIN (gaze_metrics);
CREATE INDEX IF NOT EXISTS idx_session_analytics_biomarker_summary ON session_analytics USING GIN (biomarker_summary);
CREATE INDEX IF NOT EXISTS idx_session_analytics_clinical_flags ON session_analytics USING GIN (clinical_flags);

-- Learners indexes for new fields
CREATE INDEX IF NOT EXISTS idx_learners_subdomain_scores_history ON learners USING GIN (subdomain_scores_history);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE learners ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE session_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE subdomain_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE password_reset_codes ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- DROP ALL EXISTING POLICIES (for idempotency)
-- This ensures the SQL can be run multiple times without errors
-- Policies are dropped first, then recreated below
-- ============================================================================

-- Drop all policies on users table
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'users' AND schemaname = 'public') LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON users', r.policyname);
    END LOOP;
END $$;

-- Drop all policies on learners table
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'learners' AND schemaname = 'public') LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON learners', r.policyname);
    END LOOP;
END $$;

-- Drop all policies on sessions table
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'sessions' AND schemaname = 'public') LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON sessions', r.policyname);
    END LOOP;
END $$;

-- Drop all policies on analytics table
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'analytics' AND schemaname = 'public') LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON analytics', r.policyname);
    END LOOP;
END $$;

-- Drop all policies on session_analytics table
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'session_analytics' AND schemaname = 'public') LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON session_analytics', r.policyname);
    END LOOP;
END $$;

-- Drop all policies on subdomain_history table
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'subdomain_history' AND schemaname = 'public') LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON subdomain_history', r.policyname);
    END LOOP;
END $$;

-- Drop all policies on password_reset_codes table
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'password_reset_codes' AND schemaname = 'public') LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON password_reset_codes', r.policyname);
    END LOOP;
END $$;

-- Drop all policies on profiles table (if exists)
DO $$ 
DECLARE
    r RECORD;
BEGIN
    -- Check if table exists first
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'profiles') THEN
        FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'profiles' AND schemaname = 'public') LOOP
            EXECUTE format('DROP POLICY IF EXISTS %I ON profiles', r.policyname);
        END LOOP;
    END IF;
END $$;

-- ============================================================================
-- CREATE POLICIES
-- All policies are created fresh after dropping existing ones
-- ============================================================================

-- Users table policies
DROP POLICY IF EXISTS "Users can view own data" ON users;
DROP POLICY IF EXISTS "Users can update own data" ON users;
DROP POLICY IF EXISTS "Users can insert own data" ON users;

-- Learners table policies
DROP POLICY IF EXISTS "Users can view own learners" ON learners;
DROP POLICY IF EXISTS "Users can insert own learners" ON learners;
DROP POLICY IF EXISTS "Users can update own learners" ON learners;
DROP POLICY IF EXISTS "Users can delete own learners" ON learners;

-- Sessions table policies
DROP POLICY IF EXISTS "Users can view own sessions" ON sessions;
DROP POLICY IF EXISTS "Users can insert own sessions" ON sessions;
DROP POLICY IF EXISTS "Users can update own sessions" ON sessions;
DROP POLICY IF EXISTS "Users can delete own sessions" ON sessions;

-- Analytics table policies
DROP POLICY IF EXISTS "Users can view own analytics" ON analytics;
DROP POLICY IF EXISTS "Users can insert own analytics" ON analytics;
DROP POLICY IF EXISTS "Users can update own analytics" ON analytics;
DROP POLICY IF EXISTS "Users can delete own analytics" ON analytics;

-- Session analytics table policies
DROP POLICY IF EXISTS "Users can view own session_analytics" ON session_analytics;
DROP POLICY IF EXISTS "Users can insert own session_analytics" ON session_analytics;
DROP POLICY IF EXISTS "Users can update own session_analytics" ON session_analytics;
DROP POLICY IF EXISTS "Users can delete own session_analytics" ON session_analytics;

-- Subdomain history table policies
DROP POLICY IF EXISTS "Users can view own subdomain_history" ON subdomain_history;
DROP POLICY IF EXISTS "Users can insert own subdomain_history" ON subdomain_history;
DROP POLICY IF EXISTS "Users can update own subdomain_history" ON subdomain_history;
DROP POLICY IF EXISTS "Users can delete own subdomain_history" ON subdomain_history;

-- Password reset codes table policies
DROP POLICY IF EXISTS "Allow insert password reset codes" ON password_reset_codes;
DROP POLICY IF EXISTS "Allow read password reset codes" ON password_reset_codes;
DROP POLICY IF EXISTS "Allow update password reset codes" ON password_reset_codes;
DROP POLICY IF EXISTS "Allow delete password reset codes" ON password_reset_codes;

-- Users policies
CREATE POLICY "Users can view own data"
  ON users FOR SELECT
  USING (auth.uid() = auth_id);

CREATE POLICY "Users can update own data"
  ON users FOR UPDATE
  USING (auth.uid() = auth_id);

CREATE POLICY "Users can insert own data"
  ON users FOR INSERT
  WITH CHECK (auth.uid() = auth_id);

-- Learners policies
CREATE POLICY "Users can view own learners"
  ON learners FOR SELECT
  USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

CREATE POLICY "Users can insert own learners"
  ON learners FOR INSERT
  WITH CHECK (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

CREATE POLICY "Users can update own learners"
  ON learners FOR UPDATE
  USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

CREATE POLICY "Users can delete own learners"
  ON learners FOR DELETE
  USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Sessions policies
CREATE POLICY "Users can view own sessions"
  ON sessions FOR SELECT
  USING (learner_id IN (
    SELECT id FROM learners WHERE user_id IN (
      SELECT id FROM users WHERE auth_id = auth.uid()
    )
  ));

CREATE POLICY "Users can insert own sessions"
  ON sessions FOR INSERT
  WITH CHECK (learner_id IN (
    SELECT id FROM learners WHERE user_id IN (
      SELECT id FROM users WHERE auth_id = auth.uid()
    )
  ));

CREATE POLICY "Users can update own sessions"
  ON sessions FOR UPDATE
  USING (learner_id IN (
    SELECT id FROM learners WHERE user_id IN (
      SELECT id FROM users WHERE auth_id = auth.uid()
    )
  ));

-- Analytics policies
CREATE POLICY "Users can view own analytics"
  ON analytics FOR SELECT
  USING (learner_id IN (
    SELECT id FROM learners WHERE user_id IN (
      SELECT id FROM users WHERE auth_id = auth.uid()
    )
  ));

CREATE POLICY "Users can insert own analytics"
  ON analytics FOR INSERT
  WITH CHECK (learner_id IN (
    SELECT id FROM learners WHERE user_id IN (
      SELECT id FROM users WHERE auth_id = auth.uid()
    )
  ));

-- Session analytics policies
CREATE POLICY "Users can view own session_analytics"
  ON session_analytics FOR SELECT
  USING (learner_id IN (
    SELECT id FROM learners WHERE user_id IN (
      SELECT id FROM users WHERE auth_id = auth.uid()
    )
  ));

CREATE POLICY "Users can insert own session_analytics"
  ON session_analytics FOR INSERT
  WITH CHECK (learner_id IN (
    SELECT id FROM learners WHERE user_id IN (
      SELECT id FROM users WHERE auth_id = auth.uid()
    )
  ));

CREATE POLICY "Users can update own session_analytics"
  ON session_analytics FOR UPDATE
  USING (learner_id IN (
    SELECT id FROM learners WHERE user_id IN (
      SELECT id FROM users WHERE auth_id = auth.uid()
    )
  ));

-- Subdomain history policies
CREATE POLICY "Users can view own subdomain_history"
  ON subdomain_history FOR SELECT
  USING (learner_id IN (
    SELECT id FROM learners WHERE user_id IN (
      SELECT id FROM users WHERE auth_id = auth.uid()
    )
  ));

CREATE POLICY "Users can insert own subdomain_history"
  ON subdomain_history FOR INSERT
  WITH CHECK (learner_id IN (
    SELECT id FROM learners WHERE user_id IN (
      SELECT id FROM users WHERE auth_id = auth.uid()
    )
  ));

-- Password reset codes policies (allow anonymous access for password reset flow)
CREATE POLICY "Allow insert password reset codes"
  ON password_reset_codes
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY "Allow read password reset codes"
  ON password_reset_codes
  FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Allow update password reset codes"
  ON password_reset_codes
  FOR UPDATE
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- NOTE: All functions, triggers, and RLS policies have been removed
-- The web app should handle all CRUD operations, security, and business logic
-- ============================================================================

-- Drop all existing triggers and functions (with CASCADE to remove dependencies)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.ensure_user_exists() CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS calculate_learner_age() CASCADE;
DROP FUNCTION IF EXISTS route_profile_insert() CASCADE;
DROP FUNCTION IF EXISTS learners_as_profiles_insert() CASCADE;
DROP FUNCTION IF EXISTS learners_as_profiles_update() CASCADE;
DROP FUNCTION IF EXISTS learners_as_profiles_delete() CASCADE;
DROP FUNCTION IF EXISTS validate_session_data(JSONB) CASCADE;
DROP FUNCTION IF EXISTS get_learner_session_count(UUID, INTEGER) CASCADE;
DROP FUNCTION IF EXISTS get_learner_avg_engagement(UUID) CASCADE;

-- ============================================================================
-- VIEWS for Common Queries
-- ============================================================================

-- NOTE: Triggers have been removed
-- The web app should call handle_new_user() or ensure_user_exists() after signup/login

-- ============================================================================
-- VIEWS for Common Queries
-- ============================================================================

-- View for recent sessions with learner info
CREATE OR REPLACE VIEW recent_sessions_view AS
SELECT 
  s.id,
  s.learner_id,
  l.name as learner_name,
  s.start_time,
  s.duration,
  s.engagement_quality,
  s.tasks_completed,
  s.tasks_total,
  s.focus_area
FROM sessions s
JOIN learners l ON s.learner_id = l.id
ORDER BY s.start_time DESC;

-- View for learner progress summary
CREATE OR REPLACE VIEW learner_progress_view AS
SELECT 
  l.id as learner_id,
  l.name as learner_name,
  COUNT(s.id) as total_sessions,
  AVG(s.engagement_quality) as avg_engagement,
  AVG(s.duration) as avg_duration,
  MAX(s.start_time) as last_session_date
FROM learners l
LEFT JOIN sessions s ON l.id = s.learner_id
WHERE l.is_active = true
GROUP BY l.id, l.name;

-- ============================================================================
-- PROFILES TABLE (Parent/User Profile Information and Settings)
-- Stores parent/user profile data - ONE profile per user
-- This is separate from learners table which stores child profiles
-- ============================================================================
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  
  -- Parent/User basic information (for backward compatibility with AuthContext)
  email TEXT,
  language TEXT DEFAULT 'en',
  auth_method TEXT,
  
  -- Parent/User display information
  display_name TEXT,
  profile_image TEXT, -- URL or base64
  bio TEXT,
  
  -- Learner fields (for backward compatibility - trigger routes to learners table)
  -- These fields allow code to INSERT into profiles with learner data
  name TEXT,
  date_of_birth DATE,
  age INTEGER,
  gender TEXT CHECK (gender IN ('male', 'female', 'other', 'prefer-not-to-say')),
  focus_areas TEXT[],
  diagnoses TEXT[],
  settings JSONB,
  permissions JSONB,
  subdomain_assessment_history JSONB,
  pin_hash TEXT,
  is_active BOOLEAN,
  
  -- Parent preferences and settings
  preferences JSONB DEFAULT '{
    "notifications": {
      "email": true,
      "push": true,
      "sessionReminders": true,
      "reportReady": true
    },
    "language": "en",
    "theme": "light",
    "timezone": "UTC"
  }'::jsonb,
  
  -- Parent dashboard settings
  dashboard_settings JSONB DEFAULT '{
    "defaultView": "overview",
    "showCharts": true,
    "showInsights": true,
    "dateRange": "week"
  }'::jsonb,
  
  -- Parent subscription and access
  subscription_preferences JSONB DEFAULT '{}'::jsonb,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Ensure one profile per user (only for parent profiles)
  CONSTRAINT profiles_one_per_user UNIQUE(user_id)
);

-- Add foreign key constraints for profiles (DEFERRABLE to avoid timing issues)
ALTER TABLE profiles 
  DROP CONSTRAINT IF EXISTS profiles_id_fkey;
ALTER TABLE profiles 
  ADD CONSTRAINT profiles_id_fkey 
  FOREIGN KEY (id) REFERENCES users(id) ON DELETE CASCADE 
  DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE profiles 
  DROP CONSTRAINT IF EXISTS profiles_user_id_fkey;
ALTER TABLE profiles 
  ADD CONSTRAINT profiles_user_id_fkey 
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE 
  DEFERRABLE INITIALLY DEFERRED;

-- Create indexes for profiles
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_created_at ON profiles(created_at DESC);

-- NOTE: All functions removed - web app handles routing
-- Function to route inserts to correct table (profiles vs learners)
-- This handles backward compatibility with code that inserts into 'profiles'
-- IMPORTANT: This function runs with SECURITY DEFINER to bypass RLS when routing learner data
CREATE OR REPLACE FUNCTION route_profile_insert()
RETURNS TRIGGER AS $$
DECLARE
  actual_user_id UUID;
  is_learner_profile BOOLEAN := false;
  inserted_learner_id UUID;
  auth_user_id_to_lookup UUID;
  auth_user_email TEXT;
BEGIN
  -- Prevent infinite recursion - if this is being called from within another trigger
  -- that's trying to insert into profiles, skip the routing
  -- (This is a safety check, though the logic should prevent recursion)
  
  -- Determine if this is a learner profile or parent profile
  -- Learner profiles have: name, age, focus_areas, date_of_birth
  -- Parent profiles have: email, auth_method, language (or just id matching auth.uid())
  
  -- Check if this looks like a learner profile
  IF NEW.name IS NOT NULL OR NEW.age IS NOT NULL OR NEW.focus_areas IS NOT NULL OR NEW.date_of_birth IS NOT NULL THEN
    is_learner_profile := true;
  END IF;
  
  -- If it's a learner profile, route to learners table
  IF is_learner_profile THEN
    -- Find or set user_id - handle case where user_id might be auth user ID
    -- The code passes user?.id which is auth.users.id, not users.id
    -- We need to map auth user ID to users table ID
    
    -- Determine which ID to use for lookup
    IF NEW.user_id IS NOT NULL THEN
      auth_user_id_to_lookup := NEW.user_id;
    ELSIF NEW.id IS NOT NULL THEN
      auth_user_id_to_lookup := NEW.id;
    ELSIF auth.uid() IS NOT NULL THEN
      auth_user_id_to_lookup := auth.uid();
    ELSE
      RAISE EXCEPTION 'Cannot determine user_id for learner profile. User must be authenticated.';
    END IF;
    
    -- Try to find user by auth_id first (most common case - user_id is auth user ID)
    SELECT id INTO actual_user_id FROM users WHERE auth_id = auth_user_id_to_lookup LIMIT 1;
    
    -- If not found, try to find by id (in case it's already a users.id)
    IF actual_user_id IS NULL THEN
      SELECT id INTO actual_user_id FROM users WHERE id = auth_user_id_to_lookup LIMIT 1;
    END IF;
    
    -- If still not found, create users record
    IF actual_user_id IS NULL THEN
      -- Try to get email from auth.users if available (only if we have access)
      BEGIN
        -- Note: We can't directly query auth.users from a trigger, so use what we have
        auth_user_email := COALESCE(NEW.email, '');
      EXCEPTION WHEN OTHERS THEN
        auth_user_email := COALESCE(NEW.email, '');
      END;
      
      -- Insert new user record
      BEGIN
        INSERT INTO users (auth_id, email, auth_method, language, created_at)
        VALUES (
          auth_user_id_to_lookup,
          auth_user_email,
          COALESCE(NEW.auth_method, 'email'),
          COALESCE(NEW.language, 'en'),
          NOW()
        )
        RETURNING id INTO actual_user_id;
      EXCEPTION WHEN unique_violation THEN
        -- If duplicate (race condition), try to find again
        SELECT id INTO actual_user_id FROM users WHERE auth_id = auth_user_id_to_lookup LIMIT 1;
      END;
    END IF;
    
    -- Set the user_id for the learner insert
    NEW.user_id := actual_user_id;
    
    -- Insert into learners table instead
    INSERT INTO learners (
      id, user_id, name, date_of_birth, age, gender, focus_areas,
      settings, permissions, subdomain_assessment_history, diagnoses,
      pin_hash, profile_image, is_active, created_at, updated_at
    ) VALUES (
      COALESCE(NEW.id, uuid_generate_v4()),
      NEW.user_id,
      NEW.name,
      NEW.date_of_birth,
      NEW.age,
      NEW.gender,
      COALESCE(NEW.focus_areas, ARRAY['social-skills']::TEXT[]),
      COALESCE(NEW.settings, '{
        "soundVolume": 0.7,
        "animationLevel": "medium",
        "preferredAvatar": "animal",
        "colorScheme": "default",
        "sessionDuration": 15,
        "difficulty": "adaptive",
        "rewards": true
      }'::jsonb),
      COALESCE(NEW.permissions, '{
        "camera": false,
        "microphone": false,
        "storage": false
      }'::jsonb),
      COALESCE(NEW.subdomain_assessment_history, '{}'::jsonb),
      NEW.diagnoses,
      NEW.pin_hash,
      NEW.profile_image,
      COALESCE(NEW.is_active, true),
      COALESCE(NEW.created_at, NOW()),
      COALESCE(NEW.updated_at, NOW())
    )
    ON CONFLICT (id) DO UPDATE SET
      user_id = EXCLUDED.user_id,
      name = EXCLUDED.name,
      date_of_birth = EXCLUDED.date_of_birth,
      age = EXCLUDED.age,
      gender = EXCLUDED.gender,
      focus_areas = EXCLUDED.focus_areas,
      settings = EXCLUDED.settings,
      permissions = EXCLUDED.permissions,
      subdomain_assessment_history = EXCLUDED.subdomain_assessment_history,
      diagnoses = EXCLUDED.diagnoses,
      pin_hash = EXCLUDED.pin_hash,
      profile_image = EXCLUDED.profile_image,
      is_active = EXCLUDED.is_active,
      updated_at = EXCLUDED.updated_at
    RETURNING id INTO inserted_learner_id;
    
    -- Update NEW.id to the learner id so the insert appears to succeed
    NEW.id = inserted_learner_id;
    
    -- Return NULL to prevent insert into profiles (but we've already inserted into learners)
    RETURN NULL;
  ELSE
    -- This is a parent profile - handle user_id
    IF NEW.user_id IS NULL AND NEW.id IS NOT NULL THEN
      -- Try to find user by auth_id (if id is auth user id)
      SELECT id INTO actual_user_id FROM users WHERE auth_id = NEW.id LIMIT 1;
      
      -- If not found, use id as user_id (if id is users.id)
      IF actual_user_id IS NULL THEN
        SELECT id INTO actual_user_id FROM users WHERE id = NEW.id LIMIT 1;
      END IF;
      
      -- If still not found and NEW.id matches auth.uid(), get user record
      IF actual_user_id IS NULL AND NEW.id = auth.uid() THEN
        SELECT id INTO actual_user_id FROM users WHERE auth_id = NEW.id LIMIT 1;
      END IF;
      
      NEW.user_id = COALESCE(actual_user_id, NEW.id);
      NEW.id = COALESCE(NEW.id, actual_user_id);
    END IF;
    
    -- Insert/update parent profile (including email, language, auth_method for backward compatibility)
    INSERT INTO profiles (
      id, user_id, email, language, auth_method, display_name, profile_image, bio, preferences,
      dashboard_settings, subscription_preferences, created_at, updated_at
    ) VALUES (
      COALESCE(NEW.id, NEW.user_id),
      NEW.user_id,
      NEW.email,
      COALESCE(NEW.language, 'en'),
      NEW.auth_method,
      NEW.display_name,
      NEW.profile_image,
      NEW.bio,
      COALESCE(NEW.preferences, jsonb_build_object(
        'notifications', jsonb_build_object(
          'email', true,
          'push', true,
          'sessionReminders', true,
          'reportReady', true
        ),
        'language', COALESCE(NEW.language, 'en'),
        'theme', 'light',
        'timezone', 'UTC'
      )),
      COALESCE(NEW.dashboard_settings, '{
        "defaultView": "overview",
        "showCharts": true,
        "showInsights": true,
        "dateRange": "week"
      }'::jsonb),
      COALESCE(NEW.subscription_preferences, '{}'::jsonb),
      COALESCE(NEW.created_at, NOW()),
      COALESCE(NEW.updated_at, NOW())
    )
    ON CONFLICT (user_id) DO UPDATE SET
      email = COALESCE(EXCLUDED.email, profiles.email),
      language = COALESCE(EXCLUDED.language, profiles.language),
      auth_method = COALESCE(EXCLUDED.auth_method, profiles.auth_method),
      display_name = COALESCE(EXCLUDED.display_name, profiles.display_name),
      profile_image = COALESCE(EXCLUDED.profile_image, profiles.profile_image),
      bio = COALESCE(EXCLUDED.bio, profiles.bio),
      preferences = COALESCE(EXCLUDED.preferences, profiles.preferences),
      dashboard_settings = COALESCE(EXCLUDED.dashboard_settings, profiles.dashboard_settings),
      subscription_preferences = COALESCE(EXCLUDED.subscription_preferences, profiles.subscription_preferences),
      updated_at = NOW();
    
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- NOTE: Triggers have been removed
-- Web app should insert directly into 'learners' table for child profiles
-- Web app should insert directly into 'profiles' table for parent profiles

-- ============================================================================
-- IMPORTANT: For SELECT queries, use 'learners' table or 'learners_as_profiles' view
-- The 'profiles' table is for parent profiles only and doesn't have learner columns
-- ============================================================================
-- 
-- If code queries 'profiles' expecting learners, it should query 'learners' instead
-- OR use the 'learners_as_profiles' view which provides backward compatibility
--
-- Example:
--   SELECT * FROM learners WHERE user_id = ?;  -- Correct
--   SELECT * FROM learners_as_profiles WHERE user_id = ?;  -- Also works
--   SELECT * FROM profiles WHERE user_id = ?;  -- Wrong (returns parent profiles only)

-- ============================================================================
-- IMPORTANT: Table Structure
-- ============================================================================
-- 'profiles' table: Stores PARENT/USER profile information only
--   - Does NOT have: name, age, date_of_birth, focus_areas (those are in learners)
--   - Has: display_name, preferences, dashboard_settings, etc.
--
-- 'learners' table: Stores CHILD/LEARNER profiles
--   - Has: name, age, date_of_birth, focus_areas, settings, etc.
--
-- For code that queries 'profiles' expecting learners (with age, name, etc.):
--   - Use 'learners' table instead: SELECT * FROM learners WHERE user_id = ?
--   - OR use 'learners_as_profiles' view: SELECT * FROM learners_as_profiles WHERE user_id = ?
--
-- The INSERT trigger routes inserts correctly, but SELECT queries must use the right table/view
-- ============================================================================

-- View that shows learners (for backward compatibility with SELECT queries)
-- Code should query 'learners' directly, but this view helps with migration
CREATE OR REPLACE VIEW learners_as_profiles AS
SELECT 
  l.id,
  l.user_id,
  l.name,
  l.date_of_birth,
  l.age,
  l.gender,
  l.focus_areas,
  l.settings,
  l.permissions,
  l.subdomain_assessment_history,
  l.diagnoses,
  l.pin_hash,
  l.profile_image,
  l.is_active,
  l.created_at,
  l.updated_at
FROM learners l;

-- View that combines both parent profiles and learners
CREATE OR REPLACE VIEW all_profiles_view AS
SELECT 
  l.id,
  l.user_id,
  l.name,
  l.date_of_birth,
  l.age,
  l.gender,
  l.focus_areas,
  l.settings,
  l.permissions,
  l.subdomain_assessment_history,
  l.diagnoses,
  l.pin_hash,
  l.profile_image,
  l.is_active,
  l.created_at,
  l.updated_at,
  'learner'::TEXT as profile_type
FROM learners l
UNION ALL
SELECT 
  p.id,
  p.user_id,
  p.display_name as name,
  NULL::DATE as date_of_birth,
  NULL::INTEGER as age,
  NULL::TEXT as gender,
  NULL::TEXT[] as focus_areas,
  p.preferences as settings,
  '{}'::jsonb as permissions,
  '{}'::jsonb as subdomain_assessment_history,
  NULL::TEXT[] as diagnoses,
  NULL::TEXT as pin_hash,
  p.profile_image,
  true as is_active,
  p.created_at,
  p.updated_at,
  'parent'::TEXT as profile_type
FROM profiles p;

-- Grant access to view
GRANT SELECT ON all_profiles_view TO authenticated;

-- Enable RLS on profiles
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Profiles RLS policies (for parent profiles)
DROP POLICY IF EXISTS "Users can view own profiles" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profiles" ON profiles;
DROP POLICY IF EXISTS "Users can update own profiles" ON profiles;
DROP POLICY IF EXISTS "Users can delete own profiles" ON profiles;

CREATE POLICY "Users can view own profiles"
  ON profiles FOR SELECT
  USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

CREATE POLICY "Users can insert own profiles"
  ON profiles FOR INSERT
  WITH CHECK (
    -- Allow if user is authenticated
    auth.uid() IS NOT NULL
    AND (
      -- Case 1: user_id matches authenticated user's users table record (users.id)
      user_id IN (SELECT id FROM users WHERE auth_id = auth.uid())
      -- Case 2: user_id matches auth.uid() directly (web app passes auth.users.id as user_id)
      OR user_id = auth.uid()
      -- Case 3: id matches a users.id that belongs to the authenticated user
      OR id IN (SELECT id FROM users WHERE auth_id = auth.uid())
      -- Case 4: id matches auth.uid() directly (for initial profile creation)
    OR id = auth.uid()
      -- Case 5: Allow if user_id is NULL but we're authenticated (will be set by trigger)
      OR (user_id IS NULL AND auth.uid() IS NOT NULL)
      -- Case 6: Allow if id is NULL but we're authenticated (will be set by trigger)
      -- This is needed for learner profiles that will be routed to learners table
      OR (id IS NULL AND auth.uid() IS NOT NULL)
    )
  );

CREATE POLICY "Users can update own profiles"
  ON profiles FOR UPDATE
  USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

CREATE POLICY "Users can delete own profiles"
  ON profiles FOR DELETE
  USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Trigger for profiles updated_at
-- NOTE: Triggers have been removed
-- Web app should update updated_at manually when updating profiles

-- ============================================================================
-- NOTE: Profile creation is now handled by handle_new_user() function
-- This ensures both users and profiles are created atomically in a single trigger
-- This prevents recursion issues and foreign key constraint violations
-- ============================================================================

-- ============================================================================
-- REALTIME SUBSCRIPTIONS (Optional)
-- Enable realtime for sessions table so parents can see live updates
-- ============================================================================

-- Note: This requires Supabase Realtime to be enabled
-- Check: https://supabase.com/dashboard/project/YOUR_PROJECT/database/replication
-- Only add tables to realtime publication if they're not already members
DO $$
BEGIN
    -- Add sessions table if not already in publication
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND tablename = 'sessions' 
        AND schemaname = 'public'
    ) THEN
ALTER PUBLICATION supabase_realtime ADD TABLE sessions;
    END IF;
    
    -- Add session_analytics table if not already in publication
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND tablename = 'session_analytics' 
        AND schemaname = 'public'
    ) THEN
ALTER PUBLICATION supabase_realtime ADD TABLE session_analytics;
    END IF;
END $$;

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant access to authenticated users
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT SELECT ON recent_sessions_view TO authenticated;
GRANT SELECT ON learner_progress_view TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON learners_as_profiles TO authenticated;
GRANT SELECT ON all_profiles_view TO authenticated;

-- Create INSTEAD OF triggers on learners_as_profiles view to make it writable
-- This allows code to INSERT/UPDATE/DELETE on the view as if it were the profiles table
CREATE OR REPLACE FUNCTION learners_as_profiles_insert()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO learners (
    id, user_id, name, date_of_birth, age, gender, focus_areas,
    settings, permissions, subdomain_assessment_history, diagnoses,
    pin_hash, profile_image, is_active, created_at, updated_at
  ) VALUES (
    COALESCE(NEW.id, uuid_generate_v4()),
    NEW.user_id,
    NEW.name,
    NEW.date_of_birth,
    NEW.age,
    NEW.gender,
    COALESCE(NEW.focus_areas, ARRAY['social-skills']::TEXT[]),
    COALESCE(NEW.settings, '{
      "soundVolume": 0.7,
      "animationLevel": "medium",
      "preferredAvatar": "animal",
      "colorScheme": "default",
      "sessionDuration": 15,
      "difficulty": "adaptive",
      "rewards": true
    }'::jsonb),
    COALESCE(NEW.permissions, '{
      "camera": false,
      "microphone": false,
      "storage": false
    }'::jsonb),
    COALESCE(NEW.subdomain_assessment_history, '{}'::jsonb),
    NEW.diagnoses,
    NEW.pin_hash,
    NEW.profile_image,
    COALESCE(NEW.is_active, true),
    COALESCE(NEW.created_at, NOW()),
    COALESCE(NEW.updated_at, NOW())
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION learners_as_profiles_update()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE learners SET
    user_id = NEW.user_id,
    name = NEW.name,
    date_of_birth = NEW.date_of_birth,
    age = NEW.age,
    gender = NEW.gender,
    focus_areas = NEW.focus_areas,
    settings = NEW.settings,
    permissions = NEW.permissions,
    subdomain_assessment_history = NEW.subdomain_assessment_history,
    diagnoses = NEW.diagnoses,
    pin_hash = NEW.pin_hash,
    profile_image = NEW.profile_image,
    is_active = NEW.is_active,
    updated_at = NOW()
  WHERE id = NEW.id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION learners_as_profiles_delete()
RETURNS TRIGGER AS $$
BEGIN
  DELETE FROM learners WHERE id = OLD.id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- NOTE: Triggers have been removed
-- Web app should insert/update/delete directly from 'learners' table instead of using the view

-- NOTE: Triggers have been removed
-- Web app should insert/update/delete directly from 'learners' table instead of using the view

-- ============================================================================
-- DATA VALIDATION FUNCTIONS
-- ============================================================================

-- Function to validate session data structure
CREATE OR REPLACE FUNCTION validate_session_data(session_data JSONB)
RETURNS BOOLEAN AS $$
BEGIN
  -- Check required fields
  IF NOT (session_data ? 'start_time' AND session_data ? 'learner_id') THEN
    RETURN false;
  END IF;
  
  -- Validate engagement_quality if present
  IF session_data ? 'engagement_quality' THEN
    IF (session_data->>'engagement_quality')::NUMERIC < 0 OR 
       (session_data->>'engagement_quality')::NUMERIC > 10 THEN
      RETURN false;
    END IF;
  END IF;
  
  RETURN true;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Function to get learner's recent sessions count
CREATE OR REPLACE FUNCTION get_learner_session_count(learner_uuid UUID, days_back INTEGER DEFAULT 30)
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)
    FROM sessions
    WHERE learner_id = learner_uuid
      AND start_time >= NOW() - (days_back || ' days')::INTERVAL
  );
END;
$$ LANGUAGE plpgsql;

-- Function to calculate average engagement for learner
CREATE OR REPLACE FUNCTION get_learner_avg_engagement(learner_uuid UUID)
RETURNS NUMERIC AS $$
BEGIN
  RETURN (
    SELECT COALESCE(AVG(engagement_quality), 0)
    FROM sessions
    WHERE learner_id = learner_uuid
      AND engagement_quality IS NOT NULL
  );
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PASSWORD RESET CODE FUNCTIONS
-- Functions for code-based password reset flow
-- ============================================================================

-- Function to clean up expired codes (runs automatically or can be called manually)
CREATE OR REPLACE FUNCTION cleanup_expired_reset_codes()
RETURNS void AS $$
BEGIN
  DELETE FROM password_reset_codes
  WHERE expires_at < NOW() OR used = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to generate and store password reset code
CREATE OR REPLACE FUNCTION generate_password_reset_code(user_email TEXT)
RETURNS TEXT AS $$
DECLARE
  reset_code TEXT;
  code_expires TIMESTAMPTZ;
BEGIN
  -- Generate 6-digit code
  reset_code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
  
  -- Set expiration to 15 minutes from now
  code_expires := NOW() + INTERVAL '15 minutes';
  
  -- Invalidate any existing codes for this email
  UPDATE password_reset_codes
  SET used = true
  WHERE email = LOWER(TRIM(user_email)) AND used = false;
  
  -- Insert new code
  INSERT INTO password_reset_codes (email, code, expires_at)
  VALUES (LOWER(TRIM(user_email)), reset_code, code_expires)
  ON CONFLICT (email, code) DO NOTHING;
  
  -- Return the code (for email sending)
  RETURN reset_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to verify reset code
CREATE OR REPLACE FUNCTION verify_password_reset_code(user_email TEXT, input_code TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  code_record RECORD;
BEGIN
  -- Find the code
  SELECT * INTO code_record
  FROM password_reset_codes
  WHERE email = LOWER(TRIM(user_email))
    AND code = input_code
    AND used = false
    AND expires_at > NOW()
  ORDER BY created_at DESC
  LIMIT 1;
  
  -- If code found and valid, mark as used
  IF FOUND THEN
    UPDATE password_reset_codes
    SET used = true
    WHERE id = code_record.id;
    RETURN true;
  END IF;
  
  RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions on password reset functions
GRANT EXECUTE ON FUNCTION generate_password_reset_code(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION verify_password_reset_code(TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION cleanup_expired_reset_codes() TO anon, authenticated;

-- ============================================================================
-- COMPLETION MESSAGE
-- ============================================================================
DO $$
BEGIN
  RAISE NOTICE '✅ Komal database setup completed successfully!';
  RAISE NOTICE '';
  RAISE NOTICE 'Tables created:';
  RAISE NOTICE '  - users (parent/guardian accounts)';
  RAISE NOTICE '  - profiles (parent/user profile info and settings - ONE per user)';
  RAISE NOTICE '  - learners (child/learner profiles - MULTIPLE per user)';
  RAISE NOTICE '    * subdomain_assessment_history: Last assessment timestamps per subdomain';
  RAISE NOTICE '    * subdomain_scores_history: Full assessment records with scores';
  RAISE NOTICE '  - sessions (therapy session data with complete tracking)';
  RAISE NOTICE '    * eye_tracking, micro_expressions, touch_tracking, voice_tracking';
  RAISE NOTICE '    * domain_scores: 5 main domains with subdomain breakdowns';
  RAISE NOTICE '    * biomarker_analytics: Complete biomarker analysis';
  RAISE NOTICE '    * measurement_results: Raw measurement results from assessment tools';
  RAISE NOTICE '    * mood_checks: Emoji check-ins (feeling, difficulty, motivation, understanding)';
  RAISE NOTICE '  - analytics (aggregated analytics - weekly/monthly)';
  RAISE NOTICE '  - session_analytics (session-level analytics with biomarker data)';
  RAISE NOTICE '    * emotion_timeline, gaze_metrics, gaze_heatmap';
  RAISE NOTICE '    * biomarker_summary, clinical_flags';
  RAISE NOTICE '  - subdomain_history (subdomain assessment scores over time)';
  RAISE NOTICE '  - password_reset_codes (code-based password reset codes)';
  RAISE NOTICE '';
  RAISE NOTICE 'Views created:';
  RAISE NOTICE '  - learners_as_profiles (backward compatibility - shows learners)';
  RAISE NOTICE '  - all_profiles_view (combines profiles + learners)';
  RAISE NOTICE '';
  RAISE NOTICE 'Important Notes:';
  RAISE NOTICE '  📋 profiles table: Stores PARENT/USER profile information';
  RAISE NOTICE '  👶 learners table: Stores CHILD/LEARNER profiles';
  RAISE NOTICE '  🔄 INSERTs to profiles are automatically routed:';
  RAISE NOTICE '     • Learner data (name, age, focus_areas) → learners table';
  RAISE NOTICE '     • Parent data (email, auth_method) → profiles table';
  RAISE NOTICE '  📊 For SELECT queries:';
  RAISE NOTICE '     • Query "learners" table for child profiles';
  RAISE NOTICE '     • Query "profiles" table for parent profiles';
  RAISE NOTICE '     • Use "learners_as_profiles" view for backward compatibility';
  RAISE NOTICE '';
  RAISE NOTICE 'Functions created:';
  RAISE NOTICE '  - handle_new_user() - Creates users + profiles on signup (automatic trigger)';
  RAISE NOTICE '  - ensure_user_exists() - Creates users + profiles on login (call manually)';
  RAISE NOTICE '  - generate_password_reset_code(email) - Generates 6-digit reset code';
  RAISE NOTICE '  - verify_password_reset_code(email, code) - Verifies reset code';
  RAISE NOTICE '  - cleanup_expired_reset_codes() - Cleans up expired codes';
  RAISE NOTICE '';
  RAISE NOTICE 'FIXES APPLIED:';
  RAISE NOTICE '  ✅ Foreign key constraints are DEFERRABLE to prevent timing issues';
  RAISE NOTICE '  ✅ Single trigger creates both users and profiles atomically';
  RAISE NOTICE '  ✅ ensure_user_exists() creates both users and profiles on login';
  RAISE NOTICE '  ✅ Removed duplicate triggers to prevent recursion';
  RAISE NOTICE '';
  RAISE NOTICE 'Next steps:';
  RAISE NOTICE '  1. Run this SQL file in Supabase SQL Editor';
  RAISE NOTICE '  2. Update web/src/services/supabase.js with your API keys';
  RAISE NOTICE '  3. In your signup handler, call: SELECT handle_new_user();';
  RAISE NOTICE '  4. In your login handler, call: SELECT ensure_user_exists();';
  RAISE NOTICE '  5. Test authentication: npm run dev';
END $$;

-- ============================================================================
-- SEED DATA (Optional - for testing)
-- From original supabase_setup.sql
-- ============================================================================

-- Uncomment to add test data
/*
-- Test user
INSERT INTO users (email, auth_method, language) VALUES
  ('test@komal.com', 'email', 'en');

-- Test learner
INSERT INTO learners (user_id, name, date_of_birth, gender, focus_areas) VALUES
  ((SELECT id FROM users WHERE email = 'test@komal.com'), 'Test Child', '2015-01-01', 'male', ARRAY['social-skills', 'emotional-intelligence']);
*/

-- ============================================================================
-- END OF SETUP
-- ============================================================================
-- Your Komal database is now set up in Supabase.
--
-- This file includes all features from supabase_setup.sql plus:
-- - profiles table for parent/user profile information
-- - session_analytics table for detailed session analytics
-- - subdomain_history table for subdomain assessment tracking
-- - Helper functions (no triggers - all operations are manual)
-- - Backward compatibility views
--
-- IMPORTANT: All triggers have been removed for simplicity
-- The web app must handle:
-- - Creating users and profiles after signup (call handle_new_user() or ensure_user_exists())
-- - Updating updated_at timestamps manually
-- - Calculating learner age when creating/updating learners
--
-- Next steps:
-- 1. Run this SQL file in Supabase SQL Editor
-- 2. Update web/src/services/supabase.js with your API keys
-- 3. In your signup handler, call: SELECT handle_new_user();
-- 4. In your login handler, call: SELECT ensure_user_exists();
-- 5. Test authentication: npm run dev
-- ============================================================================

