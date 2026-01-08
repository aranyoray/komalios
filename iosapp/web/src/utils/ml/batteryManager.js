/**
 * Battery-aware ML inference manager for iPhone optimization
 * Adjusts inference frequency based on battery level and charging status
 */

class BatteryManager {
  constructor() {
    this.battery = null;
    this.isCharging = true;
    this.level = 1.0;
    this.initialized = false;
  }

  async init() {
    if (this.initialized) return;

    try {
      // Battery API may not be available on all devices (especially iOS < 16)
      if ('getBattery' in navigator) {
        this.battery = await navigator.getBattery();
        this.isCharging = this.battery.charging;
        this.level = this.battery.level;

        this.battery.addEventListener('chargingchange', () => {
          this.isCharging = this.battery.charging;
        });

        this.battery.addEventListener('levelchange', () => {
          this.level = this.battery.level;
        });

        this.initialized = true;
      }
    } catch (error) {
      console.warn('Battery API not available:', error);
    }
  }

  /**
   * Get recommended inference throttle in ms based on battery status
   * - Charging or high battery: 100ms (10 FPS)
   * - Medium battery: 200ms (5 FPS)
   * - Low battery: 500ms (2 FPS)
   */
  getRecommendedThrottle() {
    if (this.isCharging) return 100;

    if (this.level > 0.5) return 100;
    if (this.level > 0.2) return 200;
    return 500;
  }

  /**
   * Check if heavy ML operations should be allowed
   * Returns false if battery is critically low and not charging
   */
  canRunHeavyML() {
    if (this.isCharging) return true;
    return this.level > 0.15;
  }

  /**
   * Get battery-aware model precision
   * - High battery: 'fp32' (full precision)
   * - Medium: 'fp16' (half precision, 2x faster)
   * - Low: 'int8' (quantized, 4x faster but lower accuracy)
   */
  getRecommendedPrecision() {
    if (this.isCharging || this.level > 0.5) return 'fp32';
    if (this.level > 0.2) return 'fp16';
    return 'int8';
  }

  getBatteryInfo() {
    return {
      isCharging: this.isCharging,
      level: this.level,
      initialized: this.initialized
    };
  }
}

export const batteryManager = new BatteryManager();
