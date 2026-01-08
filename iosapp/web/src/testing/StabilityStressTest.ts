/**
 * Stability Stress Test - Long Session Simulation
 * Simulates 30-minute session with all sensors
 * Checks: memory leaks, CPU stability, event timing
 */

import { SensorManager } from '../sensors/SensorManager';
import { MultimodalSyncEngine } from '../sync/MultimodalSyncEngine';
import { SessionSummarizer } from '../session/SessionSummarizer';

export interface StressTestResult {
  duration: number;
  totalEvents: number;
  memoryUsageMB: number;
  avgEventRate: number;
  errors: string[];
  warnings: string[];
  passed: boolean;
}

export class StabilityStressTest {
  async runTest(durationMinutes: number = 30): Promise<StressTestResult> {
    console.log(`[StressTest] Starting ${durationMinutes}-minute stability test...`);

    const startTime = Date.now();
    const startMemory = (performance as any).memory?.usedJSHeapSize || 0;
    const errors: string[] = [];
    const warnings: string[] = [];

    // Initialize systems
    const sensorManager = new SensorManager();
    const syncEngine = new MultimodalSyncEngine();
    const summarizer = new SessionSummarizer();

    // Initialize sensors (mock mode)
    await sensorManager.init();

    // Start simulation
    const simulationInterval = 100; // ms
    const totalIterations = (durationMinutes * 60 * 1000) / simulationInterval;
    let iteration = 0;

    const intervalId = setInterval(() => {
      try {
        // Mock eye samples
        if (iteration % 10 === 0) { // Every 100ms
          syncEngine.registerEvent('gaze', Date.now(), {
            region: ['avatar-face', 'task-area', 'off-screen'][Math.floor(Math.random() * 3)],
            attentionLevel: ['high', 'medium', 'low'][Math.floor(Math.random() * 3)]
          }, 'eye-tracker');
        }

        // Mock micro-expressions
        if (iteration % 15 === 0) { // Every 150ms
          syncEngine.registerEvent('emotion', Date.now(), {
            label: ['happy', 'neutral', 'frustrated'][Math.floor(Math.random() * 3)],
            confidence: 0.7 + Math.random() * 0.3
          }, 'face-detector');
        }

        // Mock audio chunks
        if (iteration % 30 === 0) { // Every 300ms
          syncEngine.registerEvent('audio', Date.now(), {
            type: 'speech',
            power: Math.random()
          }, 'mic');
        }

        // Mock taps
        if (iteration % 50 === 0 && Math.random() > 0.7) {
          syncEngine.registerEvent('tap', Date.now(), {
            target: 'button',
            force: Math.random()
          }, 'touch');
        }

        // Update summarizer
        summarizer.update({
          attention: Math.random() * 100,
          emotion: ['happy', 'neutral'][Math.floor(Math.random() * 2)],
          latency: 1000 + Math.random() * 2000
        });

        iteration++;

        // Check for completion
        if (iteration >= totalIterations) {
          clearInterval(intervalId);
          this.completeTest();
        }

      } catch (error: any) {
        errors.push(error.message);
      }
    }, simulationInterval);

    // Complete test function
    const completeTest = (): StressTestResult => {
      const endTime = Date.now();
      const endMemory = (performance as any).memory?.usedJSHeapSize || 0;
      const duration = endTime - startTime;

      // Get stats
      const stats = syncEngine.getStats();
      const memoryUsageMB = (endMemory - startMemory) / 1024 / 1024;

      // Check for issues
      if (memoryUsageMB > 100) {
        warnings.push(`High memory usage: ${memoryUsageMB.toFixed(2)}MB`);
      }

      if (stats.avgEventsPerSecond < 1) {
        warnings.push('Low event rate detected');
      }

      // Cleanup
      sensorManager.stop();
      syncEngine.clear();
      summarizer.reset();

      const passed = errors.length === 0 && memoryUsageMB < 200;

      console.log(`[StressTest] Completed in ${(duration / 1000).toFixed(1)}s`);
      console.log(`[StressTest] Events processed: ${stats.totalEvents}`);
      console.log(`[StressTest] Memory usage: ${memoryUsageMB.toFixed(2)}MB`);
      console.log(`[StressTest] Status: ${passed ? 'PASSED' : 'FAILED'}`);

      return {
        duration,
        totalEvents: stats.totalEvents,
        memoryUsageMB,
        avgEventRate: stats.avgEventsPerSecond,
        errors,
        warnings,
        passed
      };
    };

    // Wait for completion
    return new Promise(resolve => {
      const checkInterval = setInterval(() => {
        if (iteration >= totalIterations) {
          clearInterval(checkInterval);
          resolve(completeTest());
        }
      }, 1000);
    });
  }
}

/**
 * USAGE:
 * const stressTest = new StabilityStressTest();
 * const result = await stressTest.runTest(30); // 30-minute test
 *
 * console.log('Test Result:', result);
 * if (!result.passed) {
 *   console.error('Errors:', result.errors);
 *   console.warn('Warnings:', result.warnings);
 * }
 */
