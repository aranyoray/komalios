# Quick Fix Guide: Google Play Console Deep Link Error

## The Problem
Google Play Console shows: "Deep links not working" and "Domain failed validation" for `komal.app`

## Quick Solution (Choose One)

### ✅ Option A: Use App Scheme (Fastest - No Domain Needed)

**This doesn't require domain verification!**

1. **Update Supabase Email Confirmation URL:**
   - In Supabase Dashboard → Authentication → URL Configuration
   - Change redirect URL to: `com.komalkids.app://auth/confirm`
   - Or update in your code where you set `redirectTo`

2. **Your AndroidManifest.xml already supports this** (lines 38-47)

3. **In Google Play Console:**
   - Go to App content → App links
   - Remove `https://komal.app/auth/confirm` 
   - Add `com.komalkids.app://auth/confirm` instead
   - App scheme links don't need verification ✅

**Done!** This works immediately.

---

### ✅ Option B: Verify Domain (Better UX - Requires Domain Access)

**If you own `komal.app` domain:**

1. **Get SHA-256 Fingerprint:**
   - Google Play Console → Release → Setup → App signing
   - Copy "SHA-256 certificate fingerprint"

2. **Create `assetlinks.json`:**
   ```json
   [{
     "relation": ["delegate_permission/common.handle_all_urls"],
     "target": {
       "namespace": "android_app",
       "package_name": "com.komalkids.app",
       "sha256_cert_fingerprints": ["YOUR_SHA256_HERE"]
     }
   }]
   ```

3. **Host it at:**
   ```
   https://komal.app/.well-known/assetlinks.json
   ```

4. **Verify:**
   ```bash
   curl https://komal.app/.well-known/assetlinks.json
   ```

5. **Wait:** Google verifies automatically (can take hours)

---

## Which Should You Choose?

- **Don't own domain yet?** → Use Option A (app scheme)
- **Own domain but need it working now?** → Use Option A first, then Option B
- **Want best user experience?** → Use Option B (HTTPS links)

Both options work! App scheme is faster to implement.

