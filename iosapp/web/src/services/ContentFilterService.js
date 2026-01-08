/**
 * ContentFilterService.js
 * React service wrapper for iOS content filtering
 */

import { Capacitor } from '@capacitor/core';

// Import the plugin only on native platforms
let ContentFilterPlugin = null;
if (Capacitor.isNativePlatform()) {
  try {
    ContentFilterPlugin = require('../plugins/ContentFilterPlugin').default;
  } catch (error) {
    console.warn('ContentFilter plugin not available:', error);
  }
}

class ContentFilterService {
  constructor() {
    this.isAvailable = Capacitor.getPlatform() === 'ios' && ContentFilterPlugin !== null;
    this.initialized = false;
    this.needsOnboarding = false;
  }

  /**
   * Initialize the content filter
   */
  async initialize() {
    if (!this.isAvailable) {
      console.log('ContentFilter: Not available on this platform');
      return { needsOnboarding: false, childAge: 13, biometricsEnabled: false };
    }

    try {
      const result = await ContentFilterPlugin.initialize();
      this.initialized = true;
      this.needsOnboarding = result.needsOnboarding;
      return result;
    } catch (error) {
      console.error('ContentFilter initialization error:', error);
      return { needsOnboarding: false, childAge: 13, biometricsEnabled: false };
    }
  }

  /**
   * Check if a URL should be allowed
   */
  async checkURL(url) {
    if (!this.isAvailable || !this.initialized) {
      // Allow all URLs if filter not available
      return {
        shouldAllow: true,
        action: 'allow',
        category: 'unknown',
        reason: 'Filter not available',
        confidence: 1.0,
      };
    }

    try {
      const result = await ContentFilterPlugin.checkURL({ url });
      return result;
    } catch (error) {
      console.error('ContentFilter checkURL error:', error);
      // Fail open - allow URL on error
      return {
        shouldAllow: true,
        action: 'allow',
        category: 'unknown',
        reason: 'Error checking URL',
        confidence: 0,
      };
    }
  }

  /**
   * Check multiple URLs at once
   */
  async checkURLBatch(urls) {
    if (!this.isAvailable || !this.initialized) {
      return { results: urls.map(url => ({ url, shouldAllow: true, action: 'allow', category: 'unknown' })) };
    }

    try {
      return await ContentFilterPlugin.checkURLBatch({ urls });
    } catch (error) {
      console.error('ContentFilter checkURLBatch error:', error);
      return { results: [] };
    }
  }

  /**
   * Show parent onboarding survey
   */
  async showOnboarding() {
    if (!this.isAvailable) {
      console.log('ContentFilter: Onboarding not available on this platform');
      return { success: false };
    }

    try {
      const result = await ContentFilterPlugin.showOnboarding();
      if (result.success) {
        this.needsOnboarding = false;
      }
      return result;
    } catch (error) {
      console.error('ContentFilter showOnboarding error:', error);
      return { success: false };
    }
  }

  /**
   * Show parent dashboard
   */
  async showParentDashboard() {
    if (!this.isAvailable) {
      console.log('ContentFilter: Dashboard not available on this platform');
      return { success: false };
    }

    try {
      return await ContentFilterPlugin.showParentDashboard();
    } catch (error) {
      console.error('ContentFilter showParentDashboard error:', error);
      return { success: false };
    }
  }

  /**
   * Open protected browser
   */
  async openProtectedBrowser(url = 'https://www.google.com') {
    if (!this.isAvailable) {
      // Fallback to regular browser
      window.open(url, '_blank');
      return { success: false };
    }

    try {
      return await ContentFilterPlugin.openProtectedBrowser({ url });
    } catch (error) {
      console.error('ContentFilter openProtectedBrowser error:', error);
      window.open(url, '_blank');
      return { success: false };
    }
  }

  /**
   * Get filtering statistics
   */
  async getStats() {
    if (!this.isAvailable || !this.initialized) {
      return {
        totalRequests: 0,
        blocked: 0,
        gated: 0,
        allowed: 0,
        blockRate: 0,
        cacheSize: 0,
        categoryBreakdown: [],
      };
    }

    try {
      return await ContentFilterPlugin.getStats();
    } catch (error) {
      console.error('ContentFilter getStats error:', error);
      return {
        totalRequests: 0,
        blocked: 0,
        gated: 0,
        allowed: 0,
        blockRate: 0,
        cacheSize: 0,
        categoryBreakdown: [],
      };
    }
  }

  /**
   * Get activity logs
   */
  async getActivityLogs(limit = 50) {
    if (!this.isAvailable || !this.initialized) {
      return { logs: [] };
    }

    try {
      return await ContentFilterPlugin.getActivityLogs({ limit });
    } catch (error) {
      console.error('ContentFilter getActivityLogs error:', error);
      return { logs: [] };
    }
  }

  /**
   * Export settings as JSON
   */
  async exportSettings() {
    if (!this.isAvailable) return { json: '{}' };

    try {
      return await ContentFilterPlugin.exportSettings();
    } catch (error) {
      console.error('ContentFilter exportSettings error:', error);
      return { json: '{}' };
    }
  }

  /**
   * Export logs as CSV
   */
  async exportLogs() {
    if (!this.isAvailable) return { csv: '' };

    try {
      return await ContentFilterPlugin.exportLogs();
    } catch (error) {
      console.error('ContentFilter exportLogs error:', error);
      return { csv: '' };
    }
  }
}

// Singleton instance
const contentFilterService = new ContentFilterService();

export default contentFilterService;
