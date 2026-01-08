/**
 * webassembly_inference_wrapper.js — Run small models in browser cheaply
 * Compiles ONNX/TFLite to WASM, runs in worker, falls back to server
 */

// Configuration
const CONFIG = {
  modelUrl: '/models/lite_model.onnx',
  wasmUrl: '/wasm/ort-wasm.wasm',
  serverFallbackUrl: '/api/inference',
  maxInputSize: 224,
  timeout: 5000
};

// Model state
let session = null;
let isInitialized = false;
let useServerFallback = false;

/**
 * Initialize WASM inference session
 */
async function initializeModel() {
  if (isInitialized) return true;

  try {
    // Check for ONNX Runtime Web
    if (typeof ort === 'undefined') {
      // Try to load dynamically
      await loadScript('https://cdn.jsdelivr.net/npm/onnxruntime-web/dist/ort.min.js');
    }

    // Configure WASM
    ort.env.wasm.wasmPaths = '/wasm/';

    // Create inference session
    session = await ort.InferenceSession.create(CONFIG.modelUrl, {
      executionProviders: ['wasm'],
      graphOptimizationLevel: 'all'
    });

    isInitialized = true;
    console.log('WASM inference initialized');
    return true;

  } catch (error) {
    console.warn('WASM initialization failed, using server fallback:', error);
    useServerFallback = true;
    return false;
  }
}

/**
 * Run inference on input
 */
async function runInference(inputData) {
  // Ensure initialization
  if (!isInitialized && !useServerFallback) {
    await initializeModel();
  }

  if (useServerFallback) {
    return serverInference(inputData);
  }

  try {
    // Preprocess input
    const tensor = preprocessInput(inputData);

    // Run inference
    const feeds = { input: tensor };
    const results = await session.run(feeds);

    // Get output
    const output = results.output.data;

    return {
      success: true,
      data: Array.from(output),
      source: 'wasm'
    };

  } catch (error) {
    console.error('WASM inference failed:', error);

    // Fallback to server
    return serverInference(inputData);
  }
}

/**
 * Preprocess input for model
 */
function preprocessInput(inputData) {
  // Handle different input types
  let data;

  if (inputData instanceof ImageData) {
    // Convert ImageData to tensor
    data = imageDataToTensor(inputData);
  } else if (inputData instanceof Float32Array) {
    data = inputData;
  } else if (Array.isArray(inputData)) {
    data = new Float32Array(inputData);
  } else {
    throw new Error('Unsupported input type');
  }

  // Create ONNX tensor
  const dims = [1, 3, CONFIG.maxInputSize, CONFIG.maxInputSize];
  return new ort.Tensor('float32', data, dims);
}

/**
 * Convert ImageData to tensor
 */
function imageDataToTensor(imageData) {
  const { width, height, data } = imageData;
  const size = CONFIG.maxInputSize;

  // Resize if needed (simple nearest neighbor)
  const tensor = new Float32Array(3 * size * size);

  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const srcX = Math.floor(x * width / size);
      const srcY = Math.floor(y * height / size);
      const srcIdx = (srcY * width + srcX) * 4;

      const dstIdx = y * size + x;

      // RGB channels, normalized to [0, 1]
      tensor[dstIdx] = data[srcIdx] / 255;                    // R
      tensor[size * size + dstIdx] = data[srcIdx + 1] / 255;  // G
      tensor[2 * size * size + dstIdx] = data[srcIdx + 2] / 255;  // B
    }
  }

  return tensor;
}

/**
 * Server fallback inference
 */
async function serverInference(inputData) {
  try {
    const response = await fetch(CONFIG.serverFallbackUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ input: Array.from(inputData) }),
      signal: AbortSignal.timeout(CONFIG.timeout)
    });

    if (!response.ok) {
      throw new Error(`Server error: ${response.status}`);
    }

    const result = await response.json();

    return {
      success: true,
      data: result.output,
      source: 'server'
    };

  } catch (error) {
    return {
      success: false,
      error: error.message,
      source: 'server'
    };
  }
}

/**
 * Load external script
 */
function loadScript(url) {
  return new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = url;
    script.onload = resolve;
    script.onerror = reject;
    document.head.appendChild(script);
  });
}

/**
 * Get inference stats
 */
function getStats() {
  return {
    initialized: isInitialized,
    usingServer: useServerFallback,
    modelUrl: CONFIG.modelUrl
  };
}

/**
 * Cleanup resources
 */
async function cleanup() {
  if (session) {
    await session.release();
    session = null;
    isInitialized = false;
  }
}

// Web Worker support
if (typeof WorkerGlobalScope !== 'undefined' && self instanceof WorkerGlobalScope) {
  // Running in Worker
  self.onmessage = async (event) => {
    const { type, data, id } = event.data;

    switch (type) {
      case 'init':
        const initResult = await initializeModel();
        self.postMessage({ id, result: initResult });
        break;

      case 'inference':
        const result = await runInference(data);
        self.postMessage({ id, result });
        break;

      case 'stats':
        self.postMessage({ id, result: getStats() });
        break;

      default:
        self.postMessage({ id, error: 'Unknown message type' });
    }
  };
}

// Export for module use
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    initializeModel,
    runInference,
    getStats,
    cleanup
  };
}
