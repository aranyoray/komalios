/**
 * Global ErrorBus - Centralized Error Handling
 *
 * Provides structured error reporting and handling across the application
 * with graceful degradation and non-intrusive UI notifications.
 *
 * RULES:
 * 1. Sensor failures: log severity 'warn', disable channel, keep app running
 * 2. Scoring failures: log severity 'error', skip metric, compute others
 * 3. Configuration issues: fall back to safe defaults, mark in context
 */

/**
 * Error severity levels
 */
export type ErrorSeverity = 'info' | 'warn' | 'error';

/**
 * Structured application error
 */
export interface AppError {
  code: string;                           // Error code (e.g., 'SENSOR_INIT_FAILED')
  message: string;                        // Human-readable message
  severity: ErrorSeverity;                // How serious is this?
  context?: Record<string, unknown>;      // Additional context data
  timestamp?: number;                     // When did this occur?
  stack?: string;                         // Stack trace for debugging
}

/**
 * Error listener callback
 */
export type ErrorListener = (error: AppError) => void;

/**
 * ErrorBus Singleton
 * Central hub for all application errors
 */
class ErrorBusClass {
  private listeners: ErrorListener[] = [];
  private errorHistory: AppError[] = [];
  private maxHistorySize = 100; // Keep last 100 errors

  /**
   * Report an error to the bus
   * All errors should flow through this method
   */
  report(error: AppError): void {
    // Add timestamp if not provided
    const enrichedError: AppError = {
      ...error,
      timestamp: error.timestamp || Date.now()
    };

    // Add to history
    this.errorHistory.push(enrichedError);
    if (this.errorHistory.length > this.maxHistorySize) {
      this.errorHistory.shift();
    }

    // Log to console based on severity
    this.logToConsole(enrichedError);

    // Notify all listeners
    this.notifyListeners(enrichedError);
  }

  /**
   * Subscribe to error events
   * Returns unsubscribe function
   */
  subscribe(listener: ErrorListener): () => void {
    this.listeners.push(listener);

    return () => {
      this.listeners = this.listeners.filter(l => l !== listener);
    };
  }

  /**
   * Get error history
   */
  getHistory(filter?: {
    severity?: ErrorSeverity;
    code?: string;
    since?: number;
  }): AppError[] {
    let history = [...this.errorHistory];

    if (filter) {
      if (filter.severity) {
        history = history.filter(e => e.severity === filter.severity);
      }
      if (filter.code) {
        history = history.filter(e => e.code === filter.code);
      }
      if (filter.since) {
        history = history.filter(e => (e.timestamp || 0) >= filter.since);
      }
    }

    return history;
  }

  /**
   * Clear error history
   */
  clearHistory(): void {
    this.errorHistory = [];
  }

  /**
   * Get error count by severity
   */
  getErrorCounts(): { info: number; warn: number; error: number } {
    return {
      info: this.errorHistory.filter(e => e.severity === 'info').length,
      warn: this.errorHistory.filter(e => e.severity === 'warn').length,
      error: this.errorHistory.filter(e => e.severity === 'error').length
    };
  }

  /**
   * Log error to console
   */
  private logToConsole(error: AppError): void {
    const prefix = `[ErrorBus:${error.severity.toUpperCase()}]`;
    const message = `${prefix} ${error.code}: ${error.message}`;

    switch (error.severity) {
      case 'info':
        console.info(message, error.context || '');
        break;
      case 'warn':
        console.warn(message, error.context || '');
        break;
      case 'error':
        console.error(message, error.context || '', error.stack || '');
        break;
    }
  }

  /**
   * Notify all listeners
   */
  private notifyListeners(error: AppError): void {
    for (const listener of this.listeners) {
      try {
        listener(error);
      } catch (err) {
        console.error('[ErrorBus] Listener threw error:', err);
      }
    }
  }
}

/**
 * Singleton instance
 */
export const ErrorBus = new ErrorBusClass();

/**
 * Helper function to create AppError from standard Error
 */
export function fromError(
  error: Error,
  code: string,
  severity: ErrorSeverity = 'error',
  context?: Record<string, unknown>
): AppError {
  return {
    code,
    message: error.message,
    severity,
    context,
    timestamp: Date.now(),
    stack: error.stack
  };
}

/**
 * Helper function to report sensor failure
 * Sets severity to 'warn' and includes sensor context
 */
export function reportSensorFailure(
  sensor: string,
  error: Error,
  additionalContext?: Record<string, unknown>
): void {
  ErrorBus.report({
    code: 'SENSOR_FAILURE',
    message: `${sensor} sensor failed: ${error.message}`,
    severity: 'warn',
    context: {
      sensor,
      errorName: error.name,
      ...additionalContext
    },
    timestamp: Date.now(),
    stack: error.stack
  });
}

/**
 * Helper function to report scoring failure
 * Sets severity to 'error' and includes metric context
 */
export function reportScoringFailure(
  metricId: string,
  error: Error,
  additionalContext?: Record<string, unknown>
): void {
  ErrorBus.report({
    code: 'SCORING_FAILURE',
    message: `Failed to compute ${metricId}: ${error.message}`,
    severity: 'error',
    context: {
      metricId,
      errorName: error.name,
      ...additionalContext
    },
    timestamp: Date.now(),
    stack: error.stack
  });
}

/**
 * Helper function to report configuration issue
 * Sets severity to 'warn' and includes config context
 */
export function reportConfigIssue(
  configKey: string,
  issue: string,
  fallbackValue: any
): void {
  ErrorBus.report({
    code: 'CONFIG_ISSUE',
    message: `Configuration issue with ${configKey}: ${issue}`,
    severity: 'warn',
    context: {
      configKey,
      issue,
      fallbackValue,
      fallbackApplied: true
    },
    timestamp: Date.now()
  });
}

/**
 * USAGE EXAMPLES:
 */

/**
 * Example 1: Sensor failure handling
 */
export function exampleSensorFailure(): void {
  try {
    // Try to initialize camera
    throw new Error('NotAllowedError: Permission denied');
  } catch (error: any) {
    // Report sensor failure
    reportSensorFailure('camera', error, {
      permissionDenied: true,
      attemptedAt: Date.now()
    });

    // Disable camera capability
    console.log('Camera disabled, continuing without eye tracking');
  }
}

/**
 * Example 2: Scoring failure handling
 */
export function exampleScoringFailure(): void {
  try {
    // Try to compute metric
    throw new Error('Division by zero');
  } catch (error: any) {
    // Report scoring failure
    reportScoringFailure('joint-attention', error, {
      sessionId: 'session-123',
      sampleCount: 0
    });

    // Skip this metric, return neutral default
    console.log('Skipping joint-attention metric, using default score of 50');
    return; // Don't throw, continue with other metrics
  }
}

/**
 * Example 3: Configuration fallback
 */
export function exampleConfigFallback(): void {
  let samplingRate: number;

  try {
    // Try to load user config
    const userConfig = JSON.parse('invalid json');
    samplingRate = userConfig.eyeHz;
  } catch (error: any) {
    // Fall back to safe default
    samplingRate = 12; // Default 12 Hz
    reportConfigIssue('eyeHz', 'Invalid user config', samplingRate);
  }

  console.log('Using sampling rate:', samplingRate);
}

/**
 * Example 4: UI listener for non-intrusive notifications
 */
export function exampleUIListener(): void {
  // Subscribe to errors
  const unsubscribe = ErrorBus.subscribe((error) => {
    // Only show errors to adult users, never to children
    if (error.severity === 'error' && !window.location.pathname.includes('/child/')) {
      // Show non-intrusive notification
      // (e.g., toast in bottom corner, not blocking modal)
      showToast({
        message: error.message,
        severity: error.severity,
        duration: 5000
      });
    }

    // Log warnings to parent dashboard
    if (error.severity === 'warn') {
      logToParentDashboard(error);
    }
  });

  // Later: unsubscribe
  // unsubscribe();
}

// Mock functions for example
function showToast(options: any): void {
  console.log('Toast:', options);
}

function logToParentDashboard(error: AppError): void {
  console.log('Dashboard log:', error);
}

/**
 * Example 5: Error monitoring and health check
 */
export function exampleHealthCheck(): {
  healthy: boolean;
  issues: string[];
} {
  const counts = ErrorBus.getErrorCounts();
  const recentErrors = ErrorBus.getHistory({
    since: Date.now() - 60000 // Last minute
  });

  const healthy = counts.error === 0 && recentErrors.length < 10;
  const issues: string[] = [];

  if (counts.error > 0) {
    issues.push(`${counts.error} errors detected`);
  }

  if (recentErrors.length > 10) {
    issues.push(`High error rate: ${recentErrors.length} errors in last minute`);
  }

  // Check for specific critical errors
  const criticalErrors = ErrorBus.getHistory({
    code: 'SENSOR_FAILURE',
    since: Date.now() - 300000 // Last 5 minutes
  });

  if (criticalErrors.length > 3) {
    issues.push('Multiple sensor failures detected');
  }

  return { healthy, issues };
}

/**
 * Example 6: Safe function wrapper
 * Wraps any function to automatically report errors
 */
export function safe<T extends (...args: any[]) => any>(
  fn: T,
  errorCode: string,
  severity: ErrorSeverity = 'error'
): T {
  return ((...args: Parameters<T>): ReturnType<T> | null => {
    try {
      return fn(...args);
    } catch (error: any) {
      ErrorBus.report(fromError(error, errorCode, severity, {
        functionName: fn.name,
        arguments: args
      }));
      return null;
    }
  }) as T;
}

/**
 * USAGE OF SAFE WRAPPER:
 *
 * // Wrap a risky function
 * const computeMetric = safe(
 *   (data: any[]) => {
 *     // Might throw
 *     return data.reduce((a, b) => a + b) / data.length;
 *   },
 *   'METRIC_COMPUTATION_ERROR',
 *   'warn'
 * );
 *
 * // Use it - errors are automatically reported, null returned on failure
 * const result = computeMetric([1, 2, 3]); // returns 2
 * const bad = computeMetric([]); // returns null, error reported
 */
