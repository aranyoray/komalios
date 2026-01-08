/**
 * Lightweight QA Test Harness
 *
 * Quick sanity checks for metric functions without full testing framework
 * Run manually to verify:
 * - Metrics handle edge cases
 * - Scores are within expected ranges
 * - No crashes on bad input
 */

import {
  defensiveMetrics,
  SessionData,
  MetricResult
} from '../assessment/defensiveMetrics';

/**
 * Test result
 */
interface TestResult {
  testName: string;
  metric: string;
  inputSummary: string;
  output: MetricResult;
  passed: boolean;
  issues: string[];
}

/**
 * Color codes for console output
 */
const COLORS = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  gray: '\x1b[90m'
};

/**
 * Create synthetic session data for testing
 */
function createTestSession(scenario: string): SessionData | null {
  switch (scenario) {
    case 'empty':
      // Empty session - should return neutral defaults
      return {
        sessionId: 'test-empty',
        duration: 60000,
        events: []
      };

    case 'null':
      // Null session - should handle gracefully
      return null;

    case 'good-attention':
      // High attention, good fixations
      return {
        sessionId: 'test-good-attention',
        duration: 120000,
        events: [],
        eyeTracking: {
          fixations: [
            { duration: 400, region: 'avatar-face' },
            { duration: 350, region: 'avatar-face' },
            { duration: 300, region: 'task-area' },
            { duration: 450, region: 'avatar-face' },
            { duration: 380, region: 'avatar-face' },
            { duration: 320, region: 'task-area' }
          ],
          saccades: [
            { timestamp: 1000 },
            { timestamp: 2000 },
            { timestamp: 3000 }
          ],
          attentionScore: 85
        }
      };

    case 'poor-attention':
      // Low attention, short fixations
      return {
        sessionId: 'test-poor-attention',
        duration: 120000,
        events: [],
        eyeTracking: {
          fixations: [
            { duration: 100, region: 'off-screen' },
            { duration: 80, region: 'unknown' },
            { duration: 120, region: 'off-screen' },
            { duration: 90, region: 'task-area' }
          ],
          saccades: [
            { timestamp: 500 },
            { timestamp: 700 },
            { timestamp: 900 },
            { timestamp: 1100 },
            { timestamp: 1300 },
            { timestamp: 1500 }
          ],
          attentionScore: 25
        }
      };

    case 'fast-response':
      // Quick, accurate responses
      return {
        sessionId: 'test-fast-response',
        duration: 90000,
        events: [],
        touchTracking: {
          touches: [
            { timestamp: 1000, latency: 250, accuracy: 0.95 },
            { timestamp: 2000, latency: 300, accuracy: 0.92 },
            { timestamp: 3000, latency: 220, accuracy: 0.98 },
            { timestamp: 4000, latency: 280, accuracy: 0.94 }
          ],
          goalDirectedAccuracy: 0.95
        }
      };

    case 'slow-response':
      // Slow, less accurate responses
      return {
        sessionId: 'test-slow-response',
        duration: 90000,
        events: [],
        touchTracking: {
          touches: [
            { timestamp: 1000, latency: 2500, accuracy: 0.65 },
            { timestamp: 4000, latency: 3200, accuracy: 0.58 },
            { timestamp: 8000, latency: 2800, accuracy: 0.62 }
          ],
          goalDirectedAccuracy: 0.62
        }
      };

    case 'regulated-emotions':
      // Stable, positive emotions
      return {
        sessionId: 'test-regulated',
        duration: 120000,
        events: [],
        microExpressions: {
          emotions: [
            { timestamp: 0, label: 'happy', confidence: 0.8 },
            { timestamp: 30000, label: 'happy', confidence: 0.75 },
            { timestamp: 60000, label: 'neutral', confidence: 0.7 },
            { timestamp: 90000, label: 'happy', confidence: 0.85 }
          ],
          engagementScore: 0.8
        }
      };

    case 'dysregulated-emotions':
      // Rapid emotion changes, negative emotions
      return {
        sessionId: 'test-dysregulated',
        duration: 60000,
        events: [],
        microExpressions: {
          emotions: [
            { timestamp: 0, label: 'happy', confidence: 0.6 },
            { timestamp: 5000, label: 'frustrated', confidence: 0.7 },
            { timestamp: 10000, label: 'angry', confidence: 0.8 },
            { timestamp: 15000, label: 'sad', confidence: 0.7 },
            { timestamp: 20000, label: 'frustrated', confidence: 0.75 },
            { timestamp: 25000, label: 'angry', confidence: 0.8 },
            { timestamp: 30000, label: 'neutral', confidence: 0.6 }
          ],
          engagementScore: 0.5
        }
      };

    case 'rich-vocabulary':
      // Good SEL vocabulary usage
      return {
        sessionId: 'test-rich-vocab',
        duration: 180000,
        events: [],
        voiceTracking: {
          utterances: [
            { timestamp: 1000, wordsPerMinute: 90, clarity: 0.8 }
          ],
          vocabulary: [
            'happy', 'sad', 'friend', 'share', 'help', 'excited',
            'worried', 'kind', 'thank', 'sorry', 'proud', 'calm'
          ]
        }
      };

    case 'limited-vocabulary':
      // Limited SEL vocabulary
      return {
        sessionId: 'test-limited-vocab',
        duration: 180000,
        events: [],
        voiceTracking: {
          utterances: [
            { timestamp: 1000, wordsPerMinute: 60, clarity: 0.6 }
          ],
          vocabulary: ['yes', 'no', 'okay', 'good']
        }
      };

    default:
      return null;
  }
}

/**
 * Validate metric result
 */
function validateResult(
  metric: string,
  result: MetricResult,
  expectedRange?: { min: number; max: number }
): { passed: boolean; issues: string[] } {
  const issues: string[] = [];

  // Check score is within [0, 100]
  if (result.score0to100 < 0 || result.score0to100 > 100) {
    issues.push(`Score out of range: ${result.score0to100}`);
  }

  // Check score is a number
  if (typeof result.score0to100 !== 'number' || isNaN(result.score0to100)) {
    issues.push(`Score is not a valid number: ${result.score0to100}`);
  }

  // Check expected range if provided
  if (expectedRange) {
    if (result.score0to100 < expectedRange.min || result.score0to100 > expectedRange.max) {
      issues.push(
        `Score ${result.score0to100} outside expected range [${expectedRange.min}, ${expectedRange.max}]`
      );
    }
  }

  // Check confidence is valid if provided
  if (result.confidence !== undefined) {
    if (result.confidence < 0 || result.confidence > 1) {
      issues.push(`Confidence out of range: ${result.confidence}`);
    }
  }

  return {
    passed: issues.length === 0,
    issues
  };
}

/**
 * Run a single test
 */
function runTest(
  testName: string,
  metric: string,
  metricFn: (data: SessionData | null) => MetricResult,
  sessionData: SessionData | null,
  expectedRange?: { min: number; max: number }
): TestResult {
  const inputSummary = sessionData
    ? `Session: ${sessionData.sessionId}, Duration: ${sessionData.duration}ms`
    : 'null session';

  try {
    const output = metricFn(sessionData);
    const validation = validateResult(metric, output, expectedRange);

    return {
      testName,
      metric,
      inputSummary,
      output,
      passed: validation.passed,
      issues: validation.issues
    };
  } catch (error: any) {
    return {
      testName,
      metric,
      inputSummary,
      output: {
        score0to100: -1,
        error: error.message
      },
      passed: false,
      issues: [`Unexpected error: ${error.message}`]
    };
  }
}

/**
 * Print test result
 */
function printResult(result: TestResult): void {
  const statusIcon = result.passed ? '✓' : '✗';
  const statusColor = result.passed ? COLORS.green : COLORS.red;

  console.log(`\n${statusColor}${statusIcon} ${result.testName}${COLORS.reset}`);
  console.log(`  ${COLORS.gray}Metric: ${result.metric}${COLORS.reset}`);
  console.log(`  ${COLORS.gray}Input: ${result.inputSummary}${COLORS.reset}`);
  console.log(`  ${COLORS.blue}Score: ${result.output.score0to100}/100${COLORS.reset}`);

  if (result.output.confidence !== undefined) {
    console.log(`  ${COLORS.gray}Confidence: ${result.output.confidence.toFixed(2)}${COLORS.reset}`);
  }

  if (result.output.dataPoints !== undefined) {
    console.log(`  ${COLORS.gray}Data Points: ${result.output.dataPoints}${COLORS.reset}`);
  }

  if (result.output.error) {
    console.log(`  ${COLORS.yellow}Error: ${result.output.error}${COLORS.reset}`);
  }

  if (result.issues.length > 0) {
    console.log(`  ${COLORS.red}Issues:${COLORS.reset}`);
    result.issues.forEach(issue => {
      console.log(`    - ${issue}`);
    });
  }
}

/**
 * Run all quick tests
 */
export function runQuickTests(): void {
  console.log(`\n${COLORS.blue}========================================`);
  console.log('  Komal Metric QA Test Suite');
  console.log(`========================================${COLORS.reset}\n`);

  const results: TestResult[] = [];

  // Test 1: Joint Attention - Empty Session
  results.push(
    runTest(
      'Joint Attention - Empty Session',
      'joint-attention',
      defensiveMetrics.computeJointAttention,
      createTestSession('empty'),
      { min: 40, max: 60 } // Should return neutral default
    )
  );

  // Test 2: Joint Attention - Null Session
  results.push(
    runTest(
      'Joint Attention - Null Session',
      'joint-attention',
      defensiveMetrics.computeJointAttention,
      createTestSession('null'),
      { min: 40, max: 60 } // Should return neutral default
    )
  );

  // Test 3: Joint Attention - Good Attention
  results.push(
    runTest(
      'Joint Attention - Good Attention',
      'joint-attention',
      defensiveMetrics.computeJointAttention,
      createTestSession('good-attention'),
      { min: 70, max: 100 } // Should be high
    )
  );

  // Test 4: Joint Attention - Poor Attention
  results.push(
    runTest(
      'Joint Attention - Poor Attention',
      'joint-attention',
      defensiveMetrics.computeJointAttention,
      createTestSession('poor-attention'),
      { min: 0, max: 40 } // Should be low
    )
  );

  // Test 5: Response Readiness - Fast Response
  results.push(
    runTest(
      'Response Readiness - Fast Response',
      'response-readiness',
      defensiveMetrics.computeResponseReadiness,
      createTestSession('fast-response'),
      { min: 80, max: 100 } // Should be high
    )
  );

  // Test 6: Response Readiness - Slow Response
  results.push(
    runTest(
      'Response Readiness - Slow Response',
      'response-readiness',
      defensiveMetrics.computeResponseReadiness,
      createTestSession('slow-response'),
      { min: 20, max: 50 } // Should be low
    )
  );

  // Test 7: Dysregulation - Regulated Emotions
  results.push(
    runTest(
      'Dysregulation - Regulated Emotions',
      'dysregulation',
      defensiveMetrics.computeDysregulation,
      createTestSession('regulated-emotions'),
      { min: 70, max: 100 } // High regulation = high score
    )
  );

  // Test 8: Dysregulation - Dysregulated Emotions
  results.push(
    runTest(
      'Dysregulation - Dysregulated Emotions',
      'dysregulation',
      defensiveMetrics.computeDysregulation,
      createTestSession('dysregulated-emotions'),
      { min: 20, max: 50 } // Low regulation = low score
    )
  );

  // Test 9: SEL Vocabulary - Rich Vocabulary
  results.push(
    runTest(
      'SEL Vocabulary - Rich Vocabulary',
      'sel-vocabulary',
      defensiveMetrics.computeSelVocabulary,
      createTestSession('rich-vocabulary'),
      { min: 70, max: 100 } // Should be high
    )
  );

  // Test 10: SEL Vocabulary - Limited Vocabulary
  results.push(
    runTest(
      'SEL Vocabulary - Limited Vocabulary',
      'sel-vocabulary',
      defensiveMetrics.computeSelVocabulary,
      createTestSession('limited-vocabulary'),
      { min: 0, max: 30 } // Should be low
    )
  );

  // Test 11: Attention Span - Good Attention
  results.push(
    runTest(
      'Attention Span - Good Attention',
      'attention-span',
      defensiveMetrics.computeAttentionSpan,
      createTestSession('good-attention'),
      { min: 60, max: 100 } // Should be high
    )
  );

  // Test 12: Goal-Directed Behavior - Fast Response
  results.push(
    runTest(
      'Goal-Directed Behavior - Fast Response',
      'goal-directed',
      defensiveMetrics.computeGoalDirectedBehavior,
      createTestSession('fast-response'),
      { min: 80, max: 100 } // High accuracy = high score
    )
  );

  // Print all results
  results.forEach(printResult);

  // Summary
  const passed = results.filter(r => r.passed).length;
  const failed = results.filter(r => !r.passed).length;
  const total = results.length;

  console.log(`\n${COLORS.blue}========================================`);
  console.log('  Test Summary');
  console.log(`========================================${COLORS.reset}`);
  console.log(`  ${COLORS.green}Passed: ${passed}/${total}${COLORS.reset}`);
  console.log(`  ${COLORS.red}Failed: ${failed}/${total}${COLORS.reset}`);

  if (failed > 0) {
    console.log(`\n${COLORS.yellow}⚠ Some tests failed. Review issues above.${COLORS.reset}\n`);
  } else {
    console.log(`\n${COLORS.green}✓ All tests passed!${COLORS.reset}\n`);
  }
}

/**
 * USAGE:
 *
 * // Run in browser console or Node.js:
 * import { runQuickTests } from './testing/quickTests';
 * runQuickTests();
 *
 * // Or from command line (if using ts-node):
 * npx ts-node src/testing/quickTests.ts
 */

// Auto-run if executed directly
if (typeof window === 'undefined' && require.main === module) {
  runQuickTests();
}
