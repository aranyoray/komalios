/**
 * BudgetedApiClient - API Usage and Cost Control
 *
 * Keeps cloud API calls within strict budgets for:
 * - Call count per session
 * - Token usage per session
 * - Concurrent requests
 * - Request timeouts
 *
 * Prevents runaway costs and ensures responsive UX
 */

import { ErrorBus } from '../core/ErrorBus';

/**
 * Budget configuration
 */
export interface BudgetConfig {
  maxCallsPerSession: number;      // Max API calls per session
  maxTokensPerSession: number;     // Max tokens (for LLM APIs)
  maxConcurrentRequests: number;   // Max simultaneous requests
  timeoutMs: number;               // Request timeout
}

/**
 * API call metadata
 */
interface ApiCallMetadata {
  endpoint: string;
  timestamp: number;
  tokens: number;
  duration?: number;
  success: boolean;
  error?: string;
}

/**
 * Budget error
 */
export class BudgetExceededError extends Error {
  constructor(
    message: string,
    public budgetType: 'calls' | 'tokens' | 'concurrent' | 'timeout',
    public current: number,
    public limit: number
  ) {
    super(message);
    this.name = 'BudgetExceededError';
  }
}

/**
 * Default budget configuration
 * Conservative limits for typical session
 */
export const DEFAULT_BUDGET: BudgetConfig = {
  maxCallsPerSession: 20,          // Up to 20 API calls per session
  maxTokensPerSession: 10000,      // Up to 10k tokens (GPT-4o-mini ~$0.015)
  maxConcurrentRequests: 3,        // Max 3 simultaneous requests
  timeoutMs: 10000                 // 10 second timeout
};

/**
 * Strict budget for cost control
 */
export const STRICT_BUDGET: BudgetConfig = {
  maxCallsPerSession: 10,
  maxTokensPerSession: 5000,
  maxConcurrentRequests: 2,
  timeoutMs: 5000
};

/**
 * Generous budget for research/analysis
 */
export const GENEROUS_BUDGET: BudgetConfig = {
  maxCallsPerSession: 50,
  maxTokensPerSession: 50000,
  maxConcurrentRequests: 5,
  timeoutMs: 30000
};

/**
 * BudgetedApiClient
 * Enforces usage limits on API calls
 */
export class BudgetedApiClient {
  private config: BudgetConfig;
  private currentCalls = 0;
  private currentTokens = 0;
  private activeRequests = 0;
  private callHistory: ApiCallMetadata[] = [];
  private abortControllers: Map<string, AbortController> = new Map();

  constructor(config: BudgetConfig = DEFAULT_BUDGET) {
    this.config = config;
  }

  /**
   * Update budget configuration
   */
  updateConfig(config: Partial<BudgetConfig>): void {
    this.config = { ...this.config, ...config };
    console.log('[BudgetedApiClient] Config updated:', this.config);
  }

  /**
   * Check if a call can be made
   * Returns true if within budget limits
   */
  canCall(costTokens: number): boolean {
    // Check call count
    if (this.currentCalls >= this.config.maxCallsPerSession) {
      return false;
    }

    // Check token count
    if (this.currentTokens + costTokens > this.config.maxTokensPerSession) {
      return false;
    }

    // Check concurrent requests
    if (this.activeRequests >= this.config.maxConcurrentRequests) {
      return false;
    }

    return true;
  }

  /**
   * Make an API call with budget enforcement
   *
   * @param endpoint - API endpoint URL
   * @param payload - Request payload
   * @param costTokens - Estimated token cost
   * @param options - Fetch options
   * @returns API response
   * @throws BudgetExceededError if budget exceeded
   */
  async call<T = any>(
    endpoint: string,
    payload: any,
    costTokens: number,
    options: RequestInit = {}
  ): Promise<T> {
    const callId = `${endpoint}-${Date.now()}`;
    const startTime = Date.now();

    // Check budget
    if (!this.canCall(costTokens)) {
      const error = this.getBudgetError(costTokens);
      this.logCall({
        endpoint,
        timestamp: startTime,
        tokens: costTokens,
        success: false,
        error: error.message
      });
      throw error;
    }

    // Increment counters
    this.currentCalls++;
    this.currentTokens += costTokens;
    this.activeRequests++;

    // Create abort controller for timeout
    const abortController = new AbortController();
    this.abortControllers.set(callId, abortController);

    // Set timeout
    const timeoutId = setTimeout(() => {
      abortController.abort();
    }, this.config.timeoutMs);

    try {
      // Make request
      const response = await fetch(endpoint, {
        ...options,
        method: options.method || 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...options.headers
        },
        body: JSON.stringify(payload),
        signal: abortController.signal
      });

      // Clear timeout
      clearTimeout(timeoutId);

      // Check response
      if (!response.ok) {
        throw new Error(`API error: ${response.status} ${response.statusText}`);
      }

      const data = await response.json();
      const duration = Date.now() - startTime;

      // Log successful call
      this.logCall({
        endpoint,
        timestamp: startTime,
        tokens: costTokens,
        duration,
        success: true
      });

      return data as T;
    } catch (error: any) {
      clearTimeout(timeoutId);

      // Handle timeout
      if (error.name === 'AbortError') {
        const timeoutError = new BudgetExceededError(
          `Request to ${endpoint} exceeded timeout of ${this.config.timeoutMs}ms`,
          'timeout',
          Date.now() - startTime,
          this.config.timeoutMs
        );

        this.logCall({
          endpoint,
          timestamp: startTime,
          tokens: costTokens,
          success: false,
          error: timeoutError.message
        });

        // Report to ErrorBus
        ErrorBus.report({
          code: 'API_TIMEOUT',
          message: timeoutError.message,
          severity: 'warn',
          context: {
            endpoint,
            timeoutMs: this.config.timeoutMs
          }
        });

        throw timeoutError;
      }

      // Handle other errors
      this.logCall({
        endpoint,
        timestamp: startTime,
        tokens: costTokens,
        success: false,
        error: error.message
      });

      // Report to ErrorBus
      ErrorBus.report({
        code: 'API_CALL_FAILED',
        message: `API call to ${endpoint} failed: ${error.message}`,
        severity: 'error',
        context: {
          endpoint,
          error: error.message
        }
      });

      throw error;
    } finally {
      // Cleanup
      this.activeRequests--;
      this.abortControllers.delete(callId);
    }
  }

  /**
   * Get appropriate budget error
   */
  private getBudgetError(costTokens: number): BudgetExceededError {
    // Check which limit was exceeded
    if (this.currentCalls >= this.config.maxCallsPerSession) {
      const error = new BudgetExceededError(
        `Call limit exceeded: ${this.currentCalls}/${this.config.maxCallsPerSession}`,
        'calls',
        this.currentCalls,
        this.config.maxCallsPerSession
      );

      ErrorBus.report({
        code: 'BUDGET_EXCEEDED_CALLS',
        message: error.message,
        severity: 'warn',
        context: {
          current: this.currentCalls,
          limit: this.config.maxCallsPerSession
        }
      });

      return error;
    }

    if (this.currentTokens + costTokens > this.config.maxTokensPerSession) {
      const error = new BudgetExceededError(
        `Token limit exceeded: ${this.currentTokens + costTokens}/${this.config.maxTokensPerSession}`,
        'tokens',
        this.currentTokens + costTokens,
        this.config.maxTokensPerSession
      );

      ErrorBus.report({
        code: 'BUDGET_EXCEEDED_TOKENS',
        message: error.message,
        severity: 'warn',
        context: {
          current: this.currentTokens + costTokens,
          limit: this.config.maxTokensPerSession
        }
      });

      return error;
    }

    if (this.activeRequests >= this.config.maxConcurrentRequests) {
      const error = new BudgetExceededError(
        `Concurrent request limit exceeded: ${this.activeRequests}/${this.config.maxConcurrentRequests}`,
        'concurrent',
        this.activeRequests,
        this.config.maxConcurrentRequests
      );

      ErrorBus.report({
        code: 'BUDGET_EXCEEDED_CONCURRENT',
        message: error.message,
        severity: 'warn',
        context: {
          current: this.activeRequests,
          limit: this.config.maxConcurrentRequests
        }
      });

      return error;
    }

    // Default error
    return new BudgetExceededError(
      'Budget limit exceeded',
      'calls',
      this.currentCalls,
      this.config.maxCallsPerSession
    );
  }

  /**
   * Log API call
   */
  private logCall(metadata: ApiCallMetadata): void {
    this.callHistory.push(metadata);

    // Keep only last 100 calls
    if (this.callHistory.length > 100) {
      this.callHistory.shift();
    }
  }

  /**
   * Get current usage statistics
   */
  getUsage(): {
    calls: number;
    tokens: number;
    activeRequests: number;
    callsRemaining: number;
    tokensRemaining: number;
  } {
    return {
      calls: this.currentCalls,
      tokens: this.currentTokens,
      activeRequests: this.activeRequests,
      callsRemaining: this.config.maxCallsPerSession - this.currentCalls,
      tokensRemaining: this.config.maxTokensPerSession - this.currentTokens
    };
  }

  /**
   * Get call history
   */
  getHistory(filter?: {
    success?: boolean;
    since?: number;
  }): ApiCallMetadata[] {
    let history = [...this.callHistory];

    if (filter) {
      if (filter.success !== undefined) {
        history = history.filter(c => c.success === filter.success);
      }
      if (filter.since !== undefined) {
        history = history.filter(c => c.timestamp >= filter.since);
      }
    }

    return history;
  }

  /**
   * Get success rate
   */
  getSuccessRate(): number {
    if (this.callHistory.length === 0) return 1;

    const successful = this.callHistory.filter(c => c.success).length;
    return successful / this.callHistory.length;
  }

  /**
   * Get average response time
   */
  getAverageResponseTime(): number {
    const calls = this.callHistory.filter(c => c.duration !== undefined);
    if (calls.length === 0) return 0;

    const totalDuration = calls.reduce((sum, c) => sum + (c.duration || 0), 0);
    return totalDuration / calls.length;
  }

  /**
   * Reset budget (e.g., for new session)
   */
  reset(): void {
    this.currentCalls = 0;
    this.currentTokens = 0;
    this.activeRequests = 0;
    this.callHistory = [];

    // Abort any pending requests
    for (const controller of this.abortControllers.values()) {
      controller.abort();
    }
    this.abortControllers.clear();

    console.log('[BudgetedApiClient] Budget reset');
  }

  /**
   * Abort all pending requests
   */
  abortAll(): void {
    for (const controller of this.abortControllers.values()) {
      controller.abort();
    }
    this.abortControllers.clear();
    this.activeRequests = 0;
  }
}

/**
 * USAGE EXAMPLE:
 *
 * // 1. Create client with budget
 * const apiClient = new BudgetedApiClient(DEFAULT_BUDGET);
 *
 * // 2. Check if call can be made
 * const canMakeCall = apiClient.canCall(500); // 500 tokens
 * if (!canMakeCall) {
 *   console.log('Budget exceeded, cannot make call');
 *   return;
 * }
 *
 * // 3. Make API call
 * try {
 *   const response = await apiClient.call(
 *     'https://api.openai.com/v1/chat/completions',
 *     {
 *       model: 'gpt-4o-mini',
 *       messages: [{ role: 'user', content: 'Hello' }],
 *       max_tokens: 100
 *     },
 *     500, // Estimated token cost
 *     {
 *       headers: {
 *         'Authorization': `Bearer ${API_KEY}`
 *       }
 *     }
 *   );
 *   console.log('Response:', response);
 * } catch (error) {
 *   if (error instanceof BudgetExceededError) {
 *     console.log('Budget exceeded:', error.message);
 *     // Show user-friendly message
 *   } else {
 *     console.error('API call failed:', error);
 *   }
 * }
 *
 * // 4. Monitor usage
 * const usage = apiClient.getUsage();
 * console.log('API Usage:', usage);
 * console.log('Success Rate:', apiClient.getSuccessRate());
 *
 * // 5. Reset for new session
 * apiClient.reset();
 */

/**
 * Create a budgeted API client
 */
export function createBudgetedClient(
  config: BudgetConfig = DEFAULT_BUDGET
): BudgetedApiClient {
  return new BudgetedApiClient(config);
}

/**
 * OpenAI-specific helper
 * Estimates token count for OpenAI API calls
 */
export function estimateOpenAITokens(
  messages: Array<{ role: string; content: string }>,
  maxTokens: number = 100
): number {
  // Rough estimation: ~4 chars per token
  const inputChars = messages.reduce((sum, msg) => sum + msg.content.length, 0);
  const inputTokens = Math.ceil(inputChars / 4);
  const outputTokens = maxTokens;

  return inputTokens + outputTokens;
}
