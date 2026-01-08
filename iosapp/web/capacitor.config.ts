import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.komalkids.app',
  appName: 'Komal',
  webDir: 'dist',
  server: {
    androidScheme: 'https',
    // Note: 'url' is only needed for development when pointing to a dev server
    // For production builds, the app loads from 'webDir' (dist folder)
    // Deep links are configured separately in AndroidManifest.xml
    // url: 'http://localhost:5173', // Uncomment for local dev server
  },
  android: {
    // Edge-to-edge configuration for Android 15+ (SDK 35)
    // 'auto' automatically adjusts margins based on device and Android version
    // This handles WebView insets automatically, working together with EdgeToEdge.enable()
    // EdgeToEdge.enable() handles window-level edge-to-edge (Google Play Console requirement)
    // adjustMarginsForEdgeToEdge handles WebView-level insets (Capacitor framework)
    // They work at different levels and complement each other
    adjustMarginsForEdgeToEdge: 'auto', // Options: 'auto' | 'force' | 'disable'
    // If you see conflicts, try 'disable' and rely on CSS env(safe-area-inset-top) only
  },
  plugins: {
    SplashScreen: {
      launchShowDuration: 0, // 0 milliseconds - hide immediately
      launchAutoHide: true, // Auto hide on launch
      backgroundColor: '#FFFFFF', // White background
      androidSplashResourceName: 'splash_white', // Use white drawable
      androidScaleType: 'CENTER_CROP', // Scale type
      showSpinner: false, // Don't show spinner
      splashFullScreen: true, // Full screen
      splashImmersive: true, // Immersive mode
    },
  },
};

export default config;
