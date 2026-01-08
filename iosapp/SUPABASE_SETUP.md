# Supabase Setup Guide for Komal

This guide will help you connect your Komal app to Supabase.

## Prerequisites

- Supabase account
- Your Supabase project: https://supabase.com/dashboard/project/afxixmsfkiylnvatsopm

## Step 1: Get Your Supabase Credentials

1. Go to your Supabase project: https://supabase.com/dashboard/project/afxixmsfkiylnvatsopm/settings/api

2. Copy these values:
   - **Project URL**: `https://afxixmsfkiylnvatsopm.supabase.co`
   - **anon public key**: A long string starting with `eyJ...`

## Step 2: Configure Environment Variables

1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` and add your credentials:
   ```
   VITE_SUPABASE_URL=https://afxixmsfkiylnvatsopm.supabase.co
   VITE_SUPABASE_ANON_KEY=your_anon_key_from_step_1
   ```

## Step 3: Create Database Tables

1. Go to your Supabase SQL Editor:
   https://supabase.com/dashboard/project/afxixmsfkiylnvatsopm/editor

2. Copy the entire contents of `supabase_setup.sql`

3. Paste into the SQL Editor and click **Run**

4. You should see tables created:
   - ✅ `users`
   - ✅ `learners`
   - ✅ `sessions`
   - ✅ `analytics`

5. Verify in the Table Editor:
   https://supabase.com/dashboard/project/afxixmsfkiylnvatsopm/editor

## Step 4: Configure Authentication

1. Go to Authentication settings:
   https://supabase.com/dashboard/project/afxixmsfkiylnvatsopm/auth/providers

2. Enable these providers:
   - **Email** (for email/password login)
   - **Phone** (for SMS OTP - requires Twilio setup)
   - **Apple** (optional - for Sign in with Apple)

### Phone Authentication Setup (Optional but Recommended)

1. Go to Phone Auth settings:
   https://supabase.com/dashboard/project/afxixmsfkiylnvatsopm/auth/providers

2. Enable Phone provider

3. Add Twilio credentials:
   - Get Twilio Account SID and Auth Token from https://console.twilio.com
   - Add your Twilio phone number
   - Save

4. Test: Your app will now be able to send OTPs via SMS

### Email Settings

1. Go to Email Templates:
   https://supabase.com/dashboard/project/afxixmsfkiylnvatsopm/auth/templates

2. Customize email templates:
   - Confirmation email
   - Reset password email
   - Magic link email

3. Configure SMTP (optional - for custom email domain):
   - Go to Settings > Project Settings > Email
   - Add your SMTP credentials

## Step 5: Configure Row Level Security (RLS)

The SQL script already set up RLS policies, but verify:

1. Go to Authentication > Policies:
   https://supabase.com/dashboard/project/afxixmsfkiylnvatsopm/auth/policies

2. Verify policies exist for:
   - `users` table
   - `learners` table
   - `sessions` table
   - `analytics` table

3. Test with the Policy Editor to ensure users can only access their own data

## Step 6: Install Dependencies

```bash
npm install
```

This will install `@supabase/supabase-js` along with other dependencies.

## Step 7: Test the Connection

1. Start the development server:
   ```bash
   npm run dev
   ```

2. Open the browser console (F12)

3. You should see:
   ```
   [Supabase] Client initialized
   ```

4. Try signing up:
   - Go to `/signin`
   - Create an account with email or phone
   - Check Supabase Authentication tab to see the new user

## Step 8: Verify Data Sync

1. Create a learner profile in the app

2. Check Supabase Table Editor:
   https://supabase.com/dashboard/project/afxixmsfkiylnvatsopm/editor

3. You should see data in:
   - `users` table
   - `learners` table

4. Start a session in the app

5. Check `sessions` table for the session data

## Troubleshooting

### "Supabase not configured" error

**Problem**: The app can't connect to Supabase

**Solution**:
1. Check `.env` file exists and has correct values
2. Restart development server: `npm run dev`
3. Clear browser cache and reload

### "Failed to fetch" error

**Problem**: Network error or CORS issue

**Solution**:
1. Check your internet connection
2. Verify Supabase project is running (not paused)
3. Check API URL is correct in `.env`

### "JWT expired" or "Invalid token" error

**Problem**: Session expired

**Solution**:
1. Log out and log in again
2. Check Authentication > Settings > JWT expiry
3. Clear localStorage: `localStorage.clear()` in console

### Phone authentication not working

**Problem**: SMS not being sent

**Solution**:
1. Verify Twilio credentials are correct
2. Check Twilio account balance
3. Verify phone number format is E.164 (e.g., +1234567890)
4. Check Supabase logs for errors

### Data not syncing

**Problem**: Local data not appearing in Supabase

**Solution**:
1. Check browser console for errors
2. Verify Row Level Security policies allow insert/update
3. Check network tab for failed requests
4. Verify you're online (check `navigator.onLine`)

## Advanced Configuration

### Enable Realtime

To get live updates when parent dashboard is open:

1. Go to Database > Replication:
   https://supabase.com/dashboard/project/afxixmsfkiylnvatsopm/database/replication

2. Enable replication for `sessions` table

3. The app will automatically subscribe to changes

### Configure Storage for Avatars

To upload custom avatar images:

1. Go to Storage:
   https://supabase.com/dashboard/project/afxixmsfkiylnvatsopm/storage/buckets

2. Create a new bucket: `avatars`

3. Make it public or set RLS policies

4. Update app to use Supabase Storage for avatar uploads

### Set up Edge Functions (Optional)

For server-side processing (e.g., report generation):

1. Install Supabase CLI:
   ```bash
   npm install -g supabase
   ```

2. Initialize functions:
   ```bash
   supabase functions new generate-report
   ```

3. Deploy:
   ```bash
   supabase functions deploy generate-report
   ```

## Production Checklist

Before deploying to production:

- [ ] Environment variables set in hosting platform (Vercel/Netlify)
- [ ] Email templates customized with your branding
- [ ] Phone authentication tested with real phone numbers
- [ ] RLS policies reviewed and tested
- [ ] Rate limiting configured in Supabase settings
- [ ] Backup policy configured
- [ ] Monitoring and alerts set up
- [ ] GDPR compliance verified (data export, deletion)
- [ ] Custom domain configured (optional)
- [ ] SSL certificate valid

## Monitoring

Track your app usage:

1. Analytics:
   https://supabase.com/dashboard/project/afxixmsfkiylnvatsopm/reports

2. Logs:
   https://supabase.com/dashboard/project/afxixmsfkiylnvatsopm/logs

3. Database performance:
   https://supabase.com/dashboard/project/afxixmsfkiylnvatsopm/database/query-performance

## Support

- **Supabase Docs**: https://supabase.com/docs
- **Supabase Discord**: https://discord.supabase.com
- **Komal Support**: komalforkids@gmail.com

## Next Steps

Once Supabase is connected:

1. ✅ Users can sign up and log in
2. ✅ Data syncs between device and cloud
3. ✅ Multiple devices can access same account
4. ✅ Parent dashboard shows real-time data
5. ✅ Offline mode works with auto-sync when online

Happy building! 🎉
