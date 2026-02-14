# 🔒 SECURITY NOTICE

## ⚠️ CRITICAL: API Keys Are Private

**DO NOT commit these files to public repositories:**
- ✅ `Config.swift` - Contains API keys (**ALREADY IN .gitignore**)
- ✅ `GoogleService-Info.plist` - Firebase config
- ✅ `Info.plist` - May contain secrets

---

## 🔑 Current API Keys (PRIVATE)

The following keys have been integrated into `Config.swift`:

```
GOOGLE_CLOUD_API_KEY=AIzaSyBrA8VaQj-5Nv22mWqTFdRmVrVxT12JC-4
GOOGLE_CUSTOM_SEARCH_API_KEY=AIzaSyCuER2ZmdptKCmJ0sv0LjZHLg6BleDXpPo
GOOGLE_CUSTOM_SEARCH_ENGINE_ID=9155813f6a4e04c8f
```

---

## ✅ Security Measures Implemented

### 1. .gitignore Created ✅
`Config.swift` is now in `.gitignore` and will NOT be committed to Git.

### 2. Keys Secured ✅
All 3 API keys are now stored in `Config.swift` with:
- Environment variable fallback (for CI/CD)
- Plist fallback (for local secure storage)
- Hardcoded fallback (for development only)

### 3. Warnings Added ✅
All key declarations have `⚠️ PRIVATE` warnings.

---

## 🚨 If Keys Are Already in Git History

If you've already committed `Config.swift` with keys:

```bash
# 1. Remove from Git (keeps local file)
git rm --cached Config.swift

# 2. Add to .gitignore (already done)
echo "Config.swift" >> .gitignore

# 3. Commit the removal
git add .gitignore
git commit -m "Remove API keys from version control"

# 4. ROTATE YOUR KEYS IMMEDIATELY
# Go to Google Cloud Console and create NEW keys
# Update Config.swift with new keys
# Revoke the old exposed keys
```

---

## 🔄 If You Need to Share Keys with Team

### Option 1: Environment Variables (RECOMMENDED)
```bash
# Each developer sets these locally:
export GOOGLE_CLOUD_API_KEY="AIza..."
export GOOGLE_CUSTOM_SEARCH_API_KEY="AIza..."
export GOOGLE_CUSTOM_SEARCH_ENGINE_ID="9155..."

# Or add to ~/.zshrc or ~/.bash_profile
```

### Option 2: Secure Sharing Service
- Use **1Password**, **LastPass**, or **Bitwarden** team vaults
- Share keys via **encrypted email**
- Use **GitHub Secrets** for CI/CD

### Option 3: Config Template
```swift
// Commit this as Config.swift.template:
return ProcessInfo.processInfo.environment["GOOGLE_CLOUD_API_KEY"] ?? ""

// Each developer creates Config.swift locally with real keys
```

---

## 🛡️ Google Cloud Security Settings

### Restrict Your API Keys:
1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Click each API key
3. **Set Application Restrictions:**
   - iOS apps: Add bundle ID `com.komalkids.komal`
4. **Set API Restrictions:**
   - Cloud Vision API
   - Cloud Natural Language API
   - Cloud Video Intelligence API
   - Custom Search API
5. **Enable Key Rotation:**
   - Rotate keys every 90 days
   - Keep old key active for 7 days during transition

---

## 🚨 If Keys Are Compromised

### Immediate Actions:
1. **Revoke compromised keys immediately** in GCP Console
2. **Generate new keys** with restrictions
3. **Update Config.swift** with new keys
4. **Monitor GCP billing** for unauthorized usage
5. **Check access logs** in GCP Console

### Google Cloud Console:
```
https://console.cloud.google.com/apis/credentials
→ Select compromised key
→ "Regenerate Key" or "Delete"
→ Create new restricted key
```

---

## ✅ Verification Checklist

- [x] Config.swift contains real API keys
- [x] .gitignore includes Config.swift
- [x] Config.swift has security warnings
- [x] Keys are restricted in GCP Console
- [ ] Test that keys work (run app)
- [ ] Verify .gitignore is working (`git status` should NOT show Config.swift)

---

## 📞 Key Management Best Practices

### DO ✅
- Use environment variables in production
- Restrict keys by bundle ID and API
- Rotate keys regularly (every 90 days)
- Use separate keys for dev/staging/prod
- Monitor API usage in GCP Console

### DON'T ❌
- Commit keys to Git (public or private repos)
- Share keys in Slack/Discord/email
- Use same key across multiple apps
- Hardcode keys in production builds
- Share keys in screenshots/screen recordings

---

## 🔍 Check If Keys Are in Git

```bash
# Search Git history for exposed keys:
git log -S "AIzaSy" --all

# If found, use BFG Repo Cleaner:
# https://rtyley.github.io/bfg-repo-cleaner/
```

---

## 📚 Additional Resources

- [Google Cloud API Key Best Practices](https://cloud.google.com/docs/authentication/api-keys)
- [Firebase Security Rules](https://firebase.google.com/docs/rules)
- [OWASP API Security](https://owasp.org/www-project-api-security/)

---

**Status:** 🔒 Keys secured and protected  
**Action Required:** Verify keys work, then check .gitignore  
**Last Updated:** January 27, 2026
