/**
 * Authentication Context for Komal with Supabase
 * Manages user authentication state and profile selection using Supabase Auth
 */

import React, { createContext, useContext, useState, useEffect } from 'react';
import { supabase, supabaseHelpers } from '../services/supabase';
import { supabaseDB } from '../services/supabaseDB';
import { db } from '../services/db';

const AuthContext = createContext(null);

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
};

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null); // Komal user (from users table)
  const [supabaseUser, setSupabaseUser] = useState(null); // Supabase auth user
  const [currentProfile, setCurrentProfile] = useState(null); // learner or parent
  const [profileType, setProfileType] = useState(null); // 'learner' | 'parent'
  const [isLoading, setIsLoading] = useState(true);
  const [isAuthenticated, setIsAuthenticated] = useState(false);

  useEffect(() => {
    // Check for existing Supabase session
    checkSupabaseSession();

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      async (event, session) => {
        console.log('[Auth] Supabase auth event:', event);

        if (event === 'SIGNED_IN' && session) {
          await handleSupabaseSignIn(session.user);
        } else if (event === 'SIGNED_OUT') {
          handleSignOut();
        }
      }
    );

    return () => {
      subscription.unsubscribe();
    };
  }, []);

  const checkSupabaseSession = async () => {
    setIsLoading(true);
    try {
      if (!supabaseDB.isSupabaseConfigured()) {
        console.warn('[Auth] Supabase not configured, using offline mode');
        await checkLocalSession();
        return;
      }

      const session = await supabaseHelpers.getCurrentSession();

      if (session) {
        await handleSupabaseSignIn(session.user);
      } else {
        // Fallback to local session
        await checkLocalSession();
      }
    } catch (error) {
      console.error('[Auth] Session check failed:', error);
      await checkLocalSession();
    } finally {
      setIsLoading(false);
    }
  };

  const checkLocalSession = async () => {
    try {
      const lastUser = localStorage.getItem('komal_last_user');
      const lastLogin = localStorage.getItem('komal_last_login');

      if (lastUser && lastLogin) {
        const loginTime = parseInt(lastLogin);
        const now = Date.now();
        const twentyMinutes = 20 * 60 * 1000;

        if (now - loginTime < twentyMinutes) {
          const userData = await db.get('users', lastUser);
          if (userData) {
            setUser(userData);
            setIsAuthenticated(true);
          }
        }
      }
    } catch (error) {
      console.error('[Auth] Local session check failed:', error);
    }
  };

  const handleSupabaseSignIn = async (supabaseUser) => {
    try {
      setSupabaseUser(supabaseUser);

      // Get or create Komal user record
      let komalUser = await supabaseDB.getUserByPhone(supabaseUser.phone);

      if (!komalUser && supabaseUser.email) {
        // Try by email
        const users = await db.getAll('users');
        komalUser = users.find(u => u.email === supabaseUser.email);
      }

      if (!komalUser) {
        // Create new Komal user
        komalUser = await supabaseDB.createUser({
          phoneNumber: supabaseUser.phone,
          email: supabaseUser.email,
          authMethod: supabaseUser.phone ? 'phone' : 'email',
          language: 'en'
        });
      }

      setUser(komalUser);
      setIsAuthenticated(true);

      localStorage.setItem('komal_last_user', komalUser.id);
      localStorage.setItem('komal_last_login', Date.now().toString());

      // Update last login
      await supabaseDB.updateUser(komalUser.id, { lastLogin: Date.now() });
    } catch (error) {
      console.error('[Auth] Supabase sign-in handler failed:', error);
    }
  };

  const handleSignOut = () => {
    setUser(null);
    setSupabaseUser(null);
    setCurrentProfile(null);
    setProfileType(null);
    setIsAuthenticated(false);
    clearSession();
  };

  /**
   * Sign in with phone (OTP)
   */
  const signInWithPhone = async (phoneNumber) => {
    try {
      if (!supabaseDB.isSupabaseConfigured()) {
        throw new Error('Supabase not configured. Please add API keys.');
      }

      const { data, error } = await supabase.auth.signInWithOtp({
        phone: phoneNumber
      });

      if (error) throw error;

      return { success: true, data };
    } catch (error) {
      console.error('[Auth] Phone sign-in failed:', error);
      throw error;
    }
  };

  /**
   * Verify phone OTP
   */
  const verifyPhoneOTP = async (phoneNumber, token) => {
    try {
      const { data, error } = await supabase.auth.verifyOtp({
        phone: phoneNumber,
        token,
        type: 'sms'
      });

      if (error) throw error;

      // User will be created via onAuthStateChange
      return { success: true, data };
    } catch (error) {
      console.error('[Auth] OTP verification failed:', error);
      throw error;
    }
  };

  /**
   * Sign in with email and password
   */
  const signInWithEmail = async (email, password) => {
    try {
      if (!supabaseDB.isSupabaseConfigured()) {
        throw new Error('Supabase not configured');
      }

      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password
      });

      if (error) throw error;

      return { success: true, data };
    } catch (error) {
      console.error('[Auth] Email sign-in failed:', error);
      throw error;
    }
  };

  /**
   * Sign up with email and password
   */
  const signUpWithEmail = async (email, password, language = 'en') => {
    try {
      if (!supabaseDB.isSupabaseConfigured()) {
        throw new Error('Supabase not configured');
      }

      const { data, error } = await supabase.auth.signUp({
        email,
        password,
        options: {
          data: {
            language
          }
        }
      });

      if (error) throw error;

      return { success: true, data };
    } catch (error) {
      console.error('[Auth] Email sign-up failed:', error);
      throw error;
    }
  };

  /**
   * Sign in with Apple
   */
  const signInWithApple = async () => {
    try {
      if (!supabaseDB.isSupabaseConfigured()) {
        throw new Error('Supabase not configured');
      }

      const { data, error } = await supabase.auth.signInWithOAuth({
        provider: 'apple',
        options: {
          redirectTo: window.location.origin
        }
      });

      if (error) throw error;

      return { success: true, data };
    } catch (error) {
      console.error('[Auth] Apple sign-in failed:', error);
      throw error;
    }
  };

  /**
   * Legacy local login (fallback when Supabase not configured)
   */
  const loginLocal = async (userId) => {
    try {
      const userData = await db.get('users', userId);
      if (!userData) {
        throw new Error('User not found');
      }

      setUser(userData);
      setIsAuthenticated(true);

      localStorage.setItem('komal_last_user', userId);
      localStorage.setItem('komal_last_login', Date.now().toString());

      await db.update('users', {
        ...userData,
        lastLogin: Date.now()
      });

      return userData;
    } catch (error) {
      console.error('[Auth] Local login failed:', error);
      throw error;
    }
  };

  /**
   * Logout
   */
  const logout = async () => {
    try {
      if (supabaseDB.isSupabaseConfigured()) {
        await supabaseHelpers.signOut();
      }
      handleSignOut();
    } catch (error) {
      console.error('[Auth] Logout failed:', error);
      handleSignOut(); // Force logout anyway
    }
  };

  const clearSession = () => {
    localStorage.removeItem('komal_last_user');
    localStorage.removeItem('komal_last_login');
    localStorage.removeItem('komal_last_profile');
    localStorage.removeItem('komal_last_profile_type');
  };

  /**
   * Select profile (learner or parent)
   */
  const selectProfile = async (profileId, type, pin = null) => {
    try {
      if (type === 'learner') {
        const learnerData = await db.get('learners', profileId);
        if (!learnerData) {
          throw new Error('Learner not found');
        }

        if (learnerData.pin && learnerData.pin !== pin) {
          throw new Error('Incorrect PIN');
        }

        setCurrentProfile(learnerData);
        setProfileType('learner');

        localStorage.setItem('komal_last_profile', profileId);
        localStorage.setItem('komal_last_profile_type', 'learner');

        return learnerData;
      } else if (type === 'parent') {
        if (user.pin && user.pin !== pin) {
          throw new Error('Incorrect PIN');
        }

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

  /**
   * Switch profile
   */
  const switchProfile = () => {
    setCurrentProfile(null);
    setProfileType(null);
    localStorage.removeItem('komal_last_profile');
    localStorage.removeItem('komal_last_profile_type');
  };

  const value = {
    user,
    supabaseUser,
    currentProfile,
    profileType,
    isLoading,
    isAuthenticated,
    // Supabase methods
    signInWithPhone,
    verifyPhoneOTP,
    signInWithEmail,
    signUpWithEmail,
    signInWithApple,
    // Legacy methods
    loginLocal,
    logout,
    selectProfile,
    switchProfile,
    // Helpers
    isSupabaseConfigured: supabaseDB.isSupabaseConfigured()
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};
