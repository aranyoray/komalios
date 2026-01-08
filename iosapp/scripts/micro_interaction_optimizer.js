/**
 * micro_interaction_optimizer.js - Optimize UI animations for 60fps
 *
 * Controls easing curves and batches DOM updates for smooth performance
 * on low-end devices.
 */

class MicroInteractionOptimizer {
  constructor(options = {}) {
    this.targetFPS = options.targetFPS || 60;
    this.frameTime = 1000 / this.targetFPS;

    // Performance tier detection
    this.performanceTier = this._detectPerformanceTier();

    // Optimized easing curves by tier
    this.easingCurves = {
      high: {
        default: 'cubic-bezier(0.4, 0, 0.2, 1)',
        enter: 'cubic-bezier(0, 0, 0.2, 1)',
        exit: 'cubic-bezier(0.4, 0, 1, 1)',
        bounce: 'cubic-bezier(0.68, -0.55, 0.265, 1.55)'
      },
      medium: {
        default: 'ease-out',
        enter: 'ease-out',
        exit: 'ease-in',
        bounce: 'ease-out'
      },
      low: {
        default: 'linear',
        enter: 'linear',
        exit: 'linear',
        bounce: 'linear'
      }
    };

    // Animation durations by tier
    this.durations = {
      high: { short: 200, medium: 300, long: 500 },
      medium: { short: 150, medium: 200, long: 300 },
      low: { short: 100, medium: 150, long: 200 }
    };

    // Batch update queue
    this.updateQueue = [];
    this.rafId = null;
  }

  _detectPerformanceTier() {
    // Simple heuristics for device capability
    const memory = navigator.deviceMemory || 4;
    const cores = navigator.hardwareConcurrency || 4;

    if (memory >= 4 && cores >= 4) {
      return 'high';
    } else if (memory >= 2 && cores >= 2) {
      return 'medium';
    }
    return 'low';
  }

  getEasing(type = 'default') {
    return this.easingCurves[this.performanceTier][type] ||
           this.easingCurves[this.performanceTier].default;
  }

  getDuration(length = 'medium') {
    return this.durations[this.performanceTier][length] ||
           this.durations[this.performanceTier].medium;
  }

  /**
   * Optimized animation using transform and opacity only
   */
  animate(element, properties, options = {}) {
    const duration = options.duration || this.getDuration(options.length);
    const easing = options.easing || this.getEasing(options.easingType);

    // Convert to transform-only animations for performance
    const optimized = this._optimizeProperties(properties);

    // Use Web Animations API for better performance
    if (element.animate) {
      return element.animate(optimized.keyframes, {
        duration: duration,
        easing: easing,
        fill: options.fill || 'forwards'
      });
    }

    // Fallback to CSS transitions
    return this._cssTransition(element, optimized, duration, easing);
  }

  _optimizeProperties(properties) {
    const keyframes = [];
    const from = {};
    const to = {};

    for (const [key, value] of Object.entries(properties)) {
      // Convert layout properties to transforms
      if (key === 'left' || key === 'x') {
        to.transform = (to.transform || '') + ` translateX(${value})`;
      } else if (key === 'top' || key === 'y') {
        to.transform = (to.transform || '') + ` translateY(${value})`;
      } else if (key === 'scale') {
        to.transform = (to.transform || '') + ` scale(${value})`;
      } else if (key === 'rotate') {
        to.transform = (to.transform || '') + ` rotate(${value})`;
      } else if (key === 'opacity') {
        to.opacity = value;
      }
    }

    return {
      keyframes: [from, to],
      properties: to
    };
  }

  _cssTransition(element, optimized, duration, easing) {
    return new Promise(resolve => {
      element.style.transition = `all ${duration}ms ${easing}`;

      for (const [prop, value] of Object.entries(optimized.properties)) {
        element.style[prop] = value;
      }

      setTimeout(resolve, duration);
    });
  }

  /**
   * Batch DOM updates to reduce layout thrashing
   */
  batchUpdate(updateFn) {
    this.updateQueue.push(updateFn);

    if (!this.rafId) {
      this.rafId = requestAnimationFrame(() => this._flushUpdates());
    }
  }

  _flushUpdates() {
    const updates = this.updateQueue.splice(0);

    // Read phase
    const measurements = updates.map(update => {
      if (update.read) {
        return update.read();
      }
      return null;
    });

    // Write phase
    updates.forEach((update, i) => {
      if (update.write) {
        update.write(measurements[i]);
      } else if (typeof update === 'function') {
        update();
      }
    });

    this.rafId = null;
  }

  /**
   * Optimize scroll handling
   */
  optimizedScroll(element, handler, options = {}) {
    let ticking = false;
    let lastScrollY = 0;

    const throttled = () => {
      lastScrollY = element.scrollTop || window.scrollY;

      if (!ticking) {
        requestAnimationFrame(() => {
          handler(lastScrollY);
          ticking = false;
        });
        ticking = true;
      }
    };

    element.addEventListener('scroll', throttled, { passive: true });

    return () => element.removeEventListener('scroll', throttled);
  }

  /**
   * Get optimized animation config for current device
   */
  getConfig() {
    return {
      tier: this.performanceTier,
      easing: this.easingCurves[this.performanceTier],
      durations: this.durations[this.performanceTier],
      recommendations: this._getRecommendations()
    };
  }

  _getRecommendations() {
    const recs = [];

    if (this.performanceTier === 'low') {
      recs.push('Disable complex animations');
      recs.push('Use opacity and transform only');
      recs.push('Reduce particle counts');
      recs.push('Lower animation frame rate');
    } else if (this.performanceTier === 'medium') {
      recs.push('Simplify bounce/spring animations');
      recs.push('Batch DOM updates');
      recs.push('Use will-change sparingly');
    }

    return recs;
  }
}

// Export
if (typeof module !== 'undefined' && module.exports) {
  module.exports = MicroInteractionOptimizer;
} else if (typeof window !== 'undefined') {
  window.MicroInteractionOptimizer = MicroInteractionOptimizer;
}

// Usage example
if (typeof window !== 'undefined') {
  console.log('MicroInteractionOptimizer loaded');
  console.log('Example:');
  console.log('  const optimizer = new MicroInteractionOptimizer();');
  console.log('  optimizer.animate(element, { scale: 1.2, opacity: 1 });');
}
