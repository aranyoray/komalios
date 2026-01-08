/**
 * Supabase Database Service for Komal
 * Hybrid approach: Supabase (cloud) + IndexedDB (offline)
 */

import { supabase, TABLES, supabaseHelpers } from './supabase';
import { db as indexedDB } from './db';

class SupabaseDB {
  constructor() {
    this.isOnline = navigator.onLine;
    this.syncQueue = [];

    // Listen for online/offline events
    window.addEventListener('online', () => {
      this.isOnline = true;
      this.syncPendingData();
    });

    window.addEventListener('offline', () => {
      this.isOnline = false;
    });
  }

  /**
   * Check if Supabase is configured
   */
  isSupabaseConfigured() {
    return supabaseHelpers.isConfigured();
  }

  // ========================================================================
  // USERS
  // ========================================================================

  async createUser(userData) {
    try {
      // Always save to IndexedDB first
      const localUser = {
        id: crypto.randomUUID(),
        ...userData,
        createdAt: Date.now(),
        lastLogin: Date.now()
      };
      await indexedDB.add('users', localUser);

      // Try to sync to Supabase if configured and online
      if (this.isSupabaseConfigured() && this.isOnline) {
        const { data, error } = await supabase
          .from(TABLES.USERS)
          .insert({
            phone_number: userData.phoneNumber,
            email: userData.email,
            auth_method: userData.authMethod,
            language: userData.language,
            pin_hash: userData.pin
          })
          .select()
          .single();

        if (error) throw error;

        // Update local with Supabase ID
        localUser.supabaseId = data.id;
        await indexedDB.update('users', localUser);
      }

      return localUser;
    } catch (error) {
      console.error('[SupabaseDB] Create user failed:', error);
      throw error;
    }
  }

  async getUserByPhone(phoneNumber) {
    try {
      // Try local first
      const localUser = await indexedDB.getUserByPhone(phoneNumber);
      if (localUser) return localUser;

      // Try Supabase if configured and online
      if (this.isSupabaseConfigured() && this.isOnline) {
        const { data, error } = await supabase
          .from(TABLES.USERS)
          .select('*')
          .eq('phone_number', phoneNumber)
          .single();

        if (error && error.code !== 'PGRST116') throw error;
        if (data) {
          // Cache locally
          const localUser = this.supabaseToLocal(data, 'user');
          await indexedDB.add('users', localUser);
          return localUser;
        }
      }

      return null;
    } catch (error) {
      console.error('[SupabaseDB] Get user by phone failed:', error);
      return null;
    }
  }

  async updateUser(userId, updates) {
    try {
      // Update local
      const localUser = await indexedDB.get('users', userId);
      if (localUser) {
        const updated = { ...localUser, ...updates, updatedAt: Date.now() };
        await indexedDB.update('users', updated);

        // Sync to Supabase if configured and online
        if (this.isSupabaseConfigured() && this.isOnline && localUser.supabaseId) {
          const { error } = await supabase
            .from(TABLES.USERS)
            .update(this.localToSupabase(updates, 'user'))
            .eq('id', localUser.supabaseId);

          if (error) console.error('Supabase update failed:', error);
        }

        return updated;
      }
      throw new Error('User not found');
    } catch (error) {
      console.error('[SupabaseDB] Update user failed:', error);
      throw error;
    }
  }

  // ========================================================================
  // LEARNERS
  // ========================================================================

  async createLearner(learnerData) {
    try {
      const localLearner = {
        id: crypto.randomUUID(),
        ...learnerData,
        createdAt: Date.now(),
        updatedAt: Date.now()
      };
      await indexedDB.add('learners', localLearner);

      // Sync to Supabase
      if (this.isSupabaseConfigured() && this.isOnline) {
        const user = await indexedDB.get('users', learnerData.userId);

        const { data, error } = await supabase
          .from(TABLES.LEARNERS)
          .insert({
            user_id: user.supabaseId,
            name: learnerData.name,
            date_of_birth: learnerData.dateOfBirth,
            gender: learnerData.gender,
            focus_areas: learnerData.focusAreas,
            settings: learnerData.settings,
            permissions: learnerData.permissions,
            pin_hash: learnerData.pin
          })
          .select()
          .single();

        if (error) throw error;

        localLearner.supabaseId = data.id;
        await indexedDB.update('learners', localLearner);
      }

      return localLearner;
    } catch (error) {
      console.error('[SupabaseDB] Create learner failed:', error);
      throw error;
    }
  }

  async getLearnersByUserId(userId) {
    try {
      // Get from local
      const localLearners = await indexedDB.getLearnersByUserId(userId);

      // Try to sync from Supabase if configured and online
      if (this.isSupabaseConfigured() && this.isOnline) {
        const user = await indexedDB.get('users', userId);
        if (user && user.supabaseId) {
          const { data, error } = await supabase
            .from(TABLES.LEARNERS)
            .select('*')
            .eq('user_id', user.supabaseId);

          if (error) console.error('Supabase fetch failed:', error);

          if (data && data.length > 0) {
            // Merge with local data
            for (const supabaseLearner of data) {
              const localLearner = this.supabaseToLocal(supabaseLearner, 'learner');
              localLearner.userId = userId; // Map back to local user ID

              // Check if already exists locally
              const existing = localLearners.find(l => l.supabaseId === supabaseLearner.id);
              if (existing) {
                await indexedDB.update('learners', { ...existing, ...localLearner });
              } else {
                localLearner.id = crypto.randomUUID();
                await indexedDB.add('learners', localLearner);
              }
            }

            // Refresh from local
            return await indexedDB.getLearnersByUserId(userId);
          }
        }
      }

      return localLearners;
    } catch (error) {
      console.error('[SupabaseDB] Get learners failed:', error);
      return localLearners || [];
    }
  }

  // ========================================================================
  // SESSIONS
  // ========================================================================

  async createSession(sessionData) {
    try {
      const localSession = {
        id: crypto.randomUUID(),
        ...sessionData,
        createdAt: Date.now(),
        updatedAt: Date.now(),
        syncedToCloud: false
      };

      await indexedDB.add('sessions', localSession);

      // Queue for sync
      if (this.isSupabaseConfigured()) {
        this.queueSync('session', localSession);
      }

      return localSession;
    } catch (error) {
      console.error('[SupabaseDB] Create session failed:', error);
      throw error;
    }
  }

  async updateSession(sessionId, updates) {
    try {
      const localSession = await indexedDB.get('sessions', sessionId);
      if (!localSession) throw new Error('Session not found');

      const updated = {
        ...localSession,
        ...updates,
        updatedAt: Date.now()
      };

      await indexedDB.update('sessions', updated);

      // Queue for sync
      if (this.isSupabaseConfigured()) {
        this.queueSync('session', updated);
      }

      return updated;
    } catch (error) {
      console.error('[SupabaseDB] Update session failed:', error);
      throw error;
    }
  }

  async getSessionsByLearnerId(learnerId, limit = 100) {
    try {
      console.log('[SupabaseDB] Fetching sessions for learner:', learnerId, 'limit:', limit);
      
      // Get from local first
      const localSessions = await indexedDB.getSessionsByLearnerId(learnerId, limit);
      console.log('[SupabaseDB] Local sessions found:', localSessions?.length || 0);

      // Try to fetch from Supabase if configured and online
      if (this.isSupabaseConfigured() && this.isOnline) {
        const learner = await indexedDB.get('learners', learnerId);
        console.log('[SupabaseDB] Learner found:', learner ? 'yes' : 'no', learner?.supabaseId ? `supabaseId: ${learner.supabaseId}` : '');
        
        if (learner && learner.supabaseId) {
          // Query by Supabase learner ID
          const { data, error } = await supabase
            .from(TABLES.SESSIONS)
            .select('*')
            .eq('learner_id', learner.supabaseId)
            .order('start_time', { ascending: false })
            .limit(limit);

          if (error) {
            console.error('[SupabaseDB] Supabase fetch failed:', error);
          } else {
            console.log('[SupabaseDB] Supabase sessions found:', data?.length || 0);
          }

          if (data && data.length > 0) {
            // Cache locally
            for (const supabaseSession of data) {
              const localSession = this.supabaseToLocal(supabaseSession, 'session');
              localSession.learnerId = learnerId;

              const existing = localSessions.find(s => s.supabaseId === supabaseSession.id);
              if (!existing) {
                localSession.id = crypto.randomUUID();
                localSession.syncedToCloud = true;
                await indexedDB.add('sessions', localSession);
                console.log('[SupabaseDB] Cached session locally:', supabaseSession.id);
              }
            }

            // Return merged and sorted sessions
            const mergedSessions = await indexedDB.getSessionsByLearnerId(learnerId, limit);
            // Ensure they're sorted by start_time descending
            const sortedSessions = mergedSessions.sort((a, b) => {
              const timeA = a.start_time || a.startTime || 0;
              const timeB = b.start_time || b.startTime || 0;
              return new Date(timeB) - new Date(timeA);
            });
            console.log('[SupabaseDB] Returning', sortedSessions.length, 'sorted sessions');
            return sortedSessions.slice(0, limit);
          }
        } else {
          // Also try querying by local learner ID in case sessions were saved with local ID
          console.log('[SupabaseDB] Trying to query by local learner ID as fallback');
          const { data, error } = await supabase
            .from(TABLES.SESSIONS)
            .select('*')
            .eq('learner_id', learnerId)
            .order('start_time', { ascending: false })
            .limit(limit);

          if (!error && data && data.length > 0) {
            console.log('[SupabaseDB] Found sessions by local ID:', data.length);
            // Cache these sessions locally
            for (const supabaseSession of data) {
              const localSession = this.supabaseToLocal(supabaseSession, 'session');
              localSession.learnerId = learnerId;
              const existing = localSessions.find(s => s.supabaseId === supabaseSession.id);
              if (!existing) {
                localSession.id = crypto.randomUUID();
                localSession.syncedToCloud = true;
                await indexedDB.add('sessions', localSession);
              }
            }
            const mergedSessions = await indexedDB.getSessionsByLearnerId(learnerId, limit);
            const sortedSessions = mergedSessions.sort((a, b) => {
              const timeA = a.start_time || a.startTime || 0;
              const timeB = b.start_time || b.startTime || 0;
              return new Date(timeB) - new Date(timeA);
            });
            return sortedSessions.slice(0, limit);
          }
        }
      }

      // Return local sessions sorted by start_time descending
      const sortedLocalSessions = localSessions.sort((a, b) => {
        const timeA = a.start_time || a.startTime || 0;
        const timeB = b.start_time || b.startTime || 0;
        return new Date(timeB) - new Date(timeA);
      });
      console.log('[SupabaseDB] Returning', sortedLocalSessions.length, 'local sessions');
      return sortedLocalSessions.slice(0, limit);
    } catch (error) {
      console.error('[SupabaseDB] Get sessions failed:', error);
      return localSessions || [];
    }
  }

  // ========================================================================
  // SYNC MANAGEMENT
  // ========================================================================

  queueSync(type, data) {
    this.syncQueue.push({ type, data, timestamp: Date.now() });

    // Try to sync if online
    if (this.isOnline) {
      this.syncPendingData();
    }
  }

  async syncPendingData() {
    if (!this.isSupabaseConfigured() || !this.isOnline) return;

    console.log('[SupabaseDB] Syncing pending data...', this.syncQueue.length, 'items');

    while (this.syncQueue.length > 0) {
      const item = this.syncQueue[0];

      try {
        if (item.type === 'session') {
          await this.syncSession(item.data);
        }

        // Remove from queue on success
        this.syncQueue.shift();
      } catch (error) {
        console.error('[SupabaseDB] Sync failed:', error);
        // Keep in queue, try again later
        break;
      }
    }
  }

  async syncSession(sessionData) {
    try {
      const learner = await indexedDB.get('learners', sessionData.learnerId);
      if (!learner || !learner.supabaseId) {
        throw new Error('Learner not synced to Supabase');
      }

      const supabaseSession = this.localToSupabase(sessionData, 'session');
      supabaseSession.learner_id = learner.supabaseId;

      const { data, error } = await supabase
        .from(TABLES.SESSIONS)
        .upsert(supabaseSession, { onConflict: 'id' })
        .select()
        .single();

      if (error) throw error;

      // Mark as synced
      sessionData.syncedToCloud = true;
      sessionData.supabaseId = data.id;
      await indexedDB.update('sessions', sessionData);

      console.log('[SupabaseDB] Session synced:', sessionData.id);
    } catch (error) {
      console.error('[SupabaseDB] Session sync failed:', error);
      throw error;
    }
  }

  // ========================================================================
  // DATA TRANSFORMATION
  // ========================================================================

  supabaseToLocal(data, type) {
    // Transform Supabase column names to camelCase local format
    const transformed = {};

    for (const [key, value] of Object.entries(data)) {
      const camelKey = key.replace(/_([a-z])/g, (g) => g[1].toUpperCase());
      transformed[camelKey] = value;
    }

    transformed.supabaseId = data.id;
    delete transformed.id;

    return transformed;
  }

  localToSupabase(data, type) {
    // Transform camelCase local format to snake_case Supabase format
    const transformed = {};

    for (const [key, value] of Object.entries(data)) {
      if (key === 'supabaseId') {
        transformed.id = value;
      } else {
        const snakeKey = key.replace(/([A-Z])/g, '_$1').toLowerCase();
        transformed[snakeKey] = value;
      }
    }

    return transformed;
  }
}

export const supabaseDB = new SupabaseDB();
export default supabaseDB;
