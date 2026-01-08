/**
 * Google AdMob Service
 * 
 * Simple service to manage AdMob ads (Banner, Interstitial, Rewarded)
 * 
 * SETUP INSTRUCTIONS:
 * 1. Get your AdMob App ID from https://apps.admob.com/
 * 2. Add to your .env file:
 *    VITE_ADMOB_APP_ID=ca-app-pub-xxxxxxxxxxxxxxxx~xxxxxxxxxx
 *    VITE_ADMOB_BANNER_ID=ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx
 *    VITE_ADMOB_INTERSTITIAL_ID=ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx
 *    VITE_ADMOB_REWARDED_ID=ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx
 * 3. For testing, use Google's test ad unit IDs:
 *    Banner: ca-app-pub-3940256099942544/6300978111
 *    Interstitial: ca-app-pub-3940256099942544/1033173712
 *    Rewarded: ca-app-pub-3940256099942544/5224354917
 * 
 * 4. Run: npx cap sync
 * 
 * 5. For Android: Add to AndroidManifest.xml (auto-added by plugin)
 * 6. For iOS: Add to Info.plist (auto-added by plugin)
 */

import { Capacitor } from '@capacitor/core';
import { AdMob } from '@capacitor-community/admob';

// Kids / Families configuration
// Default to "true" for this app; override by setting VITE_KIDS_APP=false if you ever need to.
const IS_KIDS_APP = (import.meta.env.VITE_KIDS_APP ?? 'true') === 'true';

// Ad Unit IDs from environment variables
// const ADMOB_APP_ID = import.meta.env.VITE_ADMOB_APP_ID || 'ca-app-pub-3940256099942544~3347511713'; // Test App ID
const BANNER_AD_ID = import.meta.env.VITE_ADMOB_BANNER_ID || 'ca-app-pub-3940256099942544/6300978111'; // Test Banner ID
const INTERSTITIAL_AD_ID = import.meta.env.VITE_ADMOB_INTERSTITIAL_ID || 'ca-app-pub-3940256099942544/1033173712'; // Test Interstitial ID
const REWARDED_AD_ID = import.meta.env.VITE_ADMOB_REWARDED_ID || 'ca-app-pub-3940256099942544/5224354917'; // Test Rewarded ID

let isInitialized = false;

/**
 * Initialize AdMob
 * Must be called before showing any ads
 * Follows latest AdMob policy with proper initialization
 */
export const initializeAdMob = async () => {
  try {
    // Only initialize on native platforms (Android/iOS)
    if (!Capacitor.isNativePlatform()) {
      console.log('[AdMob] Running on web platform, AdMob not available');
      return false;
    }

    if (isInitialized) {
      console.log('[AdMob] Already initialized');
      return true;
    }

    console.log('[AdMob] Initializing AdMob...');
    
    // Initialize AdMob.
    // IMPORTANT for Kids/Families apps:
    // - Do NOT request ATT tracking authorization for child-directed apps
    // - Tag requests as child-directed (COPPA) and under-age-of-consent (TFUA)
    // - Restrict ad content rating to "General" (G)
    await AdMob.initialize({
      testingDevices: [], // Add test device IDs here for testing
      initializeForTesting: false, // Set to false in production
      ...(IS_KIDS_APP
        ? {
            tagForChildDirectedTreatment: true,
            tagForUnderAgeOfConsent: true,
            maxAdContentRating: 'General',
          }
        : {}),
    });

    // Set application muted state (optional)
    try {
      await AdMob.setApplicationMuted({ muted: false });
    } catch (error) {
      // setApplicationMuted might not be available in all versions
      console.log('[AdMob] setApplicationMuted not available');
    }

    isInitialized = true;
    console.log('[AdMob] Initialized successfully');
    return true;
  } catch (error) {
    console.error('[AdMob] Initialization error:', error);
    return false;
  }
};

/**
 * Request tracking permission (iOS 14+)
 * This is required for personalized ads
 */
export const requestTrackingPermission = async () => {
  try {
    if (!Capacitor.isNativePlatform()) {
      return false;
    }

    // Kids/Families apps should not request AppTrackingTransparency permission.
    if (IS_KIDS_APP) {
      console.log('[AdMob] Kids app: skipping tracking authorization request');
      return false;
    }

    const { status } = await AdMob.trackingAuthorizationStatus();
    console.log('[AdMob] Tracking authorization status:', status);
    
    if (status === 'notDetermined') {
      await AdMob.requestTrackingAuthorization();
      // Plugin method resolves void; re-check status after request.
      const { status: newStatus } = await AdMob.trackingAuthorizationStatus();
      console.log('[AdMob] Tracking authorization status after request:', newStatus);
      return newStatus === 'authorized';
    }
    
    return status === 'authorized';
  } catch (error) {
    console.error('[AdMob] Tracking permission error:', error);
    return false;
  }
};

/**
 * Show Banner Ad
 * @param {string} position - 'top' or 'bottom' (default: 'bottom')
 * @param {string} adId - Optional custom ad unit ID
 */
export const showBannerAds = async (position = 'top') => {
  try {
    if (!Capacitor.isNativePlatform()) {
      console.log('[AdMob] Banner ads not available on web platform');
      return false;
    }

    // Initialize if not already done
    if (!isInitialized) {
      const initialized = await initializeAdMob();
      if (!initialized) {
        return false;
      }
    }

    // Hide existing banner if any
    await hideBannerAds();

    const adUnitId = BANNER_AD_ID;
    const adPosition = position === 'top' ? 'TOP' : 'BOTTOM';

    console.log(`[AdMob] Showing banner ad at ${adPosition}...`);

    const options = {
      adId: adUnitId,
      adSize: 'BANNER',
      position: adPosition,
      margin: 0, // Margin from edge in pixels
      isTesting: false, // Set to false in production
    };

    const result = await AdMob.showBanner(options);
    
    console.log('[AdMob] Banner ad shown successfully:', JSON.stringify(result));
    return true;
  } catch (error) {
    console.error('[AdMob] Error showing banner ad:', error);
    return false;
  }
};

/**
 * Hide Banner Ad
 */
export const hideBannerAds = async () => {
  try {
    if (!Capacitor.isNativePlatform()) {
      return false;
    }

    console.log('[AdMob] Hiding banner ad...');
    await AdMob.hideBanner();
    console.log('[AdMob] Banner ad hidden');
    return true;
  } catch (error) {
    console.error('[AdMob] Error hiding banner ad:', error);
    return false;
  }
};

/**
 * Remove Banner Ad (permanently removes from view)
 */
export const removeBannerAds = async () => {
  try {
    if (!Capacitor.isNativePlatform()) {
      return false;
    }

    console.log('[AdMob] Removing banner ad...');
    await AdMob.removeBanner();
    console.log('[AdMob] Banner ad removed');
    return true;
  } catch (error) {
    console.error('[AdMob] Error removing banner ad:', error);
    return false;
  }
};

/**
 * Show Interstitial Ad
 * @param {string} adId - Optional custom ad unit ID
 * @returns {Promise<boolean>} - Returns true if ad was shown successfully
 */
export const showInterstitialAds = async () => {
  try {
    if (!Capacitor.isNativePlatform()) {
      console.log('[AdMob] Interstitial ads not available on web platform');
      return false;
    }

    // Initialize if not already done
    if (!isInitialized) {
      const initialized = await initializeAdMob();
      if (!initialized) {
        return false;
      }
    }

    const adUnitId = INTERSTITIAL_AD_ID;

    console.log('[AdMob] Loading interstitial ad...');

    // Prepare interstitial ad
    await AdMob.prepareInterstitial({
      adId: adUnitId,
      isTesting: false, // Set to false in production
    });

    // Show interstitial ad
    await AdMob.showInterstitial();

    console.log('[AdMob] Interstitial ad shown successfully');
    return true;
  } catch (error) {
    console.error('[AdMob] Error showing interstitial ad:', error);
    return false;
  }
};

/**
 * Show Rewarded Ad
 * @param {string} adId - Optional custom ad unit ID
 * @returns {Promise<{success: boolean, reward?: object}>} - Returns success status and reward if earned
 */
export const showRewardedAds = async () => {
  try {
    if (!Capacitor.isNativePlatform()) {
      console.log('[AdMob] Rewarded ads not available on web platform');
      return { success: false };
    }

    // Initialize if not already done
    if (!isInitialized) {
      const initialized = await initializeAdMob();
      if (!initialized) {
        return { success: false };
      }
    }

    const adUnitId = REWARDED_AD_ID;

    console.log('[AdMob] Loading rewarded ad...');

    // Prepare rewarded ad
    await AdMob.prepareRewardVideoAd({
      adId: adUnitId,
      isTesting: true, // Set to false in production
    });

    // Show rewarded ad and get result
    const result = await AdMob.showRewardVideoAd();

    if (result.reward) {
      console.log('[AdMob] Rewarded ad completed, reward:', result.reward);
      return {
        success: true,
        reward: result.reward,
      };
    }

    console.log('[AdMob] Rewarded ad shown but no reward earned');
    return { success: true, reward: null };
  } catch (error) {
    console.error('[AdMob] Error showing rewarded ad:', error);
    return { success: false };
  }
};

/**
 * Check if AdMob is available (native platform only)
 */
export const isAdMobAvailable = () => {
  return Capacitor.isNativePlatform();
};


// Export default object with all methods
export default {
  initializeAdMob,
  requestTrackingPermission,
  showBannerAds,
  hideBannerAds,
  removeBannerAds,
  showInterstitialAds,
  showRewardedAds,
  isAdMobAvailable,
};

