# Supabase Multi-Provider Authentication Setup Guide

## Overview

This guide walks you through setting up multiple authentication providers in Supabase for the Komal app.

**Supported Providers:**
- ✅ Email/Password (credentials)
- ✅ Phone Number (SMS OTP)
- ✅ Google OAuth
- ✅ Apple Sign In
- ✅ Account Linking (multiple providers per user)

---

## Prerequisites

1. Supabase account (https://supabase.com)
2. Supabase project created
3. Node.js project with `@supabase/supabase-js` installed

```bash
npm install @supabase/supabase-js
```

---

## Step 1: Basic Supabase Setup

### 1.1 Get Your Credentials

1. Go to your Supabase project dashboard
2. Navigate to **Settings** → **API**
3. Copy these values:
   - `Project URL` → `VITE_SUPABASE_URL`
   - `anon public` key → `VITE_SUPABASE_ANON_KEY`

### 1.2 Create `.env` File

```env
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key-here
```

---

## Step 2: Enable Email/Password Authentication

### 2.1 Enable Email Provider

1. Go to **Authentication** → **Providers**
2. Find **Email** and click **Enable**
3. Configure settings:
   - ✅ **Enable email provider**
   - ✅ **Confirm email** (recommended for production)
   - Email templates can be customized under **Email Templates**

### 2.2 Customize Email Templates (Optional)

Go to **Authentication** → **Email Templates** to customize:
- Confirmation email
- Magic link email
- Password reset email

---

## Step 3: Enable Phone Number (SMS) Authentication

### 3.1 Choose SMS Provider

Supabase supports multiple SMS providers:
- **Twilio** (recommended, most reliable)
- **MessageBird**
- **Textlocal**
- **Vonage**

### 3.2 Setup with Twilio (Recommended)

1. Create a Twilio account: https://www.twilio.com
2. Get a phone number with SMS capabilities
3. Get your credentials:
   - Account SID
   - Auth Token

### 3.3 Configure in Supabase

1. Go to **Authentication** → **Providers**
2. Find **Phone** and click **Enable**
3. Select **Twilio** as provider
4. Enter:
   - **Twilio Account SID**: `your-account-sid`
   - **Twilio Auth Token**: `your-auth-token`
   - **Twilio Phone Number**: `+1234567890` (your Twilio number)
5. Click **Save**

### 3.4 Test Phone Auth

```javascript
import { signInWithPhone, verifyPhoneOTP } from './auth/supabaseAuth';

// Send OTP
await signInWithPhone('+1234567890');

// Verify OTP
await verifyPhoneOTP('+1234567890', '123456');
```

**Important Notes:**
- Phone numbers must include country code (e.g., `+1` for US)
- Twilio trial accounts can only send to verified numbers
- Production requires purchasing a phone number (~$1/month)

---

## Step 4: Enable Google OAuth

### 4.1 Create Google OAuth Application

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project or select existing
3. Navigate to **APIs & Services** → **Credentials**
4. Click **Create Credentials** → **OAuth client ID**
5. Configure OAuth consent screen if not done:
   - Application name: `Komal`
   - User support email: your email
   - Scopes: `email`, `profile`
6. Create OAuth Client ID:
   - Application type: **Web application**
   - Name: `Komal Web Client`
   - Authorized JavaScript origins:
     - `https://your-project.supabase.co`
     - `http://localhost:5173` (for local development)
   - Authorized redirect URIs:
     - `https://your-project.supabase.co/auth/v1/callback`
     - `http://localhost:5173/auth/callback`

7. Copy **Client ID** and **Client Secret**

### 4.2 Configure in Supabase

1. Go to **Authentication** → **Providers**
2. Find **Google** and click **Enable**
3. Enter:
   - **Client ID**: `your-google-client-id`
   - **Client Secret**: `your-google-client-secret`
4. Click **Save**

### 4.3 Test Google Sign In

```javascript
import { signInWithOAuth } from './auth/supabaseAuth';

await signInWithOAuth('google');
// User will be redirected to Google sign-in
```

---

## Step 5: Enable Apple Sign In

### 5.1 Requirements

- Apple Developer Account ($99/year)
- App registered in Apple Developer Portal

### 5.2 Create Apple Service ID

1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Select **Identifiers** → **App IDs**
4. Create new App ID:
   - Description: `Komal App`
   - Bundle ID: `com.komal.app` (your unique identifier)
   - Enable **Sign In with Apple**

5. Create Service ID:
   - Go to **Identifiers** → **Services IDs**
   - Create new Service ID
   - Identifier: `com.komal.service` (different from App ID)
   - Enable **Sign In with Apple**
   - Configure:
     - Domains: `your-project.supabase.co`
     - Return URLs: `https://your-project.supabase.co/auth/v1/callback`

### 5.3 Create Apple Sign In Key

1. Go to **Keys** in Apple Developer Portal
2. Click **+** to create new key
3. Name: `Komal Sign In Key`
4. Enable **Sign In with Apple**
5. Configure with your App ID
6. Download `.p8` key file (save securely!)
7. Note the **Key ID** (10 characters)

### 5.4 Configure in Supabase

1. Go to **Authentication** → **Providers**
2. Find **Apple** and click **Enable**
3. Enter:
   - **Service ID**: `com.komal.service`
   - **Team ID**: Found in Apple Developer Portal (10 characters)
   - **Key ID**: From the .p8 key you created
   - **Private Key**: Open the .p8 file and paste contents
4. Click **Save**

### 5.5 Test Apple Sign In

```javascript
await signInWithOAuth('apple');
// User will be redirected to Apple sign-in
```

**Important Notes:**
- Apple Sign In only works on HTTPS (not localhost)
- Use ngrok or deploy to test: `ngrok http 5173`
- Update redirect URLs in both Apple and Supabase

---

## Step 6: Enable Account Linking (Multiple Providers)

### 6.1 Enable Manual Linking in Supabase

1. Go to **Authentication** → **Settings**
2. Find **Manual Linking** section
3. ✅ Enable **Allow manual linking of accounts**
4. Click **Save**

This allows users to link multiple auth providers (e.g., sign up with email, then link Google).

### 6.2 Database Schema for Identity Tracking

Supabase automatically creates `auth.identities` table to track linked providers.

**Query linked identities:**

```sql
SELECT
  id,
  user_id,
  provider,
  created_at
FROM auth.identities
WHERE user_id = 'user-uuid-here';
```

### 6.3 Link Additional Provider (Code)

```javascript
import { linkAuthProvider, getLinkedIdentities } from './auth/supabaseAuth';

// User must be signed in first
const user = await getCurrentUser();

// Link Google to existing account
await linkAuthProvider('google');

// Check all linked providers
const identities = await getLinkedIdentities();
console.log(identities);
// [
//   { provider: 'email', ... },
//   { provider: 'google', ... }
// ]
```

### 6.4 Unlink Provider

```javascript
import { unlinkAuthProvider } from './auth/supabaseAuth';

// Remove Google from account
await unlinkAuthProvider('google');
```

**Important:**
- User must have at least one auth method remaining
- Cannot unlink the last provider

---

## Step 7: Security Best Practices

### 7.1 Row Level Security (RLS)

Enable RLS on all tables to ensure users can only access their own data:

```sql
-- Enable RLS on learners table
ALTER TABLE learners ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own learner profiles
CREATE POLICY "Users can view own learners"
  ON learners
  FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Users can insert their own learners
CREATE POLICY "Users can insert own learners"
  ON learners
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own learners
CREATE POLICY "Users can update own learners"
  ON learners
  FOR UPDATE
  USING (auth.uid() = user_id);
```

### 7.2 Email Rate Limiting

Go to **Authentication** → **Rate Limits** and configure:
- Email sends per hour: `10` (prevent spam)
- SMS sends per hour: `5` (Twilio charges per SMS)

### 7.3 Password Requirements

Go to **Authentication** → **Policies**:
- Minimum password length: `8`
- Require uppercase: ✅
- Require numbers: ✅
- Require special characters: ✅

---

## Step 8: Handle Auth Callbacks

### 8.1 Create Auth Callback Route

Create `src/pages/auth/AuthCallback.jsx`:

```javascript
import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../../auth/supabaseAuth';

export default function AuthCallback() {
  const navigate = useNavigate();

  useEffect(() => {
    // Handle OAuth callback
    supabase.auth.onAuthStateChange((event, session) => {
      if (session) {
        navigate('/dashboard');
      } else {
        navigate('/login');
      }
    });
  }, [navigate]);

  return <div>Completing sign in...</div>;
}
```

### 8.2 Add Route

In `src/App.jsx`:

```javascript
<Route path="/auth/callback" element={<AuthCallback />} />
```

---

## Step 9: User Metadata & Profiles

### 9.1 Store Additional User Data

When signing up, add metadata:

```javascript
await signUpWithEmail('user@example.com', 'password', {
  full_name: 'John Doe',
  age_band: '6-10',
  language: 'en',
  role: 'parent'
});
```

### 9.2 Create User Profile Table

```sql
CREATE TABLE user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  age_band TEXT,
  language TEXT DEFAULT 'en',
  role TEXT DEFAULT 'parent',
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
  ON user_profiles
  FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON user_profiles
  FOR UPDATE
  USING (auth.uid() = id);
```

### 9.3 Trigger to Create Profile on Signup

```sql
CREATE OR REPLACE FUNCTION create_user_profile()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_profiles (id, full_name, age_band, language, role)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'age_band',
    NEW.raw_user_meta_data->>'language',
    NEW.raw_user_meta_data->>'role'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION create_user_profile();
```

---

## Step 10: Testing the Complete Flow

### 10.1 Test Email Sign Up

```javascript
import { signUpWithEmail } from './auth/supabaseAuth';

await signUpWithEmail('test@example.com', 'SecurePassword123!', {
  full_name: 'Test User',
  role: 'parent'
});
// User receives confirmation email
```

### 10.2 Test Phone Sign In

```javascript
await signInWithPhone('+1234567890');
// SMS sent with 6-digit code

await verifyPhoneOTP('+1234567890', '123456');
// User signed in
```

### 10.3 Test OAuth

```javascript
await signInWithOAuth('google');
// Redirects to Google sign-in
// Returns to /auth/callback
// User signed in
```

### 10.4 Test Account Linking

```javascript
// Sign in with email
await signInWithEmail('test@example.com', 'password');

// Link Google account
await linkAuthProvider('google');

// Now user can sign in with either email OR Google
```

---

## Troubleshooting

### Issue: "Email not confirmed"

**Solution:**
- Development: Disable email confirmation in Authentication → Settings
- Production: User must click confirmation link in email

### Issue: "Invalid OAuth redirect URI"

**Solution:**
- Verify redirect URI in both Supabase and provider (Google/Apple)
- Must match exactly: `https://your-project.supabase.co/auth/v1/callback`

### Issue: "Phone number already registered"

**Solution:**
- Phone numbers are unique per project
- User should sign in instead of signing up
- Or use different phone number

### Issue: "Cannot link identity, email already exists"

**Solution:**
- Supabase prevents linking if email from OAuth provider already exists
- User should sign in with that email first, then link

### Issue: "Apple Sign In not working on localhost"

**Solution:**
- Apple requires HTTPS
- Use ngrok: `ngrok http 5173`
- Update redirect URIs in Apple Developer Portal and Supabase

---

## Environment Variables Summary

Add to `.env`:

```env
# Supabase
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key

# OAuth Redirect (for local dev)
VITE_AUTH_REDIRECT_URL=http://localhost:5173/auth/callback
```

---

## Next Steps

1. ✅ Set up all auth providers
2. ✅ Test each auth method
3. ✅ Enable RLS on all tables
4. ✅ Create user profile table and trigger
5. ✅ Implement account linking UI
6. ✅ Add password reset flow
7. ✅ Configure email templates
8. ✅ Set up rate limiting

---

## Additional Resources

- [Supabase Auth Docs](https://supabase.com/docs/guides/auth)
- [Google OAuth Setup](https://support.google.com/cloud/answer/6158849)
- [Apple Sign In Guide](https://developer.apple.com/sign-in-with-apple/)
- [Twilio SMS Setup](https://www.twilio.com/docs/sms)
