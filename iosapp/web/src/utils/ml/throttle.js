/**
 * Efficient throttle for ML inference
 * Ensures minimum time between inferences to save battery
 */

export class InferenceThrottle {
  constructor(minInterval = 100) {
    this.minInterval = minInterval;
    this.lastCallTime = 0;
    this.timeoutId = null;
    this.pendingArgs = null;
  }

  setInterval(interval) {
    this.minInterval = interval;
  }

  /**
   * Throttle a function call
   * If called too soon, schedules for later
   */
  throttle(fn, ...args) {
    const now = performance.now();
    const timeSinceLastCall = now - this.lastCallTime;

    if (timeSinceLastCall >= this.minInterval) {
      // Enough time has passed, execute immediately
      this.lastCallTime = now;
      if (this.timeoutId) {
        clearTimeout(this.timeoutId);
        this.timeoutId = null;
      }
      return fn(...args);
    } else {
      // Too soon, schedule for later
      this.pendingArgs = args;

      if (!this.timeoutId) {
        const remaining = this.minInterval - timeSinceLastCall;
        this.timeoutId = setTimeout(() => {
          this.lastCallTime = performance.now();
          this.timeoutId = null;
          if (this.pendingArgs) {
            fn(...this.pendingArgs);
            this.pendingArgs = null;
          }
        }, remaining);
      }
    }
  }

  clear() {
    if (this.timeoutId) {
      clearTimeout(this.timeoutId);
      this.timeoutId = null;
    }
    this.pendingArgs = null;
  }
}

/**
 * Request Animation Frame with max FPS limit
 * More battery-efficient than pure RAF
 */
export class ThrottledRAF {
  constructor(maxFPS = 10) {
    this.maxFPS = maxFPS;
    this.minInterval = 1000 / maxFPS;
    this.lastTime = 0;
    this.rafId = null;
  }

  setMaxFPS(fps) {
    this.maxFPS = fps;
    this.minInterval = 1000 / fps;
  }

  start(callback) {
    const loop = (currentTime) => {
      this.rafId = requestAnimationFrame(loop);

      const elapsed = currentTime - this.lastTime;

      if (elapsed >= this.minInterval) {
        this.lastTime = currentTime - (elapsed % this.minInterval);
        callback(currentTime);
      }
    };

    this.rafId = requestAnimationFrame(loop);
  }

  stop() {
    if (this.rafId) {
      cancelAnimationFrame(this.rafId);
      this.rafId = null;
    }
  }
}
