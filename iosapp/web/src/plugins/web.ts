/**
 * web.ts
 * Komal - Web implementation stub
 *
 * Stub implementation for web platform (content filtering only works on iOS)
 */

import { WebPlugin } from '@capacitor/core';
import type { ContentFilterPlugin } from './ContentFilterPlugin';

export class ContentFilterWeb extends WebPlugin implements ContentFilterPlugin {
  async initialize() {
    console.log('ContentFilter: Web platform not supported');
    return {
      needsOnboarding: false,
      childAge: 13,
      biometricsEnabled: false,
    };
  }

  async showOnboarding() {
    console.log('ContentFilter: Web platform not supported');
    return { success: false };
  }

  async checkURL(_options: { url: string }) {
    console.log('ContentFilter: Web platform not supported - allowing all URLs');
    return {
      shouldAllow: true,
      action: 'allow' as const,
      category: 'unknown',
      reason: 'Web platform - no filtering',
      confidence: 1.0,
    };
  }

  async checkURLBatch(_options: { urls: string[] }) {
    return { results: [] };
  }

  async showParentDashboard() {
    console.log('ContentFilter: Web platform not supported');
    return { success: false };
  }

  async openProtectedBrowser(_options?: { url?: string }) {
    console.log('ContentFilter: Web platform not supported');
    return { success: false };
  }

  async getStats() {
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

  async getActivityLogs(_options?: { limit?: number }) {
    return { logs: [] };
  }

  async getSettings() {
    return {
      version: '1.0.0',
      child_age: 13,
      use_biometrics: false,
      max_log_entries: 100,
      log_retention_days: 30,
      onboarding_completed: false,
      custom_rules: [],
      logs_count: 0,
      exported_at: new Date().toISOString(),
    };
  }

  async updateChildAge(_options: { age: number }) {
    return { success: false };
  }

  async setCustomRule(_options: { category: string; action: string }) {
    return { success: false };
  }

  async exportSettings() {
    return { json: '{}' };
  }

  async exportLogs() {
    return { csv: '' };
  }

  async clearCache() {
    return { success: false };
  }
}
