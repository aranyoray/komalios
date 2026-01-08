# Google Play Console - Deep Link Setup Steps

## ✅ What We Fixed

1. **Removed HTTPS deep link** from AndroidManifest.xml (since you don't own `komal.app`)
2. **Kept app scheme deep links** which work without domain verification:
   - `com.komalkids.app://auth/confirm` (preferred - already in your code)
   - `komal://auth/confirm` (alternative)

## 📋 Steps for Google Play Console

### Step 1: Remove HTTPS Link (if added)
1. Go to **Google Play Console**
2. Navigate to **App content** → **App links** (or **Deep links**)
3. Find the path `/auth/confirm`
4. **Remove** or **don't add** `https://komal.app/auth/confirm`
5. This link requires domain verification which you can't do without owning the domain

### Step 2: Use App Scheme Instead (Optional)
App scheme links work automatically - you don't need to add them in Google Play Console. However, if you want to document them:

1. In **App content** → **App links**
2. Add path: `/auth/confirm`
3. Add link: `com.komalkids.app://auth/confirm`
4. **No verification needed** ✅

**Note:** App scheme links don't require verification in Google Play Console. They work automatically based on your AndroidManifest.xml configuration.

### Step 3: Test Your Deep Links

After building and installing your app, test the deep link:

```bash
adb shell am start -a android.intent.action.VIEW -d "com.komalkids.app://auth/confirm?token=test123"
```

Or test the custom scheme:
```bash
adb shell am start -a android.intent.action.VIEW -d "komal://auth/confirm?token=test123"
```

## ✅ What's Already Working

- ✅ Your code (`AuthContext.jsx`) already uses `com.komalkids.app://auth/confirm` for native platforms
- ✅ AndroidManifest.xml has both app scheme deep links configured
- ✅ Deep link handler in `App.jsx` processes `/auth/confirm` path
- ✅ Email confirmation component (`EmailConfirm.jsx`) handles the confirmation

## 🎯 Summary

**You don't need to do anything in Google Play Console!** 

The app scheme deep links (`com.komalkids.app://auth/confirm`) work automatically without verification. The error you saw was only for the HTTPS link which we've now removed.

When users click email confirmation links:
- **Native app**: Opens directly with `com.komalkids.app://auth/confirm`
- **Web browser**: Falls back to web URL (if they're not on mobile)

Everything is already configured correctly! 🎉

