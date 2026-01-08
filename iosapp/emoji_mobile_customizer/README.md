# Emoji Mobile Customizer

React Native/Expo app for customizing Komal avatars on mobile devices.

## Requirements

- Node.js 18+
- Expo CLI
- iOS Simulator or Android Emulator (or physical device)

## Setup

```bash
npm install
npx expo start
```

## Features

- Touch-friendly avatar customization
- Real-time canvas preview
- Export to device gallery
- Accessibility support with large touch targets
- Parent-approved color palettes

## Project Structure

```
emoji_mobile_customizer/
├── App.js                    # Main app entry
├── components/
│   └── CustomizerNative.js   # Native customization controls
├── app.json                  # Expo configuration
└── package.json              # Dependencies
```

## Building for Production

```bash
# iOS
npx expo build:ios

# Android
npx expo build:android
```
