/**
 * Web Worker for ML inference
 * Runs models in background thread to avoid blocking UI
 * Optimized for battery efficiency
 */

// Import ONNX Runtime (will be bundled by Vite)
import * as ort from 'onnxruntime-web';

// Configure ONNX for worker environment
ort.env.wasm.numThreads = 1;
ort.env.wasm.simd = true;
ort.env.wasm.wasmPaths = 'https://cdn.jsdelivr.net/npm/onnxruntime-web@1.20.0/dist/';

const sessions = new Map();
let initialized = false;

/**
 * Initialize the worker
 */
async function init() {
  if (initialized) return { success: true };

  try {
    initialized = true;
    return { success: true, message: 'Worker initialized' };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

/**
 * Load a model in the worker
 */
async function loadModel(modelName, modelUrl) {
  try {
    if (sessions.has(modelName)) {
      return { success: true, cached: true };
    }

    const sessionOptions = {
      executionProviders: ['wasm'], // Use WASM in worker
      graphOptimizationLevel: 'all',
      executionMode: 'sequential'
    };

    const session = await ort.InferenceSession.create(modelUrl, sessionOptions);
    sessions.set(modelName, session);

    return {
      success: true,
      cached: false,
      inputNames: session.inputNames,
      outputNames: session.outputNames
    };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

/**
 * Run inference
 */
async function runInference(modelName, inputs) {
  try {
    const session = sessions.get(modelName);
    if (!session) {
      throw new Error(`Model ${modelName} not loaded`);
    }

    // Convert inputs to ONNX tensors
    const tensorInputs = {};
    for (const [name, data] of Object.entries(inputs)) {
      tensorInputs[name] = new ort.Tensor(
        data.type || 'float32',
        data.data,
        data.dims
      );
    }

    const startTime = performance.now();
    const results = await session.run(tensorInputs);
    const inferenceTime = performance.now() - startTime;

    // Convert results to transferable format
    const outputs = {};
    for (const [name, tensor] of Object.entries(results)) {
      outputs[name] = {
        data: Array.from(tensor.data),
        dims: tensor.dims,
        type: tensor.type
      };
    }

    return {
      success: true,
      outputs,
      inferenceTime
    };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

/**
 * Release a model
 */
function releaseModel(modelName) {
  if (sessions.has(modelName)) {
    sessions.delete(modelName);
    return { success: true };
  }
  return { success: false, error: 'Model not found' };
}

/**
 * Message handler
 */
self.onmessage = async (event) => {
  const { type, id, ...payload } = event.data;

  let result;

  try {
    switch (type) {
      case 'init':
        result = await init();
        break;

      case 'loadModel':
        result = await loadModel(payload.modelName, payload.modelUrl);
        break;

      case 'runInference':
        result = await runInference(payload.modelName, payload.inputs);
        break;

      case 'releaseModel':
        result = releaseModel(payload.modelName);
        break;

      case 'releaseAll':
        sessions.clear();
        result = { success: true };
        break;

      default:
        result = { success: false, error: `Unknown message type: ${type}` };
    }

    // Send result back to main thread
    self.postMessage({ type, id, ...result });
  } catch (error) {
    self.postMessage({
      type,
      id,
      success: false,
      error: error.message
    });
  }
};
