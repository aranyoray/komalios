/**
 * Device Detection Utility
 * Detects device type, orientation, and camera position for eye tracking optimization
 * Uses Capacitor Device API when available, falls back to browser detection
 */

import { Device } from '@capacitor/device';
import { Capacitor } from '@capacitor/core';

/**
 * Detect device type using Capacitor Device API (preferred) or browser fallback
 */
export const detectDeviceType = async () => {
  const width = window.innerWidth;
  const height = window.innerHeight;
  
  // Try Capacitor Device API first (more reliable on native platforms)
  if (Capacitor.isNativePlatform()) {
    try {
      const deviceInfo = await Device.getInfo();
      
      // Map Capacitor device types to our categories
      let deviceType = 'unknown';
      let isMobile = false;
      let isTablet = false;
      let isDesktop = false;
      
      // Capacitor provides: 'ios' | 'android' | 'web'
      if (deviceInfo.platform === 'ios' || deviceInfo.platform === 'android') {
        // Use model to distinguish phone vs tablet
        const model = deviceInfo.model?.toLowerCase() || '';
        const isIPad = model.includes('ipad');
        const isTabletModel = model.includes('tablet') || isIPad;
        
        if (isTabletModel) {
          deviceType = 'tablet';
          isTablet = true;
        } else {
          deviceType = 'mobile';
          isMobile = true;
        }
      } else {
        // Web platform - use screen size
        if (width > 1024) {
          deviceType = 'desktop';
          isDesktop = true;
        } else if (width >= 768) {
          deviceType = 'tablet';
          isTablet = true;
        } else {
          deviceType = 'mobile';
          isMobile = true;
        }
      }
      
      return {
        type: deviceType,
        isMobile,
        isTablet,
        isDesktop,
        platform: deviceInfo.platform,
        model: deviceInfo.model,
        manufacturer: deviceInfo.manufacturer,
        operatingSystem: deviceInfo.operatingSystem,
        osVersion: deviceInfo.osVersion,
        screenWidth: width,
        screenHeight: height,
        isNative: true,
      };
    } catch (error) {
      console.warn('[DeviceDetection] Capacitor Device API failed, using fallback:', error);
      // Fall through to browser detection
    }
  }
  
  // Browser fallback (for web or if Capacitor fails)
  const ua = navigator.userAgent || navigator.vendor || window.opera;
  
  // Check for mobile devices
  const isMobile = /android|webos|iphone|ipod|blackberry|iemobile|opera mini/i.test(ua.toLowerCase());
  
  // Check for tablet (iPad, Android tablets)
  const isTablet = /ipad|android(?!.*mobile)|tablet/i.test(ua.toLowerCase()) ||
                   (width >= 768 && width <= 1024 && height >= 768 && height <= 1024);
  
  // Check for laptop/desktop
  const isDesktop = !isMobile && !isTablet && width > 1024;
  
  // Determine device category
  let deviceType = 'unknown';
  if (isMobile) {
    deviceType = 'mobile';
  } else if (isTablet) {
    deviceType = 'tablet';
  } else if (isDesktop) {
    deviceType = 'desktop';
  }
  
  return {
    type: deviceType,
    isMobile,
    isTablet,
    isDesktop,
    userAgent: ua,
    screenWidth: width,
    screenHeight: height,
    isNative: false,
  };
};

/**
 * Detect screen orientation
 */
export const detectOrientation = () => {
  const width = window.innerWidth;
  const height = window.innerHeight;
  
  // Use screen orientation API if available
  if (screen.orientation) {
    const angle = screen.orientation.angle;
    return {
      angle,
      isPortrait: angle === 0 || angle === 180,
      isLandscape: angle === 90 || angle === 270,
      mode: angle === 0 || angle === 180 ? 'portrait' : 'landscape',
    };
  }
  
  // Fallback: use dimensions
  const isPortrait = height > width;
  return {
    angle: isPortrait ? 0 : 90,
    isPortrait,
    isLandscape: !isPortrait,
    mode: isPortrait ? 'portrait' : 'landscape',
  };
};

/**
 * Get camera position information based on device type
 * Cameras are typically positioned at the top of devices
 */
export const getCameraPosition = async () => {
  const device = await detectDeviceType();
  const orientation = detectOrientation();
  
  // Camera position relative to screen
  // All devices have cameras at the top, but viewing angles differ
  const cameraInfo = {
    position: 'top', // Always at top
    // Typical viewing angles (pitch) when looking at screen center:
    // - Mobile: User looks down ~15-25° (negative pitch)
    // - Tablet: User looks down ~10-20° (negative pitch)
    // - Laptop: User looks down ~5-15° (negative pitch)
    typicalPitchRange: {
      mobile: { min: -25, max: -15 },
      tablet: { min: -20, max: -10 },
      desktop: { min: -15, max: -5 },
    },
    // Distance from camera to screen center (affects gaze calculation)
    // Approximate values in normalized units
    typicalDistance: {
      mobile: 0.3, // Closer to screen
      tablet: 0.4,
      desktop: 0.5, // Further from screen
    },
  };
  
  // Get device-specific pitch range
  const pitchRange = cameraInfo.typicalPitchRange[device.type] || cameraInfo.typicalPitchRange.desktop;
  const typicalDistance = cameraInfo.typicalDistance[device.type] || cameraInfo.typicalDistance.desktop;
  
  return {
    ...cameraInfo,
    deviceType: device.type,
    orientation: orientation.mode,
    pitchRange,
    typicalDistance,
    // Expected pitch when user is looking at screen center
    expectedCenterPitch: (pitchRange.min + pitchRange.max) / 2,
  };
};

/**
 * Get device-specific calibration adjustments
 */
export const getDeviceCalibrationAdjustments = async () => {
  const device = await detectDeviceType();
  const camera = await getCameraPosition();
  
  // Different devices may need different calibration parameters
  const adjustments = {
    mobile: {
      // Mobile: Smaller screens, closer viewing distance
      pointSize: 30, // Smaller calibration points
      pointDuration: 3000, // Longer duration for stability
      smoothingFactor: 0.75, // More smoothing for stability
      headPoseTolerance: 25, // More tolerance for head movement
    },
    tablet: {
      // Tablet: Medium screens, medium viewing distance
      pointSize: 35,
      pointDuration: 3000,
      smoothingFactor: 0.7,
      headPoseTolerance: 20,
    },
    desktop: {
      // Desktop: Larger screens, further viewing distance
      pointSize: 40,
      pointDuration: 2500,
      smoothingFactor: 0.65, // Less smoothing (more responsive)
      headPoseTolerance: 15, // Less tolerance (more precise)
    },
  };
  
  return adjustments[device.type] || adjustments.desktop;
};

/**
 * Check if device supports eye tracking well
 */
export const isEyeTrackingSupported = async () => {
  const device = await detectDeviceType();
  
  // All modern devices should support eye tracking
  // But some may have limitations
  const hasCamera = !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia);
  const hasWebGL = !!document.createElement('canvas').getContext('webgl');
  
  return {
    supported: hasCamera && hasWebGL,
    hasCamera,
    hasWebGL,
    deviceType: device.type,
    recommendations: {
      mobile: 'Hold device at comfortable distance (30-40cm)',
      tablet: 'Place tablet on stand or hold steady',
      desktop: 'Sit at comfortable distance from screen',
    },
  };
};

export default {
  detectDeviceType,
  detectOrientation,
  getCameraPosition,
  getDeviceCalibrationAdjustments,
  isEyeTrackingSupported,
};

