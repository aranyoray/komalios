# Database Setup Comparison

## Analysis Summary

After analyzing the `web/` folder and comparing with the existing `supabase_setup.sql`, I've created a comprehensive `web/database_setup.sql` file that includes all tables needed to run the web application.

## Key Differences & Additions

### ✅ **New Tables Added**

1. **`session_analytics`** - NEW
   - **Purpose**: Stores detailed session-level analytics for dashboard and reports
   - **Used by**: `web/src/services/analytics.js`
   - **Fields**: 
     - `attention_score`, `engagement_score`, `completion_rate`
     - `emotion_data`, `gaze_heatmap`, `focus_areas`
     - `difficulty_level`, `responses`
   - **Why needed**: The analytics service directly queries this table for dashboard metrics

2. **`subdomain_history`** - NEW
   - **Purpose**: Stores subdomain assessment scores over time for trend analysis
   - **Used by**: 
     - `web/src/hooks/useSubdomainTracking.js`
     - `web/src/services/historicalData.js`
   - **Fields**:
     - `subdomain_id`, `domain_id`
     - `score`, `confidence`, `metrics`
   - **Why needed**: Tracks subdomain progress over time for assessment framework

### 📝 **Enhanced Existing Tables**

#### **`learners` Table**
- **Added**: `subdomain_assessment_history` (JSONB) - Stores assessment history
- **Added**: `diagnoses` (TEXT[]) - For clinical use
- **Enhanced**: `settings` JSONB now includes `sessionDuration`, `difficulty`, `rewards`

#### **`sessions` Table**
- **Added**: `correlations` (JSONB) - Cross-modal correlation data
- **Added**: `concise_report` (JSONB) - Generated concise report
- **Added**: `extended_report` (JSONB) - Generated extended report
- **Added**: `synced_to_cloud` (BOOLEAN) - Sync status tracking
- **Added**: `last_sync_attempt` (TIMESTAMPTZ) - Last sync timestamp

#### **`users` Table**
- **Enhanced**: `auth_method` now includes 'google' option
- **Enhanced**: `language` supports all 24 languages from i18n system

### 🔍 **Code Analysis Findings**

#### Tables Referenced in Web App:
1. ✅ `users` - Used in `supabaseDB.js`, `AuthContext.jsx`
2. ✅ `learners` - Used in `supabaseDB.js` (also referenced as 'profiles' in some files)
3. ✅ `sessions` - Used in `supabaseDB.js`, `useSession.js`
4. ✅ `analytics` - Used in `supabaseDB.js`
5. ✅ `session_analytics` - Used in `analytics.js` service
6. ⚠️ `profiles` - Referenced in some auth files, but appears to be an alias for `learners`

#### Note on 'profiles' Table:
Some code files reference a `profiles` table:
- `web/src/contexts/AuthContext.jsx`
- `web/src/pages/Auth/CreateProfile.jsx`
- `web/src/pages/Auth/ProfileSelect.jsx`

**Resolution**: The `learners` table serves as the profiles table. The code should be updated to use `learners` consistently, OR a view/alias can be created. For now, the SQL file uses `learners` as the canonical table.

### 📊 **Indexes Added**

**New indexes for performance:**
- `idx_sessions_synced` - For finding unsynced sessions
- `idx_sessions_learner_start_time` - Composite index for common queries
- `idx_session_analytics_*` - Multiple indexes for analytics queries
- `idx_subdomain_history_*` - Indexes for subdomain trend analysis

### 🔐 **RLS Policies Enhanced**

**New policies added:**
- Policies for `session_analytics` table
- Policies for `subdomain_history` table
- INSERT policies for all tables (were missing in original)

### 🛠️ **Functions & Views Added**

**New helper functions:**
- `validate_session_data()` - Validates session JSONB structure
- `get_learner_session_count()` - Gets session count for a learner
- `get_learner_avg_engagement()` - Calculates average engagement

**New views:**
- `recent_sessions_view` - Recent sessions with learner info
- `learner_progress_view` - Learner progress summary

### 📋 **Complete Table List**

| Table | Status | Purpose |
|-------|--------|---------|
| `users` | ✅ Enhanced | Parent/guardian accounts |
| `learners` | ✅ Enhanced | Child/learner profiles |
| `sessions` | ✅ Enhanced | Session data with tracking |
| `analytics` | ✅ Existing | Aggregated analytics |
| `session_analytics` | 🆕 NEW | Session-level analytics |
| `subdomain_history` | 🆕 NEW | Subdomain assessment history |

## Migration Path

### If you have existing data:

1. **Backup your database first!**
2. Run the new SQL file - it uses `CREATE TABLE IF NOT EXISTS` so existing tables won't be affected
3. Add new columns to existing tables:
   ```sql
   -- Add to learners table
   ALTER TABLE learners ADD COLUMN IF NOT EXISTS subdomain_assessment_history JSONB DEFAULT '{}'::jsonb;
   ALTER TABLE learners ADD COLUMN IF NOT EXISTS diagnoses TEXT[];
   
   -- Add to sessions table
   ALTER TABLE sessions ADD COLUMN IF NOT EXISTS correlations JSONB DEFAULT '{}'::jsonb;
   ALTER TABLE sessions ADD COLUMN IF NOT EXISTS concise_report JSONB;
   ALTER TABLE sessions ADD COLUMN IF NOT EXISTS extended_report JSONB;
   ALTER TABLE sessions ADD COLUMN IF NOT EXISTS synced_to_cloud BOOLEAN DEFAULT false;
   ALTER TABLE sessions ADD COLUMN IF NOT EXISTS last_sync_attempt TIMESTAMPTZ;
   ```
4. Create new tables: `session_analytics` and `subdomain_history`
5. Create new indexes and policies

## File Locations

- **Original SQL**: `/supabase_setup.sql` (root)
- **New SQL**: `/web/database_setup.sql` (web folder)
- **Use**: The new file in `web/database_setup.sql` for the web application

## Verification Checklist

After running the SQL:

- [ ] All 6 tables created successfully
- [ ] All indexes created
- [ ] RLS policies enabled and working
- [ ] Triggers created for updated_at
- [ ] Auth trigger working (creates user on signup)
- [ ] Views accessible
- [ ] Test insert/select/update operations
- [ ] Verify RLS policies allow authenticated users

## Next Steps

1. Run `web/database_setup.sql` in Supabase SQL Editor
2. Verify all tables are created
3. Test authentication flow
4. Test session creation
5. Test analytics queries
6. Update code to use consistent table names (learners vs profiles)

