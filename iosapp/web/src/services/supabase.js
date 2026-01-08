/**
 * Supabase Configuration for Komal
 *
 * SETUP INSTRUCTIONS:
 * 1. Go to https://supabase.com/dashboard/project/afxixmsfkiylnvatsopm/settings/api
 * 2. Copy your project URL and anon public key
 * 3. Replace the values below OR create a .env file with:
 *    VITE_SUPABASE_URL=your_project_url
 *    VITE_SUPABASE_ANON_KEY=your_anon_key
 */

import { createClient } from '@supabase/supabase-js';

// Supabase credentials
// Get these from: https://supabase.com/dashboard/project/afxixmsfkiylnvatsopm/settings/api
const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL || 'https://afxixmsfkiylnvatsopm.supabase.co';
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY || 'sb_publishable_CcrzYD934PA4caXqbk1zHw_0l21U2Kw';

// Create Supabase client
export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true,
    storage: window.localStorage,
    storageKey: 'komal-auth'
  },
  realtime: {
    params: {
      eventsPerSecond: 2
    }
  }
});

// Clean up old Supabase storage keys (migration helper)
// Supabase default storage key format: sb-{project-ref}-auth-token
const cleanupOldStorageKeys = () => {
  try {
    // Remove old default Supabase storage keys
    const keysToRemove = [];
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i);
      // Remove any Supabase default storage keys (sb-*-auth-token format)
      if (key && key.startsWith('sb-') && key.endsWith('-auth-token')) {
        keysToRemove.push(key);
      }
    }
    
    keysToRemove.forEach(key => {
      console.log('[Supabase] Removing old storage key:', key);
      localStorage.removeItem(key);
    });
    
    if (keysToRemove.length > 0) {
      console.log(`[Supabase] Cleaned up ${keysToRemove.length} old storage key(s)`);
    }
  } catch (error) {
    console.error('[Supabase] Error cleaning up old storage keys:', error);
  }
};

// Run cleanup on module load (only once)
if (typeof window !== 'undefined') {
  cleanupOldStorageKeys();
}

// Database table names
export const TABLES = {
  USERS: 'users',
  LEARNERS: 'learners',
  SESSIONS: 'sessions',
  ANALYTICS: 'analytics'
};

// Helper functions
export const supabaseHelpers = {
  /**
   * Check if Supabase is properly configured
   */
  isConfigured: () => {
    return SUPABASE_ANON_KEY !== 'YOUR_ANON_KEY_HERE';
  },

  /**
   * Get current user
   */
  getCurrentUser: async () => {
    const { data: { user } } = await supabase.auth.getUser();
    return user;
  },

  /**
   * Get current session
   */
  getCurrentSession: async () => {
    const { data: { session } } = await supabase.auth.getSession();
    return session;
  },

  /**
   * Sign out
   */
  signOut: async () => {
    const { error } = await supabase.auth.signOut();
    if (error) throw error;
  }
};

export default supabase;
