# Firebase Console Setup Guide

## Required Steps in Firebase Console

### 1. Create Firestore Database
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `komal-learn-with-ai`
3. Click on **"Firestore Database"** in the left sidebar
4. Click **"Create database"**
5. Choose **"Start in test mode"** (we'll update rules)
6. Select a location (e.g., `us-central1`)
7. Click **"Enable"**

### 2. Set Security Rules
1. In Firestore Database, go to **"Rules"** tab
2. Replace the default rules with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection - users can only read/write their own data
    match /users/{userId} {
      // Allow read if user is authenticated and reading their own data
      allow read: if request.auth != null && request.auth.uid == userId;
      
      // Allow write if user is authenticated and writing their own data
      allow write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

3. Click **"Publish"**

### 3. Verify Google Sign-In
1. Go to **Authentication** → **Sign-in method**
2. Ensure **"Google"** is enabled
3. Verify the OAuth client ID matches your app

### 4. Verify Project Configuration
1. Go to **Project Settings** → **General**
2. Confirm iOS bundle ID: `com.komalkids.komal`
3. Ensure `GoogleService-Info.plist` is up to date

## Firestore Collection Structure

The app will automatically create:
- **Collection**: `users`
- **Document ID**: User's Firebase Auth UID
- **Fields**:
  - `uid`: String
  - `email`: String?
  - `displayName`: String?
  - `photoURL`: String?
  - `provider`: String ("google", "apple", etc.)
  - `createdAt`: Timestamp
  - `lastLoginAt`: Timestamp
  - `isActive`: Boolean

## Testing

After setup:
1. Run the app
2. Sign in with Google
3. Check Firestore Console → `users` collection
4. Verify user document is created with correct data
