/**
 * Parent PIN Utility
 * Manages parent PIN at user level (not per learner)
 * Used for: Parent Dashboard, Profile page, Switching learners
 */

import { supabase } from '../services/supabase';

const PARENT_PIN_STORAGE_KEY = 'komal_parent_pin';

/**
 * Get parent PIN for current user
 * @param {Object} user - Supabase auth user
 * @returns {Promise<string>} PIN string (default: '1234')
 */
export const getParentPin = async (user) => {
  if (!user?.id) {
    // Fallback to localStorage
    return localStorage.getItem(PARENT_PIN_STORAGE_KEY) || '1234';
  }

  try {
    // Get user record
    const { data: userRecord, error } = await supabase
      .from('users')
      .select('id, pin_hash')
      .eq('auth_id', user.id)
      .single();

    if (error || !userRecord) {
      // Fallback to localStorage
      return localStorage.getItem(PARENT_PIN_STORAGE_KEY) || '1234';
    }

    // Check if PIN is stored in pin_hash (for backward compatibility)
    if (userRecord.pin_hash) {
      return userRecord.pin_hash;
    }

    // Check profiles table for PIN in dashboard_settings
    const { data: profile } = await supabase
      .from('profiles')
      .select('dashboard_settings')
      .eq('user_id', userRecord.id)
      .single();

    if (profile?.dashboard_settings?.parentPin) {
      return profile.dashboard_settings.parentPin;
    }

    // Fallback to localStorage
    return localStorage.getItem(PARENT_PIN_STORAGE_KEY) || '1234';
  } catch (error) {
    console.error('[ParentPIN] Failed to get PIN:', error);
    return localStorage.getItem(PARENT_PIN_STORAGE_KEY) || '1234';
  }
};

/**
 * Save parent PIN for current user
 * @param {Object} user - Supabase auth user
 * @param {string} pin - 4-digit PIN
 * @returns {Promise<boolean>} Success status
 */
export const saveParentPin = async (user, pin) => {
  if (!user?.id) {
    // Fallback to localStorage
    localStorage.setItem(PARENT_PIN_STORAGE_KEY, pin);
    return true;
  }

  try {
    // Get user record
    const { data: userRecord, error: userError } = await supabase
      .from('users')
      .select('id')
      .eq('auth_id', user.id)
      .single();

    if (userError || !userRecord) {
      throw new Error('Failed to find user record');
    }

    // Save to localStorage as backup
    localStorage.setItem(PARENT_PIN_STORAGE_KEY, pin);

    // Try to save to profiles table dashboard_settings
    const { data: existingProfile } = await supabase
      .from('profiles')
      .select('dashboard_settings')
      .eq('user_id', userRecord.id)
      .single();

    const dashboardSettings = existingProfile?.dashboard_settings || {};
    dashboardSettings.parentPin = pin;

    const { error: profileError } = await supabase
      .from('profiles')
      .upsert({
        user_id: userRecord.id,
        id: userRecord.id,
        dashboard_settings: dashboardSettings,
        updated_at: new Date().toISOString(),
      }, {
        onConflict: 'user_id',
      });

    if (profileError) {
      console.warn('[ParentPIN] Failed to save to profiles table:', profileError);
      // Still return true since localStorage was saved
    }

    // Also save to users.pin_hash for backward compatibility
    const { error: userUpdateError } = await supabase
      .from('users')
      .update({
        pin_hash: pin,
        updated_at: new Date().toISOString(),
      })
      .eq('id', userRecord.id);

    if (userUpdateError) {
      console.warn('[ParentPIN] Failed to save to users table:', userUpdateError);
    }

    return true;
  } catch (error) {
    console.error('[ParentPIN] Failed to save PIN:', error);
    // Still save to localStorage as fallback
    localStorage.setItem(PARENT_PIN_STORAGE_KEY, pin);
    return false;
  }
};

/**
 * Verify parent PIN
 * @param {Object} user - Supabase auth user
 * @param {string} enteredPin - PIN entered by user
 * @returns {Promise<boolean>} Whether PIN is correct
 */
export const verifyParentPin = async (user, enteredPin) => {
  const storedPin = await getParentPin(user);
  return enteredPin === storedPin;
};

