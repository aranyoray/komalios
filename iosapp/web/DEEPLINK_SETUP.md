# Deep Link Setup Guide for Email Confirmation

## ✅ Current Configuration

Your app ID is: `com.komalkids.app`

### Deep Link Schemes Configured:
1. **App ID based** (preferred): `com.komalkids.app://auth/confirm`
2. **Custom scheme**: `komal://auth/confirm`
3. **HTTPS scheme**: `https://komal.app/auth/confirm`

All three schemes are configured in `AndroidManifest.xml` and will work.

---

## 📋 Supabase Dashboard Configuration

### Step 1: Navigate to Supabase Dashboard
1. Go to: https://supabase.com/dashboard/project/afxixmsfkiylnvatsopm
2. Navigate to: **Authentication** → **URL Configuration**

### Step 2: Add Redirect URLs

In the **Redirect URLs** section, add these URLs (one per line):

```
com.komalkids.app://auth/confirm
komal://auth/confirm
https://komal.app/auth/confirm
http://localhost:5173/auth/confirm
```

**Note:** Replace `http://localhost:5173` with your actual development URL if different.

### Step 3: Site URL (if needed)
Make sure your **Site URL** is set correctly:
- Development: `http://localhost:5173` (or your dev server URL)
- Production: `https://komal.app` (or your production domain)

---

## 🔍 Verification Checklist

### ✅ Android Deep Links
- [x] `com.komalkids.app://auth/confirm` - Configured in AndroidManifest.xml
- [x] `komal://auth/confirm` - Configured in AndroidManifest.xml  
- [x] `https://komal.app/auth/confirm` - Configured in AndroidManifest.xml

### ✅ Code Configuration
- [x] Deep link handler in `App.jsx` - ✅ Configured
- [x] Email confirmation page - ✅ Created at `/auth/confirm`
- [x] Signup function uses correct redirect URL - ✅ Configured
- [x] Capacitor App plugin installed - ✅ Installed

---

## 🧪 Testing Deep Links

### Test on Android Device/Emulator:

1. **Test App ID based scheme:**
   ```bash
   adb shell am start -W -a android.intent.action.VIEW -d "com.komalkids.app://auth/confirm#access_token=test&type=signup" com.komalkids.app
   ```

2. **Test Custom scheme:**
   ```bash
   adb shell am start -W -a android.intent.action.VIEW -d "komal://auth/confirm#access_token=test&type=signup" com.komalkids.app
   ```

3. **Test HTTPS scheme:**
   ```bash
   adb shell am start -W -a android.intent.action.VIEW -d "https://komal.app/auth/confirm#access_token=test&type=signup" com.komalkids.app
   ```

### Test Email Confirmation Flow:
1. Sign up with a test email
2. Check email inbox for confirmation link
3. Click the link (should open the app)
4. App should navigate to `/auth/confirm` and verify the email

---

## 📱 How It Works

1. **User signs up** → Supabase sends confirmation email
2. **User clicks email link** → Supabase redirects to configured URL
3. **Native app opens** → Deep link handler captures URL
4. **App navigates** → Routes to `/auth/confirm` page
5. **Email verified** → Session created, user redirected to sign in

---

## 🔧 Troubleshooting

### Deep link not opening app:
- Check AndroidManifest.xml has all intent filters
- Verify app is installed on device
- Check Supabase redirect URLs are added correctly

### Email confirmation not working:
- Verify redirect URL in Supabase matches exactly
- Check browser console/logs for errors
- Ensure `/auth/confirm` route exists in App.jsx

### Hash fragments not preserved:
- Deep link handler preserves hash fragments automatically
- Check `EmailConfirm.jsx` handles hash tokens correctly

---

## 📝 Notes

- **App ID vs Custom Scheme**: Both work, but app ID based (`com.komalkids.app://`) is more standard
- **HTTPS Scheme**: Requires domain ownership and proper SSL certificate
- **Custom Scheme**: `komal://` is simpler but less standard
- **All three schemes** are configured for maximum compatibility

---

## ✅ Summary

**Your deep links are properly configured!** 

Just make sure to add all three redirect URLs in Supabase dashboard:
- `com.komalkids.app://auth/confirm`
- `komal://auth/confirm`
- `https://komal.app/auth/confirm`

No additional mobile configuration needed - everything is set up correctly! 🎉

