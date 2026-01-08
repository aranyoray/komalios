/**
 * Authentication Context for Komal
 * Uses Supabase for authentication and profiles table
 * 
 * DEV MODE: Set DEV_BYPASS_AUTH=true to skip authentication for UI testing
 */

import React, { createContext, useContext, useState, useEffect } from 'react';
import { Capacitor } from '@capacitor/core';
import { supabase } from '../services/supabase';

// ======================== DEV MODE CONFIG ========================
// Enable this to bypass Supabase auth and use mock data for UI testing
const DEV_BYPASS_AUTH = import.meta.env.DEV && true; // Only works in development

// Mock user for dev mode
const DEV_MOCK_USER = {
  id: 'dev-user-123',
  email: 'dev@komal.test',
  phone: null,
  created_at: new Date().toISOString(),
  app_metadata: { provider: 'email' },
  user_metadata: { name: 'Dev User' }
};

// Mock learner profile for dev mode
const DEV_MOCK_LEARNER = {
  id: 'dev-learner-456',
  user_id: 'dev-user-123',
  name: 'Test Child',
  age: 8,
  gender: 'other',
  avatar_url: null,
  focus_areas: ['Social Skills', 'Emotional Regulation'],
  sensitivity_settings: { sound: 'medium', visual: 'medium' },
  created_at: new Date().toISOString(),
  updated_at: new Date().toISOString()
};
// ==================================================================

const AuthContext = createContext(null);

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
};

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [currentProfile, setCurrentProfile] = useState(null);
  const [profileType, setProfileType] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isAuthenticated, setIsAuthenticated] = useState(false);

  // Helper function to ensure user record exists in users table
  // Falls back to direct insert if RPC function doesn't exist
  const ensureUserRecordExists = async (authUser) => {
    if (!authUser?.id) return;

    try {
      // First, try to call the RPC function if it exists
      const { error: rpcError } = await supabase.rpc('ensure_user_exists');

      // If function doesn't exist (PGRST202), fall back to direct insert/update
      if (rpcError && rpcError.code === 'PGRST202') {
        // Check if user record already exists
        const { data: existingUser, error: selectError } = await supabase
          .from('users')
          .select('id')
          .eq('auth_id', authUser.id)
          .single();

        if (selectError && selectError.code !== 'PGRST116') { // PGRST116 = no rows
          console.error('[Auth] Failed to check user record:', selectError);
          return;
        }

        // If user doesn't exist, create it
        if (!existingUser) {
          // Determine auth method from user metadata
          const authMethod = authUser.phone
            ? 'phone'
            : authUser.app_metadata?.provider === 'apple'
              ? 'apple'
              : authUser.app_metadata?.provider === 'google'
                ? 'google'
                : 'email';

          const { error: insertError } = await supabase
            .from('users')
            .upsert({
              auth_id: authUser.id,
              email: authUser.email || '',
              auth_method: authMethod,
              last_login: new Date().toISOString()
            }, {
              onConflict: 'auth_id'
            });

          if (insertError) {
            console.error('[Auth] Failed to create user record:', insertError);
          } else {
            console.log('[Auth] User record created/updated successfully');
          }
        } else {
          // Update last_login if user exists
          const { error: updateError } = await supabase
            .from('users')
            .update({ last_login: new Date().toISOString() })
            .eq('id', existingUser.id);

          if (updateError) {
            console.error('[Auth] Failed to update last_login:', updateError);
          }
        }
      } else if (rpcError) {
        console.error('[Auth] Failed to ensure user exists:', rpcError);
      }
    } catch (err) {
      console.error('[Auth] Error ensuring user record exists:', err);
      // Don't throw - auth succeeded, DB record can be created later
    }
  };

  useEffect(() => {
    // Check for existing session
    checkSession();

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      // Set loading to false immediately to avoid blocking UI
      setIsLoading(false);

      if (session?.user) {
        setUser(session.user);
        setIsAuthenticated(true);

        // Ensure user record exists in users table after successful auth
        // Run in background to avoid blocking
        if (event === 'SIGNED_IN' || event === 'TOKEN_REFRESHED') {
          ensureUserRecordExists(session.user).catch(err => {
            console.error('[Auth] Background user record check failed:', err);
          });
        }
      } else {
        setUser(null);
        setIsAuthenticated(false);
        setCurrentProfile(null);
        setProfileType(null);
      }
    });

    return () => subscription.unsubscribe();
  }, []);

  const checkSession = async () => {
    setIsLoading(true);
    try {
      const { data: { session } } = await supabase.auth.getSession();

      if (session?.user) {
        setUser(session.user);
        setIsAuthenticated(true);

        // Ensure user record exists in users table (run in background to avoid blocking)
        ensureUserRecordExists(session.user).catch(err => {
          console.error('[Auth] Background user record check failed:', err);
        });

        // Check for last selected profile
        const lastProfile = localStorage.getItem('komal_last_profile');
        const lastProfileType = localStorage.getItem('komal_last_profile_type');

        if (lastProfile && lastProfileType === 'learner') {
          // Query 'learners' table, not 'profiles' table
          const { data: profileData } = await supabase
            .from('learners')
            .select('*')
            .eq('id', lastProfile)
            .single();

          if (profileData) {
            setCurrentProfile(profileData);
            setProfileType('learner');
          }
        }
      }
    } catch (error) {
      console.error('[Auth] Session check failed:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const login = async (email, password) => {
    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password
      });

      if (error) throw error;

      setUser(data.user);
      setIsAuthenticated(true);

      // Ensure user record exists in users table (run in background to avoid blocking)
      if (data.user) {
        ensureUserRecordExists(data.user).catch(err => {
          console.error('[Auth] Background user record check failed:', err);
        });
      }

      return data.user;
    } catch (error) {
      console.error('[Auth] Login failed:', error);
      throw error;
    }
  };

  const signup = async (userData) => {
    try {
      const { email, password, authMethod = 'email', language = 'en', ...profileData } = userData;

      // Determine redirect URL for email confirmation
      // Use deep link for native apps, web URL for web
      let redirectUrl;
      try {
        const isNative = Capacitor?.isNativePlatform() || false;
        if (isNative) {
          // Use app ID based deep link (more standard) or custom scheme
          // Both are configured in AndroidManifest.xml
          redirectUrl = 'com.komalkids.app://auth/confirm'; // App ID based (preferred)
          // Alternative: 'komal://auth/confirm' (custom scheme, also works)
        } else {
          redirectUrl = `${window.location.origin}/auth/confirm`; // Web URL
        }
      } catch (error) {
        // Fallback to web URL if Capacitor is not available
        redirectUrl = `${window.location.origin}/auth/confirm`;
      }

      // Create auth user
      const { data, error } = await supabase.auth.signUp({
        email,
        password,
        options: {
          emailRedirectTo: redirectUrl,
          data: {
            auth_method: authMethod,
            language: language,
            ...profileData
          }
        }
      });

      if (error) throw error;

      // Create user record in users table after successful signup
      if (data.user) {
        try {
          const { error: rpcError } = await supabase.rpc('handle_new_user');

          // If function doesn't exist, fall back to direct insert
          if (rpcError && rpcError.code === 'PGRST202') {
            const userAuthMethod = data.user.phone
              ? 'phone'
              : data.user.app_metadata?.provider === 'apple'
                ? 'apple'
                : data.user.app_metadata?.provider === 'google'
                  ? 'google'
                  : authMethod || 'email';

            const { error: insertError } = await supabase
              .from('users')
              .upsert({
                auth_id: data.user.id,
                email: data.user.email || '',
                auth_method: userAuthMethod,
                language: language
              }, {
                onConflict: 'auth_id'
              });

            if (insertError) {
              console.error('[Auth] Failed to create user record:', insertError);
            } else {
              console.log('[Auth] User record created successfully');
            }
          } else if (rpcError) {
            console.error('[Auth] Failed to create user record:', rpcError);
          }
        } catch (err) {
          console.error('[Auth] Error calling handle_new_user:', err);
          // Don't throw - auth user is created, DB record can be created later
        }
      }

      // Return signup result with session info
      // If email confirmation is required, session will be null
      return {
        user: data.user,
        session: data.session,
        needsEmailConfirmation: !data.session && data.user && !data.user.email_confirmed_at
      };
    } catch (error) {
      console.error('[Auth] Signup failed:', error);
      throw error;
    }
  };

  const logout = async () => {
    try {
      // Clear dev mode flag if set
      localStorage.removeItem('komal_dev_mode');

      await supabase.auth.signOut();
      clearSession();
      setUser(null);
      setCurrentProfile(null);
      setProfileType(null);
      setIsAuthenticated(false);
    } catch (error) {
      console.error('[Auth] Logout failed:', error);
    }
  };

  const clearSession = () => {
    localStorage.removeItem('komal_last_profile');
    localStorage.removeItem('komal_last_profile_type');
    localStorage.removeItem('komal_dev_mode');
  };

  const selectProfile = async (profileId, type, pin = null, learnerDataOverride = null) => {
    try {
      if (type === 'learner') {
        let learnerData = learnerDataOverride;

        // If learnerData is provided, use it directly (e.g., after creating a new profile)
        // Otherwise, query from database
        if (!learnerData) {
          // Query 'learners' table, not 'profiles' table
          // 'profiles' is for parent/user info, 'learners' is for child profiles
          const { data, error } = await supabase
            .from('learners')
            .select('*')
            .eq('id', profileId)
            .single();

          if (error) throw error;
          if (!data) throw new Error('Learner not found');

          learnerData = data;
        }

        // Check PIN if set (pin_hash is stored in learners table)
        if (learnerData.pin_hash && learnerData.pin_hash !== pin) {
          throw new Error('Incorrect PIN');
        }

        setCurrentProfile(learnerData);
        setProfileType('learner');

        localStorage.setItem('komal_last_profile', profileId);
        localStorage.setItem('komal_last_profile_type', 'learner');

        return learnerData;
      } else if (type === 'parent') {
        // Parent mode
        setCurrentProfile(user);
        setProfileType('parent');

        localStorage.setItem('komal_last_profile', user.id);
        localStorage.setItem('komal_last_profile_type', 'parent');

        return user;
      }
    } catch (error) {
      console.error('[Auth] Profile selection failed:', error);
      throw error;
    }
  };

  const switchProfile = () => {
    setCurrentProfile(null);
    setProfileType(null);
    localStorage.removeItem('komal_last_profile');
    localStorage.removeItem('komal_last_profile_type');
  };

  // Dev mode login - bypasses Supabase completely
  const devLogin = async () => {
    if (!DEV_BYPASS_AUTH) {
      throw new Error('Dev login only available in development mode');
    }

    console.log('[Auth] 🔧 DEV MODE: Logging in with mock user');
    setUser(DEV_MOCK_USER);
    setIsAuthenticated(true);
    setCurrentProfile(DEV_MOCK_LEARNER);
    setProfileType('learner');
    setIsLoading(false);

    // Save to localStorage so it persists
    localStorage.setItem('komal_dev_mode', 'true');
    localStorage.setItem('komal_last_profile', DEV_MOCK_LEARNER.id);
    localStorage.setItem('komal_last_profile_type', 'learner');

    return DEV_MOCK_USER;
  };

  // Check if we're in dev mode on mount
  useEffect(() => {
    if (DEV_BYPASS_AUTH && localStorage.getItem('komal_dev_mode') === 'true') {
      console.log('[Auth] 🔧 DEV MODE: Restoring mock session');
      setUser(DEV_MOCK_USER);
      setIsAuthenticated(true);
      setCurrentProfile(DEV_MOCK_LEARNER);
      setProfileType('learner');
      setIsLoading(false);
    }
  }, []);

  const value = {
    user,
    currentProfile,
    profileType,
    isLoading,
    isAuthenticated,
    login,
    signup,
    logout,
    selectProfile,
    switchProfile,
    checkSession,
    // Dev mode exports
    devLogin,
    isDevMode: DEV_BYPASS_AUTH
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};
