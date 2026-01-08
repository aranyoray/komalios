/**
 * Supabase Multi-Provider Authentication Service
 *
 * Supports:
 * - Email/Password (credentials)
 * - Phone Number (OTP)
 * - Google OAuth
 * - Apple Sign In
 * - Account Linking (multiple providers per user)
 */

import { SupabaseClient, Session, User } from '@supabase/supabase-js';
// Use the same Supabase client instance with consistent storage key
import { supabase } from '../services/supabase';

export type AuthProvider = 'google' | 'apple';

/**
 * Sign up with email and password
 */
export async function signUpWithEmail(email: string, password: string, metadata?: any) {
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: metadata // Store additional user metadata
    }
  });

  if (error) throw error;

  // Create user record in users table after successful signup
  if (data.user) {
    try {
      const { error: dbError } = await supabase.rpc('handle_new_user');
      if (dbError) {
        console.error('[Auth] Failed to create user record:', dbError);
        // Don't throw - auth user is created, DB record can be created later
      }
    } catch (err) {
      console.error('[Auth] Error calling handle_new_user:', err);
      // Don't throw - auth user is created, DB record can be created later
    }
  }

  return data;
}

/**
 * Sign in with email and password
 */
export async function signInWithEmail(email: string, password: string) {
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password
  });

  if (error) throw error;

  // Ensure user record exists in users table after successful login
  if (data.user) {
    try {
      const { error: dbError } = await supabase.rpc('ensure_user_exists');
      if (dbError) {
        console.error('[Auth] Failed to ensure user exists:', dbError);
        // Don't throw - login succeeded, DB record can be created later
      }
    } catch (err) {
      console.error('[Auth] Error calling ensure_user_exists:', err);
      // Don't throw - login succeeded, DB record can be created later
    }
  }

  return data;
}

/**
 * Sign up/Sign in with phone number (OTP)
 * Step 1: Send OTP to phone
 */
export async function signInWithPhone(phone: string) {
  const { data, error } = await supabase.auth.signInWithOtp({
    phone
  });

  if (error) throw error;
  return data;
}

/**
 * Step 2: Verify OTP code
 */
export async function verifyPhoneOTP(phone: string, token: string) {
  const { data, error } = await supabase.auth.verifyOtp({
    phone,
    token,
    type: 'sms'
  });

  if (error) throw error;

  // Ensure user record exists in users table after successful OTP verification
  if (data.user) {
    try {
      const { error: dbError } = await supabase.rpc('ensure_user_exists');
      if (dbError) {
        console.error('[Auth] Failed to ensure user exists:', dbError);
        // Don't throw - login succeeded, DB record can be created later
      }
    } catch (err) {
      console.error('[Auth] Error calling ensure_user_exists:', err);
      // Don't throw - login succeeded, DB record can be created later
    }
  }

  return data;
}

/**
 * Sign in with OAuth provider (Google, Apple)
 */
export async function signInWithOAuth(provider: AuthProvider) {
  const { data, error } = await supabase.auth.signInWithOAuth({
    provider,
    options: {
      redirectTo: `${window.location.origin}/auth/callback`,
      // For account linking
      queryParams: {
        access_type: 'offline',
        prompt: 'consent'
      }
    }
  });

  if (error) throw error;
  return data;
}

/**
 * Link an additional auth provider to existing account
 * User must be already signed in
 */
export async function linkAuthProvider(provider: AuthProvider) {
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    throw new Error('Must be signed in to link provider');
  }

  // Sign in with new provider
  const { data, error } = await supabase.auth.linkIdentity({
    provider
  });

  if (error) throw error;
  return data;
}

/**
 * Unlink an auth provider from account
 */
export async function unlinkAuthProvider(provider: AuthProvider) {
  // Get current user to find the identity to unlink
  const { data: { user } } = await supabase.auth.getUser();
  
  if (!user) {
    throw new Error('Must be signed in to unlink provider');
  }

  // Find the identity matching the provider
  const identity = user.identities?.find(id => id.provider === provider);
  
  if (!identity) {
    throw new Error(`No linked identity found for provider: ${provider}`);
  }

  // Unlink using the full identity object
  const { data, error } = await supabase.auth.unlinkIdentity(identity);

  if (error) throw error;
  return data;
}

/**
 * Get current session
 */
export async function getSession(): Promise<Session | null> {
  const { data: { session } } = await supabase.auth.getSession();
  return session;
}

/**
 * Get current user
 */
export async function getCurrentUser(): Promise<User | null> {
  const { data: { user } } = await supabase.auth.getUser();
  return user;
}

/**
 * Get all linked identities for current user
 */
export async function getLinkedIdentities() {
  const user = await getCurrentUser();
  if (!user) return [];

  return user.identities || [];
}

/**
 * Sign out
 */
export async function signOut() {
  const { error } = await supabase.auth.signOut();
  if (error) throw error;
}

/**
 * Password reset via email (link-based - legacy)
 */
export async function resetPassword(email: string) {
  const { data, error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: `${window.location.origin}/auth/reset-password`
  });

  if (error) throw error;
  return data;
}

/**
 * Generate and send password reset code via email
 * Uses Supabase's email OTP system to send a 6-digit code
 */
export async function generatePasswordResetCode(email: string) {
  try {
    // Use Supabase's email OTP to send a code
    // This sends an email with a 6-digit code that can be verified
    const { data, error } = await supabase.auth.signInWithOtp({
      email: email.toLowerCase().trim(),
      options: {
        shouldCreateUser: false, // Don't create user if doesn't exist
        emailRedirectTo: undefined,
      }
    });

    if (error) {
      // Check if user doesn't exist
      if (error.message.includes('User not found') || error.message.includes('not registered')) {
        throw new Error('No account found with this email address');
      }
      throw error;
    }

    return { success: true, emailSent: true };
  } catch (error) {
    console.error('[Auth] Failed to generate reset code:', error);
    throw error;
  }
}

/**
 * Verify password reset code and create session
 * Uses Supabase's OTP verification which creates a session upon successful verification
 */
export async function verifyPasswordResetCode(email: string, code: string) {
  try {
    // Verify the OTP code sent via email
    // This will create a session if the code is valid
    const { data, error } = await supabase.auth.verifyOtp({
      email: email.toLowerCase().trim(),
      token: code,
      type: 'email'
    });

    if (error) {
      if (error.message.includes('expired') || error.message.includes('invalid')) {
        throw new Error('Invalid or expired reset code');
      }
      throw error;
    }

    // If successful, user now has a session
    // We can use this session to update the password
    return { 
      success: true, 
      codeVerified: true,
      session: data.session,
      user: data.user
    };
  } catch (error) {
    console.error('[Auth] Failed to verify reset code:', error);
    throw error;
  }
}

/**
 * Reset password with code (code-based reset)
 * This verifies the code (which creates a session), then updates the password
 */
export async function resetPasswordWithCode(email: string, code: string, newPassword: string) {
  try {
    // Step 1: Verify the code (this creates a session via OTP verification)
    const verifyResult = await verifyPasswordResetCode(email, code);
    
    if (!verifyResult.success || !verifyResult.codeVerified) {
      throw new Error('Invalid or expired reset code');
    }

    // Step 2: Check if we have a session from code verification
    let session = verifyResult.session;
    
    // If no session in result, check current session
    if (!session) {
      const { data: { session: currentSession } } = await supabase.auth.getSession();
      session = currentSession;
    }

    if (!session) {
      throw new Error('Session not created. Please try verifying the code again.');
    }

    // Step 3: Update password using the session from code verification
    const { data, error } = await supabase.auth.updateUser({
      password: newPassword
    });

    if (error) {
      // If password update fails, check if it's a session issue
      if (error.message.includes('session') || error.message.includes('expired')) {
        throw new Error('Your reset session has expired. Please request a new reset code.');
      }
      throw error;
    }

    return { success: true, data };
  } catch (error) {
    console.error('[Auth] Failed to reset password with code:', error);
    throw error;
  }
}

/**
 * Update password (must be signed in)
 */
export async function updatePassword(newPassword: string) {
  const { data, error } = await supabase.auth.updateUser({
    password: newPassword
  });

  if (error) throw error;
  return data;
}

/**
 * Update user metadata
 */
export async function updateUserMetadata(metadata: any) {
  const { data, error } = await supabase.auth.updateUser({
    data: metadata
  });

  if (error) throw error;
  return data;
}

/**
 * Listen to auth state changes
 */
export function onAuthStateChange(callback: (session: Session | null) => void) {
  const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
    callback(session);
  });

  return () => subscription.unsubscribe();
}

/**
 * Check if user has specific provider linked
 */
export async function hasProviderLinked(provider: string): Promise<boolean> {
  const identities = await getLinkedIdentities();
  return identities.some(identity => identity.provider === provider);
}

/**
 * Get primary auth method (first linked)
 */
export async function getPrimaryAuthMethod(): Promise<string | null> {
  const identities = await getLinkedIdentities();
  return identities[0]?.provider || null;
}
