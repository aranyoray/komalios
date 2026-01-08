/**
 * ContentFilterPlugin.ts
 * Komal - Content Filter Plugin Wrapper for React
 *
 * TypeScript wrapper for the native iOS content filtering plugin
 */

import { registerPlugin } from '@capacitor/core';

export interface ContentFilterPlugin {
  /**
   * Initialize the content filter and check onboarding status
   */
  initialize(): Promise<{
    needsOnboarding: boolean;
    childAge: number;
    biometricsEnabled: boolean;
  }>;

  /**
   * Show the parent onboarding flow
   */
  showOnboarding(): Promise<{ success: boolean }>;

  /**
   * Check if a URL should be allowed
   */
  checkURL(options: { url: string }): Promise<{
    shouldAllow: boolean;
    action: 'allow' | 'gate' | 'block';
    category: string;
    reason: string;
    confidence: number;
  }>;

  /**
   * Check multiple URLs at once
   */
  checkURLBatch(options: { urls: string[] }): Promise<{
    results: Array<{
      url: string;
      shouldAllow: boolean;
      action: string;
      category: string;
    }>;
  }>;

  /**
   * Show the parent dashboard
   */
  showParentDashboard(): Promise<{ success: boolean }>;

  /**
   * Open the protected browser
   */
  openProtectedBrowser(options?: { url?: string }): Promise<{ success: boolean }>;

  /**
   * Get filtering statistics
   */
  getStats(): Promise<{
    totalRequests: number;
    blocked: number;
    gated: number;
    allowed: number;
    blockRate: number;
    cacheSize: number;
    categoryBreakdown: Array<{
      category: string;
      displayName: string;
      count: number;
    }>;
  }>;

  /**
   * Get activity logs
   */
  getActivityLogs(options?: { limit?: number }): Promise<{
    logs: Array<{
      id: string;
      timestamp: string;
      url: string;
      category: string;
      action: string;
      wasBlocked: boolean;
      reason: string;
    }>;
  }>;

  /**
   * Get current settings
   */
  getSettings(): Promise<{
    version: string;
    child_age: number;
    use_biometrics: boolean;
    max_log_entries: number;
    log_retention_days: number;
    onboarding_completed: boolean;
    custom_rules: Array<{ category: string; action: string }>;
    logs_count: number;
    exported_at: string;
  }>;

  /**
   * Update child age
   */
  updateChildAge(options: { age: number }): Promise<{ success: boolean }>;

  /**
   * Set custom filtering rule for a category
   */
  setCustomRule(options: {
    category: string;
    action: 'allow' | 'gate' | 'block';
  }): Promise<{ success: boolean }>;

  /**
   * Export settings as JSON
   */
  exportSettings(): Promise<{ json: string }>;

  /**
   * Export logs as CSV
   */
  exportLogs(): Promise<{ csv: string }>;

  /**
   * Clear the URL cache
   */
  clearCache(): Promise<{ success: boolean }>;
}

const ContentFilter = registerPlugin<ContentFilterPlugin>('ContentFilter', {
  web: () => import('./web').then(m => new m.ContentFilterWeb()),
});

export default ContentFilter;

// Helper functions for React components
export const useContentFilter = () => {
  const checkLink = async (url: string) => {
    try {
      const result = await ContentFilter.checkURL({ url });
      return result;
    } catch (error) {
      console.error('Content filter error:', error);
      return {
        shouldAllow: true,
        action: 'allow' as const,
        category: 'unknown',
        reason: 'Filter unavailable',
        confidence: 0,
      };
    }
  };

  const openDashboard = async () => {
    try {
      await ContentFilter.showParentDashboard();
    } catch (error) {
      console.error('Failed to open dashboard:', error);
    }
  };

  const getStats = async () => {
    try {
      return await ContentFilter.getStats();
    } catch (error) {
      console.error('Failed to get stats:', error);
      return null;
    }
  };

  return {
    checkLink,
    openDashboard,
    getStats,
  };
};
