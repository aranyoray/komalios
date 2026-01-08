/**
 * jank_detector.js - Detect frame stalls in web/mobile UI
 *
 * Measures frame stalling using requestAnimationFrame timestamps,
 * logs stalls, and recommends animation downgrades.
 */

class JankDetector {
  constructor(options = {}) {
    this.thresholds = {
      mild: options.mildThreshold || 50,    // 50ms (20 FPS)
      moderate: options.moderateThreshold || 100, // 100ms (10 FPS)
      severe: options.severeThreshold || 250     // 250ms (4 FPS)
    };

    this.history = [];
    this.maxHistory = options.maxHistory || 1000;
    this.lastFrameTime = 0;
    this.frameCount = 0;
    this.running = false;

    // Stats
    this.stats = {
      totalFrames: 0,
      mildJanks: 0,
      moderateJanks: 0,
      severeJanks: 0,
      totalJankTime: 0
    };

    // Recommendations
    this.recommendations = [];
  }

  start() {
    if (this.running) return;
    this.running = true;
    this.lastFrameTime = performance.now();
    this._tick();
    console.log('JankDetector started');
  }

  stop() {
    this.running = false;
    console.log('JankDetector stopped');
  }

  _tick() {
    if (!this.running) return;

    const now = performance.now();
    const delta = now - this.lastFrameTime;

    this._recordFrame(delta);

    this.lastFrameTime = now;
    this.frameCount++;

    requestAnimationFrame(() => this._tick());
  }

  _recordFrame(delta) {
    this.stats.totalFrames++;

    // Detect jank
    let severity = null;

    if (delta >= this.thresholds.severe) {
      severity = 'severe';
      this.stats.severeJanks++;
      this.stats.totalJankTime += delta;
    } else if (delta >= this.thresholds.moderate) {
      severity = 'moderate';
      this.stats.moderateJanks++;
      this.stats.totalJankTime += delta;
    } else if (delta >= this.thresholds.mild) {
      severity = 'mild';
      this.stats.mildJanks++;
      this.stats.totalJankTime += delta;
    }

    if (severity) {
      const entry = {
        timestamp: Date.now(),
        delta: delta,
        severity: severity,
        frameNumber: this.frameCount
      };

      this.history.push(entry);

      if (this.history.length > this.maxHistory) {
        this.history.shift();
      }

      console.warn(`Jank detected: ${severity} (${delta.toFixed(1)}ms)`);
    }
  }

  getStats() {
    const totalJanks = this.stats.mildJanks + this.stats.moderateJanks + this.stats.severeJanks;
    const jankRate = this.stats.totalFrames > 0
      ? (totalJanks / this.stats.totalFrames) * 100
      : 0;

    const avgFrameTime = this.stats.totalFrames > 0
      ? this.stats.totalJankTime / totalJanks || 0
      : 0;

    return {
      totalFrames: this.stats.totalFrames,
      totalJanks: totalJanks,
      jankRate: jankRate.toFixed(2) + '%',
      mildJanks: this.stats.mildJanks,
      moderateJanks: this.stats.moderateJanks,
      severeJanks: this.stats.severeJanks,
      avgJankDuration: avgFrameTime.toFixed(1) + 'ms'
    };
  }

  getRecommendations() {
    const stats = this.getStats();
    const recommendations = [];

    // Analyze patterns
    if (this.stats.severeJanks > 5) {
      recommendations.push({
        priority: 'high',
        issue: 'Frequent severe jank',
        actions: [
          'Disable complex animations',
          'Reduce particle effects',
          'Lower render resolution',
          'Check for layout thrashing'
        ]
      });
    }

    if (this.stats.moderateJanks > 20) {
      recommendations.push({
        priority: 'medium',
        issue: 'Moderate frame drops',
        actions: [
          'Simplify CSS animations',
          'Use transform instead of layout properties',
          'Batch DOM updates',
          'Consider requestIdleCallback for non-critical work'
        ]
      });
    }

    if (parseFloat(stats.jankRate) > 5) {
      recommendations.push({
        priority: 'medium',
        issue: 'High jank rate',
        actions: [
          'Profile with DevTools Performance tab',
          'Check for expensive event handlers',
          'Debounce scroll/resize handlers',
          'Use will-change for animated elements'
        ]
      });
    }

    // Check for patterns
    const recentHistory = this.history.slice(-100);
    const hasConsecutiveJanks = this._hasConsecutiveJanks(recentHistory, 3);

    if (hasConsecutiveJanks) {
      recommendations.push({
        priority: 'high',
        issue: 'Consecutive frame drops detected',
        actions: [
          'Check for synchronous operations in animation loop',
          'Move heavy computation to Web Worker',
          'Consider reducing animation complexity'
        ]
      });
    }

    return recommendations;
  }

  _hasConsecutiveJanks(history, count) {
    let consecutive = 0;

    for (let i = 1; i < history.length; i++) {
      if (history[i].frameNumber - history[i-1].frameNumber === 1) {
        consecutive++;
        if (consecutive >= count) return true;
      } else {
        consecutive = 0;
      }
    }

    return false;
  }

  reset() {
    this.history = [];
    this.frameCount = 0;
    this.stats = {
      totalFrames: 0,
      mildJanks: 0,
      moderateJanks: 0,
      severeJanks: 0,
      totalJankTime: 0
    };
  }

  exportReport() {
    return {
      stats: this.getStats(),
      recommendations: this.getRecommendations(),
      recentJanks: this.history.slice(-50),
      timestamp: new Date().toISOString()
    };
  }
}

// Export for Node.js or browser
if (typeof module !== 'undefined' && module.exports) {
  module.exports = JankDetector;
} else if (typeof window !== 'undefined') {
  window.JankDetector = JankDetector;
}

// Demo usage
if (typeof window !== 'undefined') {
  console.log('JankDetector loaded. Usage:');
  console.log('  const detector = new JankDetector();');
  console.log('  detector.start();');
  console.log('  // ... run your app ...');
  console.log('  console.log(detector.getStats());');
  console.log('  console.log(detector.getRecommendations());');
}
