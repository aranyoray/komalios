/**
 * useContentFilter.js
 * React hook for content filtering
 */

import { useState, useEffect, useCallback } from 'react';
import contentFilterService from '../services/ContentFilterService';

export const useContentFilter = () => {
  const [isAvailable, setIsAvailable] = useState(false);
  const [needsOnboarding, setNeedsOnboarding] = useState(false);
  const [stats, setStats] = useState(null);

  // Initialize on mount
  useEffect(() => {
    const init = async () => {
      const result = await contentFilterService.initialize();
      setIsAvailable(contentFilterService.isAvailable);
      setNeedsOnboarding(result.needsOnboarding);
    };
    init();
  }, []);

  /**
   * Check if a URL should be allowed
   */
  const checkURL = useCallback(async (url) => {
    return await contentFilterService.checkURL(url);
  }, []);

  /**
   * Check multiple URLs
   */
  const checkURLBatch = useCallback(async (urls) => {
    return await contentFilterService.checkURLBatch(urls);
  }, []);

  /**
   * Show onboarding survey
   */
  const showOnboarding = useCallback(async () => {
    const result = await contentFilterService.showOnboarding();
    if (result.success) {
      setNeedsOnboarding(false);
    }
    return result;
  }, []);

  /**
   * Show parent dashboard
   */
  const showDashboard = useCallback(async () => {
    return await contentFilterService.showParentDashboard();
  }, []);

  /**
   * Open protected browser
   */
  const openProtectedBrowser = useCallback(async (url) => {
    return await contentFilterService.openProtectedBrowser(url);
  }, []);

  /**
   * Refresh statistics
   */
  const refreshStats = useCallback(async () => {
    const newStats = await contentFilterService.getStats();
    setStats(newStats);
    return newStats;
  }, []);

  /**
   * Get activity logs
   */
  const getActivityLogs = useCallback(async (limit) => {
    return await contentFilterService.getActivityLogs(limit);
  }, []);

  /**
   * Export settings
   */
  const exportSettings = useCallback(async () => {
    return await contentFilterService.exportSettings();
  }, []);

  /**
   * Export logs
   */
  const exportLogs = useCallback(async () => {
    return await contentFilterService.exportLogs();
  }, []);

  return {
    isAvailable,
    needsOnboarding,
    stats,
    checkURL,
    checkURLBatch,
    showOnboarding,
    showDashboard,
    openProtectedBrowser,
    refreshStats,
    getActivityLogs,
    exportSettings,
    exportLogs,
  };
};
