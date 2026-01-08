/**
 * React hook for ML Worker
 * Provides easy interface to run ML inference in background
 */

import { useEffect, useRef, useState, useCallback } from 'react';
import { batteryManager } from '../utils/ml/batteryManager';
import { InferenceThrottle } from '../utils/ml/throttle';

export const useMLWorker = () => {
  const workerRef = useRef(null);
  const [isReady, setIsReady] = useState(false);
  const [loadedModels, setLoadedModels] = useState(new Set());
  const messageIdRef = useRef(0);
  const pendingRequestsRef = useRef(new Map());
  const throttleRef = useRef(new InferenceThrottle(100));

  // Initialize worker
  useEffect(() => {
    const worker = new Worker(
      new URL('../workers/ml.worker.js', import.meta.url),
      { type: 'module' }
    );

    workerRef.current = worker;

    // Handle messages from worker
    worker.onmessage = (event) => {
      const { id, type, success, error, ...data } = event.data;

      const pending = pendingRequestsRef.current.get(id);
      if (pending) {
        if (success) {
          pending.resolve(data);
        } else {
          pending.reject(new Error(error || 'Worker error'));
        }
        pendingRequestsRef.current.delete(id);
      }

      // Update loaded models list
      if (type === 'loadModel' && success) {
        setLoadedModels(prev => new Set([...prev, data.modelName]));
      }
    };

    worker.onerror = (error) => {
      console.error('[MLWorker] Error:', error);
    };

    // Initialize worker
    sendMessage('init').then(() => {
      setIsReady(true);
      console.log('[MLWorker] Ready');
    });

    // Initialize battery manager
    batteryManager.init().then(() => {
      // Update throttle based on battery
      const throttleMs = batteryManager.getRecommendedThrottle();
      throttleRef.current.setInterval(throttleMs);
      console.log('[MLWorker] Throttle set to', throttleMs, 'ms');
    });

    return () => {
      worker.terminate();
      setIsReady(false);
    };
  }, []);

  // Send message to worker
  const sendMessage = useCallback((type, payload = {}) => {
    return new Promise((resolve, reject) => {
      if (!workerRef.current) {
        reject(new Error('Worker not initialized'));
        return;
      }

      const id = messageIdRef.current++;
      pendingRequestsRef.current.set(id, { resolve, reject });

      workerRef.current.postMessage({ type, id, ...payload });
    });
  }, []);

  /**
   * Load a model
   */
  const loadModel = useCallback(async (modelName, modelUrl) => {
    if (!isReady) {
      throw new Error('Worker not ready');
    }

    console.log(`[MLWorker] Loading model: ${modelName}`);
    const result = await sendMessage('loadModel', { modelName, modelUrl });

    if (result.cached) {
      console.log(`[MLWorker] Model ${modelName} loaded from cache`);
    } else {
      console.log(`[MLWorker] Model ${modelName} loaded from network`);
    }

    return result;
  }, [isReady, sendMessage]);

  /**
   * Run inference with automatic throttling
   */
  const runInference = useCallback(async (modelName, inputs, options = {}) => {
    if (!isReady) {
      throw new Error('Worker not ready');
    }

    const { skipThrottle = false } = options;

    // Check battery status
    if (!batteryManager.canRunHeavyML()) {
      console.warn('[MLWorker] Skipping inference - low battery');
      return null;
    }

    // Convert inputs to transferable format
    const transferableInputs = {};
    for (const [name, tensor] of Object.entries(inputs)) {
      transferableInputs[name] = {
        data: Array.from(tensor.data),
        dims: tensor.dims,
        type: tensor.type
      };
    }

    const runFn = async () => {
      const result = await sendMessage('runInference', {
        modelName,
        inputs: transferableInputs
      });

      if (result.inferenceTime > 200) {
        console.warn(`[MLWorker] Slow inference: ${result.inferenceTime.toFixed(1)}ms`);
      }

      return result;
    };

    if (skipThrottle) {
      return await runFn();
    } else {
      // Use throttle for battery efficiency
      return new Promise((resolve, reject) => {
        throttleRef.current.throttle(async () => {
          try {
            const result = await runFn();
            resolve(result);
          } catch (error) {
            reject(error);
          }
        });
      });
    }
  }, [isReady, sendMessage]);

  /**
   * Release a model from worker memory
   */
  const releaseModel = useCallback(async (modelName) => {
    if (!isReady) return;

    await sendMessage('releaseModel', { modelName });
    setLoadedModels(prev => {
      const next = new Set(prev);
      next.delete(modelName);
      return next;
    });

    console.log(`[MLWorker] Released model: ${modelName}`);
  }, [isReady, sendMessage]);

  /**
   * Release all models
   */
  const releaseAll = useCallback(async () => {
    if (!isReady) return;

    await sendMessage('releaseAll');
    setLoadedModels(new Set());
    console.log('[MLWorker] Released all models');
  }, [isReady, sendMessage]);

  /**
   * Update throttle based on battery
   */
  const updateThrottle = useCallback(() => {
    const throttleMs = batteryManager.getRecommendedThrottle();
    throttleRef.current.setInterval(throttleMs);
    return throttleMs;
  }, []);

  return {
    isReady,
    loadedModels: Array.from(loadedModels),
    loadModel,
    runInference,
    releaseModel,
    releaseAll,
    updateThrottle,
    batteryInfo: batteryManager.getBatteryInfo()
  };
};
