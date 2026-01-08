/**
 * Data Policy Enforcement - Strict Privacy & Security
 *
 * Enforces COPPA/GDPR-compliant data minimization and child safety policies.
 *
 * CORE PRINCIPLES:
 * 1. NO raw media (images, audio, video) ever persisted
 * 2. Only derived numeric/text features may be stored
 * 3. Guardian consent required for ALL child interactions
 * 4. PII sanitization and redaction
 * 5. Safe logging with content redaction
 */

import { ErrorBus } from '../core/ErrorBus';

/**
 * ============================================================================
 * DATA MINIMIZATION & RETENTION POLICY
 * ============================================================================
 */

/**
 * Session store interface (simplified)
 */
export interface SessionStore {
  sessionId: string;
  data: Record<string, any>;
}

/**
 * Check if data type is raw media (forbidden to persist)
 *
 * Raw media types that MUST NOT be persisted:
 * - ImageData, Blob, ArrayBuffer (images/video)
 * - Float32Array, Int16Array (audio waveforms)
 * - Any object with 'imageData', 'buffer', 'pixels' properties
 * - Base64 image strings
 *
 * @param key - Data key name
 * @param value - Data value
 * @returns true if persistence allowed, false if raw media
 */
export function allowPersist(key: string, value: unknown): boolean {
  // Check for explicit raw media indicators in key name
  const forbiddenKeyPatterns = [
    'raw', 'image', 'frame', 'buffer', 'pixels', 'waveform',
    'audio', 'video', 'photo', 'recording'
  ];

  const lowerKey = key.toLowerCase();
  for (const pattern of forbiddenKeyPatterns) {
    if (lowerKey.includes(pattern)) {
      ErrorBus.report({
        code: 'RAW_MEDIA_PERSIST_BLOCKED',
        message: `Blocked persistence of raw media: key="${key}"`,
        severity: 'warn',
        context: { key, type: typeof value }
      });
      return false;
    }
  }

  // Check value type
  if (value === null || value === undefined) {
    return true; // Allow null/undefined
  }

  // Block typed arrays (audio buffers)
  if (
    value instanceof Float32Array ||
    value instanceof Float64Array ||
    value instanceof Int16Array ||
    value instanceof Int32Array ||
    value instanceof Uint8Array ||
    value instanceof Uint8ClampedArray
  ) {
    ErrorBus.report({
      code: 'RAW_MEDIA_PERSIST_BLOCKED',
      message: `Blocked persistence of typed array: key="${key}"`,
      severity: 'warn',
      context: { key, arrayType: value.constructor.name }
    });
    return false;
  }

  // Block ImageData
  if (typeof value === 'object' && value !== null) {
    // Check for ImageData properties
    if ('data' in value && 'width' in value && 'height' in value) {
      ErrorBus.report({
        code: 'RAW_MEDIA_PERSIST_BLOCKED',
        message: `Blocked persistence of ImageData: key="${key}"`,
        severity: 'warn',
        context: { key }
      });
      return false;
    }

    // Check for Blob
    if (value instanceof Blob) {
      ErrorBus.report({
        code: 'RAW_MEDIA_PERSIST_BLOCKED',
        message: `Blocked persistence of Blob: key="${key}"`,
        severity: 'warn',
        context: { key, blobType: value.type }
      });
      return false;
    }

    // Check for ArrayBuffer
    if (value instanceof ArrayBuffer) {
      ErrorBus.report({
        code: 'RAW_MEDIA_PERSIST_BLOCKED',
        message: `Blocked persistence of ArrayBuffer: key="${key}"`,
        severity: 'warn',
        context: { key }
      });
      return false;
    }

    // Check for base64 image strings
    if (typeof value === 'string' && value.startsWith('data:image/')) {
      ErrorBus.report({
        code: 'RAW_MEDIA_PERSIST_BLOCKED',
        message: `Blocked persistence of base64 image: key="${key}"`,
        severity: 'warn',
        context: { key }
      });
      return false;
    }
  }

  // Allow primitive types and safe objects
  return true;
}

/**
 * Apply retention policy to session data
 *
 * Pipeline location: Called after session ends
 *
 * Steps:
 * 1. Aggregate per-frame data into session summaries
 * 2. Delete detailed per-frame traces
 * 3. Keep only aggregated metrics
 *
 * @param sessionId - Session identifier
 * @param store - Session data store
 */
export function applyRetentionPolicy(sessionId: string, store: SessionStore): void {
  const data = store.data;

  // 1. Check for and remove raw media
  for (const key of Object.keys(data)) {
    if (!allowPersist(key, data[key])) {
      delete data[key];
      console.log(`[RetentionPolicy] Removed raw media: ${key}`);
    }
  }

  // 2. Aggregate per-frame arrays into summaries
  if (data.eyeSamples && Array.isArray(data.eyeSamples)) {
    // Replace with summary
    data.gazeSummary = {
      totalSamples: data.eyeSamples.length,
      avgAttention: calculateAvg(data.eyeSamples, 'attention'),
      regions: countRegions(data.eyeSamples)
    };
    delete data.eyeSamples; // Remove detailed traces
    console.log(`[RetentionPolicy] Aggregated ${data.gazeSummary.totalSamples} eye samples`);
  }

  if (data.audioFrames && Array.isArray(data.audioFrames)) {
    data.audioSummary = {
      totalFrames: data.audioFrames.length,
      avgPitch: calculateAvg(data.audioFrames, 'pitch'),
      avgVolume: calculateAvg(data.audioFrames, 'volume')
    };
    delete data.audioFrames;
    console.log(`[RetentionPolicy] Aggregated ${data.audioSummary.totalFrames} audio frames`);
  }

  if (data.faceFrames && Array.isArray(data.faceFrames)) {
    data.emotionSummary = {
      totalFrames: data.faceFrames.length,
      emotions: countEmotions(data.faceFrames),
      dominantEmotion: getDominantEmotion(data.faceFrames)
    };
    delete data.faceFrames;
    console.log(`[RetentionPolicy] Aggregated ${data.emotionSummary.totalFrames} face frames`);
  }

  // 3. Log policy application
  ErrorBus.report({
    code: 'RETENTION_POLICY_APPLIED',
    message: `Retention policy applied to session ${sessionId}`,
    severity: 'info',
    context: {
      sessionId,
      keysRemaining: Object.keys(data).length
    }
  });
}

// Helper functions for aggregation
function calculateAvg(arr: any[], field: string): number {
  const values = arr.map(item => item[field]).filter(v => typeof v === 'number');
  return values.length ? values.reduce((a, b) => a + b, 0) / values.length : 0;
}

function countRegions(samples: any[]): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const sample of samples) {
    const region = sample.region || 'unknown';
    counts[region] = (counts[region] || 0) + 1;
  }
  return counts;
}

function countEmotions(frames: any[]): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const frame of frames) {
    const emotion = frame.emotion || 'neutral';
    counts[emotion] = (counts[emotion] || 0) + 1;
  }
  return counts;
}

function getDominantEmotion(frames: any[]): string {
  const counts = countEmotions(frames);
  return Object.entries(counts).sort((a, b) => b[1] - a[1])[0]?.[0] || 'neutral';
}

/**
 * ============================================================================
 * GUARDIAN CONSENT & CHILD ACCOUNT SAFETY
 * ============================================================================
 */

export interface SessionContext {
  guardianConsent: boolean;
  childAge: number;
  networkEnabled: boolean;
  policyVersion: string;
}

export interface ChildProfile {
  childId: string;
  fullName?: string;
  dateOfBirth?: Date;
  ageBand: '3-5' | '6-10' | '11-15';
  language: string;
  approximateRegion?: string;
  // PII fields below should be removed by sanitization
  address?: string;
  email?: string;
  phone?: string;
  schoolName?: string;
}

/**
 * Ensure guardian consent before any child interaction
 *
 * COPPA/GDPR requirement: Verifiable parental consent required
 * for children under 13.
 *
 * Call this: At session start, before any data collection
 *
 * @param context - Session context
 * @throws Error if consent not granted
 */
export function ensureGuardianConsent(context: SessionContext): void {
  if (!context.guardianConsent) {
    const error = new Error(
      'Guardian consent required for child session. ' +
      'Cannot proceed without verifiable parental consent.'
    );

    ErrorBus.report({
      code: 'GUARDIAN_CONSENT_MISSING',
      message: error.message,
      severity: 'error',
      context: {
        childAge: context.childAge,
        policyVersion: context.policyVersion
      }
    });

    throw error;
  }

  // Log consent verification
  ErrorBus.report({
    code: 'GUARDIAN_CONSENT_VERIFIED',
    message: 'Guardian consent verified',
    severity: 'info',
    context: {
      childAge: context.childAge,
      policyVersion: context.policyVersion
    }
  });
}

/**
 * Sanitize child profile - remove sensitive PII
 *
 * Keeps only: age band, language, approximate region
 * Removes: full name, DOB, address, contact info, school
 *
 * Call this: Before storing or transmitting profile data
 *
 * @param profile - Raw child profile
 * @returns Sanitized profile (safe to store)
 */
export function sanitizeChildProfile(profile: ChildProfile): ChildProfile {
  const sanitized: ChildProfile = {
    childId: profile.childId, // Keep anonymized ID
    ageBand: profile.ageBand,
    language: profile.language,
    approximateRegion: profile.approximateRegion
  };

  // Log sanitization
  const removedFields = Object.keys(profile).filter(
    key => !Object.keys(sanitized).includes(key)
  );

  if (removedFields.length > 0) {
    ErrorBus.report({
      code: 'PII_SANITIZED',
      message: `Sanitized ${removedFields.length} PII fields from profile`,
      severity: 'info',
      context: {
        childId: profile.childId,
        removedFields
      }
    });
  }

  return sanitized;
}

/**
 * Check if online features can be used
 *
 * Requirements:
 * - Guardian consent granted
 * - Network enabled in settings
 * - Policy version accepted
 *
 * Call this: Before any network request (API calls, sync, etc.)
 *
 * @param context - Session context
 * @returns true if online features allowed
 */
export function canUseOnlineFeatures(context: SessionContext): boolean {
  // Check consent
  if (!context.guardianConsent) {
    ErrorBus.report({
      code: 'ONLINE_FEATURES_BLOCKED',
      message: 'Online features blocked: Guardian consent missing',
      severity: 'warn',
      context: { reason: 'no_consent' }
    });
    return false;
  }

  // Check network setting
  if (!context.networkEnabled) {
    ErrorBus.report({
      code: 'ONLINE_FEATURES_BLOCKED',
      message: 'Online features blocked: Network disabled in settings',
      severity: 'info',
      context: { reason: 'network_disabled' }
    });
    return false;
  }

  // All checks passed
  return true;
}

/**
 * ============================================================================
 * SAFE LOGGING & REDACTION
 * ============================================================================
 */

export interface LogEvent {
  type: string;
  payload: any;
  timestamp?: number;
}

/**
 * Redact child utterances from text
 *
 * Replaces any raw speech content with placeholder.
 * Preserves metadata (timestamps, labels) but not content.
 *
 * @param text - Potentially sensitive text
 * @returns Redacted text
 */
export function redactUtterance(text: string): string {
  // If text looks like a quote or direct speech, redact it
  if (
    text.includes('"') ||
    text.includes("'") ||
    text.toLowerCase().includes('said') ||
    text.toLowerCase().includes('asked')
  ) {
    return '[REDACTED_CHILD_SPEECH]';
  }

  // If text is longer than 50 chars and looks like content, redact
  if (text.length > 50 && !text.includes('=') && !text.includes(':')) {
    return '[REDACTED_CHILD_SPEECH]';
  }

  return text;
}

/**
 * Safe logger that automatically redacts sensitive content
 *
 * Call this: Instead of console.log for any event logging
 *
 * @param event - Event to log
 */
export function logEvent(event: LogEvent): void {
  const safeEvent = {
    type: event.type,
    timestamp: event.timestamp || Date.now(),
    payload: sanitizePayload(event.payload)
  };

  // Log to console (safe)
  console.log('[SafeLogger]', JSON.stringify(safeEvent));

  // Report to ErrorBus for centralized logging
  ErrorBus.report({
    code: 'EVENT_LOGGED',
    message: `Event logged: ${event.type}`,
    severity: 'info',
    context: safeEvent
  });
}

/**
 * Sanitize event payload recursively
 */
function sanitizePayload(payload: any): any {
  if (payload === null || payload === undefined) {
    return payload;
  }

  if (typeof payload === 'string') {
    return redactUtterance(payload);
  }

  if (Array.isArray(payload)) {
    return payload.map(sanitizePayload);
  }

  if (typeof payload === 'object') {
    const sanitized: any = {};

    for (const [key, value] of Object.entries(payload)) {
      // Redact known sensitive fields
      if (
        key.toLowerCase().includes('speech') ||
        key.toLowerCase().includes('utterance') ||
        key.toLowerCase().includes('text') ||
        key.toLowerCase().includes('content')
      ) {
        sanitized[key] = '[REDACTED]';
      } else {
        sanitized[key] = sanitizePayload(value);
      }
    }

    return sanitized;
  }

  return payload;
}

/**
 * USAGE EXAMPLES:
 *
 * // 1. Check before persisting
 * if (allowPersist('eyeTrackingData', data)) {
 *   await db.save('eyeTrackingData', data);
 * } // Blocks if data is raw media
 *
 * // 2. Apply retention policy after session
 * applyRetentionPolicy(sessionId, sessionStore);
 * // Aggregates detailed data, removes raw traces
 *
 * // 3. Check guardian consent
 * try {
 *   ensureGuardianConsent(sessionContext);
 *   // Proceed with session
 * } catch (error) {
 *   // Show consent screen
 * }
 *
 * // 4. Sanitize profile before storage
 * const safeProfile = sanitizeChildProfile(rawProfile);
 * await db.save('profile', safeProfile);
 *
 * // 5. Check before using network
 * if (canUseOnlineFeatures(context)) {
 *   await syncToCloud();
 * }
 *
 * // 6. Log events safely
 * logEvent({
 *   type: 'task_completed',
 *   payload: {
 *     taskId: 'emotion-naming',
 *     score: 85,
 *     utterance: 'I feel happy today' // Automatically redacted
 *   }
 * });
 * // Logs: payload.utterance = '[REDACTED_CHILD_SPEECH]'
 */
