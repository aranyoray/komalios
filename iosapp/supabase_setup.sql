-- Komal Database Schema for Supabase
-- Run this in your Supabase SQL Editor: https://supabase.com/dashboard/project/afxixmsfkiylnvatsopm/editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable Row Level Security
ALTER DATABASE postgres SET "app.jwt_secret" TO 'your-jwt-secret';

-- ============================================================================
-- USERS TABLE
-- Stores parent/guardian account information
-- ============================================================================
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  auth_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  phone_number TEXT UNIQUE,
  email TEXT,
  auth_method TEXT CHECK (auth_method IN ('phone', 'email', 'apple', 'guest')),
  language TEXT DEFAULT 'en' CHECK (language IN ('en', 'hi', 'bn')),
  pin_hash TEXT, -- Hashed PIN for parent access
  face_id_enabled BOOLEAN DEFAULT false,
  subscription_status TEXT DEFAULT 'free' CHECK (subscription_status IN ('free', 'premium', 'trial')),
  subscription_tier TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_login TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- LEARNERS TABLE
-- Stores child/learner profiles
-- ============================================================================
CREATE TABLE IF NOT EXISTS learners (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  date_of_birth DATE,
  age INTEGER GENERATED ALWAYS AS (
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth))
  ) STORED,
  gender TEXT CHECK (gender IN ('male', 'female', 'other', 'prefer-not-to-say')),

  -- Focus areas (array)
  focus_areas TEXT[] DEFAULT ARRAY['social-skills'],

  -- Settings (JSONB for flexibility)
  settings JSONB DEFAULT '{
    "soundVolume": 0.7,
    "animationLevel": "medium",
    "preferredAvatar": "animal",
    "colorScheme": "default"
  }'::jsonb,

  -- Permissions
  permissions JSONB DEFAULT '{
    "camera": false,
    "microphone": false,
    "storage": false
  }'::jsonb,

  pin_hash TEXT, -- Optional PIN for multi-learner households
  profile_image TEXT, -- URL or base64
  is_active BOOLEAN DEFAULT true,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- SESSIONS TABLE
-- Stores therapy/learning session data
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
  eye_tracking JSONB DEFAULT '{}'::jsonb,
  micro_expressions JSONB DEFAULT '{}'::jsonb,
  touch_tracking JSONB DEFAULT '{}'::jsonb,
  voice_tracking JSONB DEFAULT '{}'::jsonb,
  response_patterns JSONB DEFAULT '{}'::jsonb,

  -- SEL metrics
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
-- INDEXES for Performance
-- ============================================================================

-- Users indexes
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone_number);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_auth_id ON users(auth_id);

-- Learners indexes
CREATE INDEX IF NOT EXISTS idx_learners_user_id ON learners(user_id);
CREATE INDEX IF NOT EXISTS idx_learners_active ON learners(is_active);

-- Sessions indexes
CREATE INDEX IF NOT EXISTS idx_sessions_learner_id ON sessions(learner_id);
CREATE INDEX IF NOT EXISTS idx_sessions_start_time ON sessions(start_time DESC);
CREATE INDEX IF NOT EXISTS idx_sessions_focus_area ON sessions(focus_area);
CREATE INDEX IF NOT EXISTS idx_sessions_created_at ON sessions(created_at DESC);

-- Analytics indexes
CREATE INDEX IF NOT EXISTS idx_analytics_learner_id ON analytics(learner_id);
CREATE INDEX IF NOT EXISTS idx_analytics_date_range ON analytics(start_date, end_date);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE learners ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics ENABLE ROW LEVEL SECURITY;

-- Users policies
CREATE POLICY "Users can view own data"
  ON users FOR SELECT
  USING (auth.uid() = auth_id);

CREATE POLICY "Users can update own data"
  ON users FOR UPDATE
  USING (auth.uid() = auth_id);

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

-- ============================================================================
-- FUNCTIONS & TRIGGERS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_learners_updated_at BEFORE UPDATE ON learners
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sessions_updated_at BEFORE UPDATE ON sessions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to create user record after auth signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (auth_id, email, auth_method)
  VALUES (
    NEW.id,
    NEW.email,
    CASE
      WHEN NEW.phone IS NOT NULL THEN 'phone'
      WHEN NEW.app_metadata->>'provider' = 'apple' THEN 'apple'
      ELSE 'email'
    END
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create user record after auth signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- REALTIME SUBSCRIPTIONS (Optional)
-- Enable realtime for sessions table so parents can see live updates
-- ============================================================================

ALTER PUBLICATION supabase_realtime ADD TABLE sessions;

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant access to authenticated users
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- ============================================================================
-- SEED DATA (Optional - for testing)
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
-- DONE!
-- ============================================================================
-- Your Komal database is now set up in Supabase.
--
-- Next steps:
-- 1. Update src/services/supabase.js with your API keys
-- 2. Test authentication: npm run dev
-- 3. Create your first user via the app
-- ============================================================================
