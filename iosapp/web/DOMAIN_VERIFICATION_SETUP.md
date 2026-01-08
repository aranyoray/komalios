# Google Play Console Deep Link Domain Verification Setup

## Problem
Google Play Console requires domain verification for HTTPS deep links (`https://komal.app/auth/confirm`). The domain `komal.app` needs to be verified by hosting a Digital Asset Links file.

## Solution Options

### Option 1: Verify Domain with Digital Asset Links (Recommended for HTTPS links)

#### Step 1: Get Your App's SHA-256 Fingerprint

You need to get the SHA-256 fingerprint of your app signing key. Use one of these methods:

**Method A: From Google Play Console (Easiest)**
1. Go to Google Play Console
2. Select your app
3. Go to **Release** > **Setup** > **App signing**
4. Copy the **SHA-256 certificate fingerprint** from the "App signing key certificate" section

**Method B: From Your Keystore File**
```bash
# Replace 'your-keystore.jks' with your actual keystore file path
# Replace 'your-key-alias' with your key alias
keytool -list -v -keystore android/app/your-keystore.jks -alias your-key-alias
```
Look for the SHA-256 value in the output.

**Method C: From Upload Certificate (if using Play App Signing)**
1. Go to Google Play Console
2. **Release** > **Setup** > **App signing**
3. Under "Upload key certificate", copy the SHA-256 fingerprint

#### Step 2: Create assetlinks.json File

Create a file named `assetlinks.json` with the following content (replace `YOUR_SHA256_FINGERPRINT` with your actual SHA-256 fingerprint):

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.komalkids.app",
    "sha256_cert_fingerprints": [
      "YOUR_SHA256_FINGERPRINT"
    ]
  }
}]
```

**Important:** The SHA-256 fingerprint should be in uppercase, with colons removed (e.g., `A1:B2:C3:...` becomes `A1B2C3...`).

#### Step 3: Host the File on Your Domain

1. Upload the `assetlinks.json` file to your web server
2. Place it at: `https://komal.app/.well-known/assetlinks.json`
3. Ensure the file is:
   - Accessible via HTTPS
   - Served with `Content-Type: application/json`
   - Returns HTTP 200 status code
   - No redirects

**Example using Apache (.htaccess):**
```apache
<Files "assetlinks.json">
    Header set Content-Type "application/json"
</Files>
```

**Example using Nginx:**
```nginx
location /.well-known/assetlinks.json {
    add_header Content-Type application/json;
    add_header Access-Control-Allow-Origin *;
}
```

#### Step 4: Verify the File is Accessible

Test that the file is accessible:
```bash
curl https://komal.app/.well-known/assetlinks.json
```

You should see your JSON content returned.

#### Step 5: Verify in Google Play Console

1. Go to Google Play Console
2. Navigate to **App content** > **App links** (or **Deep links**)
3. Click on the path `/auth/confirm`
4. Click **Verify domain** or wait for automatic verification (can take a few minutes to hours)
5. Once verified, the status should change to "Link working"

### Option 2: Use App Scheme Deep Links (No Domain Verification Required)

If you don't have access to host files on `komal.app`, you can use app scheme deep links instead. These don't require domain verification.

#### Update Supabase Email Confirmation Redirect

In your Supabase dashboard or code, change the redirect URL from:
```
https://komal.app/auth/confirm
```

To:
```
com.komalkids.app://auth/confirm
```

This scheme is already configured in your `AndroidManifest.xml` (lines 38-47).

#### Update AndroidManifest.xml (if needed)

Your manifest already has the app scheme configured, but ensure it's correct:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
        android:scheme="com.komalkids.app"
        android:host="auth"
        android:pathPrefix="/confirm" />
</intent-filter>
```

#### Update Google Play Console

1. Go to Google Play Console
2. Navigate to **App content** > **App links**
3. Remove or don't add the HTTPS link `https://komal.app/auth/confirm`
4. Instead, use the app scheme: `com.komalkids.app://auth/confirm`
5. App scheme links don't require domain verification

**Note:** App scheme links will show a "Open with" dialog on Android, while verified HTTPS links open directly.

## Troubleshooting

### Domain Verification Fails

1. **Check file accessibility:**
   ```bash
   curl -I https://komal.app/.well-known/assetlinks.json
   ```
   Should return `200 OK` and `Content-Type: application/json`

2. **Check JSON validity:**
   ```bash
   curl https://komal.app/.well-known/assetlinks.json | python -m json.tool
   ```

3. **Verify SHA-256 fingerprint:**
   - Ensure it matches exactly (case-sensitive, no colons)
   - Use the SHA-256 from your app signing key, not upload key

4. **Check package name:**
   - Must match exactly: `com.komalkids.app`

5. **Wait for propagation:**
   - Google's verification can take up to 24 hours

### Testing Deep Links

**Test HTTPS link:**
```bash
adb shell am start -a android.intent.action.VIEW -d "https://komal.app/auth/confirm?token=test"
```

**Test app scheme link:**
```bash
adb shell am start -a android.intent.action.VIEW -d "com.komalkids.app://auth/confirm?token=test"
```

## Recommended Approach

1. **If you own `komal.app` domain:** Use Option 1 (HTTPS links with domain verification) for better user experience
2. **If you don't own the domain yet:** Use Option 2 (app scheme links) as a temporary solution
3. **For production:** HTTPS links are preferred as they open directly without showing the "Open with" dialog

## Additional Resources

- [Google Digital Asset Links Documentation](https://developers.google.com/digital-asset-links/v1/getting-started)
- [Android App Links Documentation](https://developer.android.com/training/app-links)
- [Google Play Console App Links Guide](https://support.google.com/googleplay/android-developer/answer/10188407)

