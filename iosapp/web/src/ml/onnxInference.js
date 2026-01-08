/**
 * ONNX Runtime inference manager
 * Optimized for browser performance and battery efficiency
 */

import * as ort from 'onnxruntime-web';
import { modelCache } from '../utils/ml/modelCache';
import { batteryManager } from '../utils/ml/batteryManager';

// Configure ONNX Runtime for optimal performance on mobile
ort.env.wasm.numThreads = 1; // Single thread for better battery life
ort.env.wasm.simd = true; // Enable SIMD for faster computation
ort.env.wasm.proxy = false; // Disable proxy for lower overhead

class ONNXInference {
  constructor() {
    this.sessions = new Map();
    this.initialized = false;
  }

  async init() {
    if (this.initialized) return;

    // Set WASM paths (adjust based on your build setup)
    ort.env.wasm.wasmPaths = 'https://cdn.jsdelivr.net/npm/onnxruntime-web@1.20.0/dist/';

    await batteryManager.init();
    this.initialized = true;

    console.log('[ONNX] Initialized with config:', {
      wasmThreads: ort.env.wasm.numThreads,
      simd: ort.env.wasm.simd,
      battery: batteryManager.getBatteryInfo()
    });
  }

  /**
   * Load an ONNX model with caching
   * @param {string} modelName - Unique name for the model
   * @param {string} modelUrl - URL or path to .onnx file
   * @param {object} options - Session options
   */
  async loadModel(modelName, modelUrl, options = {}) {
    await this.init();

    if (this.sessions.has(modelName)) {
      return this.sessions.get(modelName);
    }

    const loadFn = async () => {
      // Get battery-aware execution provider preference
      const executionProviders = this.getExecutionProviders();

      const sessionOptions = {
        executionProviders,
        graphOptimizationLevel: 'all',
        executionMode: 'sequential', // Better for single-threaded
        ...options
      };

      const session = await ort.InferenceSession.create(modelUrl, sessionOptions);
      this.sessions.set(modelName, session);
      return session;
    };

    return await modelCache.loadModel(`onnx_${modelName}`, loadFn, true);
  }

  /**
   * Get execution providers based on battery and device capabilities
   */
  getExecutionProviders() {
    const providers = [];

    // Try WebGL first (GPU acceleration) if battery allows
    if (batteryManager.canRunHeavyML()) {
      providers.push('webgl');
    }

    // Fallback to WASM (CPU)
    providers.push('wasm');

    return providers;
  }

  /**
   * Run inference on a model
   * @param {string} modelName - Model to use
   * @param {object} inputs - Input tensors { inputName: tensor }
   * @returns {object} Output tensors
   */
  async runInference(modelName, inputs) {
    const session = this.sessions.get(modelName);
    if (!session) {
      throw new Error(`Model ${modelName} not loaded. Call loadModel() first.`);
    }

    try {
      const startTime = performance.now();
      const results = await session.run(inputs);
      const inferenceTime = performance.now() - startTime;

      if (inferenceTime > 100) {
        console.warn(`[ONNX] Slow inference for ${modelName}: ${inferenceTime.toFixed(1)}ms`);
      }

      return { outputs: results, inferenceTime };
    } catch (error) {
      console.error(`[ONNX] Inference failed for ${modelName}:`, error);
      throw error;
    }
  }

  /**
   * Preprocess image for model input
   * @param {ImageData|HTMLImageElement|HTMLCanvasElement} image
   * @param {object} options - { width, height, mean, std }
   */
  preprocessImage(image, options = {}) {
    const {
      width = 224,
      height = 224,
      mean = [127.5, 127.5, 127.5],
      std = [127.5, 127.5, 127.5],
      normalize = true
    } = options;

    // Create canvas for resizing
    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext('2d');

    // Draw and resize image
    ctx.drawImage(image, 0, 0, width, height);
    const imageData = ctx.getImageData(0, 0, width, height);

    // Convert to CHW format (Channels, Height, Width)
    const pixelData = imageData.data;
    const channels = 3;
    const imageSize = width * height;
    const float32Data = new Float32Array(channels * imageSize);

    for (let i = 0; i < imageSize; i++) {
      const pixelIndex = i * 4;
      for (let c = 0; c < channels; c++) {
        let value = pixelData[pixelIndex + c];

        // Normalize if needed
        if (normalize) {
          value = (value - mean[c]) / std[c];
        }

        // CHW format: channel_offset + pixel_position
        float32Data[c * imageSize + i] = value;
      }
    }

    return new ort.Tensor('float32', float32Data, [1, channels, height, width]);
  }

  /**
   * Resize image tensor efficiently
   */
  resizeImageTensor(tensor, targetWidth, targetHeight) {
    // This is a simple implementation - for production, use a proper resize library
    // or handle resizing before creating the tensor
    return tensor;
  }

  /**
   * Release a model from memory
   */
  async releaseModel(modelName) {
    const session = this.sessions.get(modelName);
    if (session) {
      // ONNX sessions don't have explicit dispose, but we remove from cache
      this.sessions.delete(modelName);
      console.log(`[ONNX] Released model: ${modelName}`);
    }
  }

  /**
   * Release all models
   */
  releaseAll() {
    this.sessions.clear();
    modelCache.clearMemoryCache();
    console.log('[ONNX] Released all models');
  }

  getLoadedModels() {
    return Array.from(this.sessions.keys());
  }

  isModelLoaded(modelName) {
    return this.sessions.has(modelName);
  }
}

export const onnxInference = new ONNXInference();
