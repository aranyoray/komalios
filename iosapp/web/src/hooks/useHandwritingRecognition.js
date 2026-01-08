/**
 * Handwriting recognition for digits (0-9)
 * Optimized for battery efficiency on mobile devices
 * Uses lightweight MNIST-style model
 */

import { useState, useCallback, useRef } from 'react';
import { useMLWorker } from './useMLWorker';

// Placeholder for a lightweight digit recognition model
// In production, you'd load a quantized MNIST model (~50KB)
const DIGIT_MODEL_URL = '/models/digit-recognition.onnx';

export const useHandwritingRecognition = () => {
  const [isReady, setIsReady] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [lastPrediction, setLastPrediction] = useState(null);

  const mlWorker = useMLWorker();
  const modelLoadedRef = useRef(false);

  /**
   * Load the digit recognition model (lazy loaded)
   */
  const loadModel = useCallback(async () => {
    if (modelLoadedRef.current || isLoading) return true;

    setIsLoading(true);

    try {
      // For now, we'll use a simple heuristic approach
      // In production, uncomment below to load actual ONNX model
      /*
      if (mlWorker.isReady) {
        await mlWorker.loadModel('digit-recognition', DIGIT_MODEL_URL);
        modelLoadedRef.current = true;
        setIsReady(true);
      }
      */

      // Using heuristic for demo/testing
      modelLoadedRef.current = true;
      setIsReady(true);

      console.log('[HandwritingRecognition] Model loaded');
      return true;
    } catch (error) {
      console.error('[HandwritingRecognition] Failed to load model:', error);
      return false;
    } finally {
      setIsLoading(false);
    }
  }, [isLoading, mlWorker]);

  /**
   * Preprocess canvas image for digit recognition
   */
  const preprocessCanvas = useCallback((canvas) => {
    // Create a 28x28 grayscale image (MNIST format)
    const targetSize = 28;
    const tempCanvas = document.createElement('canvas');
    tempCanvas.width = targetSize;
    tempCanvas.height = targetSize;
    const ctx = tempCanvas.getContext('2d');

    // Fill with white background
    ctx.fillStyle = '#fff';
    ctx.fillRect(0, 0, targetSize, targetSize);

    // Draw the canvas content centered and scaled
    const sourceWidth = canvas.width;
    const sourceHeight = canvas.height;
    const scale = Math.min(targetSize / sourceWidth, targetSize / sourceHeight) * 0.8;
    const scaledWidth = sourceWidth * scale;
    const scaledHeight = sourceHeight * scale;
    const offsetX = (targetSize - scaledWidth) / 2;
    const offsetY = (targetSize - scaledHeight) / 2;

    ctx.drawImage(canvas, offsetX, offsetY, scaledWidth, scaledHeight);

    // Get image data and convert to grayscale
    const imageData = ctx.getImageData(0, 0, targetSize, targetSize);
    const data = imageData.data;
    const grayscale = new Float32Array(targetSize * targetSize);

    for (let i = 0; i < targetSize * targetSize; i++) {
      const idx = i * 4;
      // Convert to grayscale and invert (MNIST expects white on black)
      const gray = (data[idx] + data[idx + 1] + data[idx + 2]) / 3;
      grayscale[i] = (255 - gray) / 255.0; // Normalize to [0, 1]
    }

    return {
      data: grayscale,
      dims: [1, 1, targetSize, targetSize],
      type: 'float32'
    };
  }, []);

  /**
   * Simple heuristic digit recognition based on image features
   * This is a fallback when ML model is not available
   * NOT accurate but battery-efficient for demo purposes
   */
  const recognizeHeuristic = useCallback((canvas) => {
    const ctx = canvas.getContext('2d');
    const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
    const data = imageData.data;

    let totalInk = 0;
    let minX = canvas.width;
    let maxX = 0;
    let minY = canvas.height;
    let maxY = 0;
    let inkPixels = 0;

    // Find bounding box and count ink pixels
    for (let y = 0; y < canvas.height; y++) {
      for (let x = 0; x < canvas.width; x++) {
        const i = (y * canvas.width + x) * 4;
        const brightness = (data[i] + data[i + 1] + data[i + 2]) / 3;

        if (brightness < 200) { // Consider dark pixels as ink
          inkPixels++;
          totalInk += (255 - brightness);
          minX = Math.min(minX, x);
          maxX = Math.max(maxX, x);
          minY = Math.min(minY, y);
          maxY = Math.max(maxY, y);
        }
      }
    }

    const width = maxX - minX;
    const height = maxY - minY;
    const aspectRatio = width / Math.max(1, height);

    // Very simple heuristic based on shape features
    // This is NOT accurate - just a placeholder
    let predictions = [];

    if (inkPixels < 50) {
      // Too little ink, likely 1 or 7
      predictions = [
        { digit: 1, confidence: 0.4 },
        { digit: 7, confidence: 0.3 }
      ];
    } else if (aspectRatio > 1.5) {
      // Wide shape - likely 0, 8
      predictions = [
        { digit: 0, confidence: 0.4 },
        { digit: 8, confidence: 0.3 }
      ];
    } else {
      // Random guess - this is where ML would help!
      const randomDigit = Math.floor(Math.random() * 10);
      predictions = [
        { digit: randomDigit, confidence: 0.5 }
      ];
    }

    return {
      predictions,
      bestDigit: predictions[0].digit,
      confidence: predictions[0].confidence,
      isHeuristic: true
    };
  }, []);

  /**
   * Recognize digit from canvas
   */
  const recognizeDigit = useCallback(async (canvas) => {
    if (!canvas) {
      throw new Error('Canvas is required');
    }

    // Ensure model is loaded
    await loadModel();

    try {
      // For now, use heuristic approach
      // In production with ONNX model, use the commented code below
      const result = recognizeHeuristic(canvas);

      setLastPrediction(result);
      return result;

      /* With actual ONNX model:
      const inputTensor = preprocessCanvas(canvas);

      const { outputs, inferenceTime } = await mlWorker.runInference(
        'digit-recognition',
        { input: inputTensor }
      );

      // Parse output (assuming softmax probabilities for 10 digits)
      const probabilities = outputs.output.data;
      const predictions = probabilities
        .map((prob, digit) => ({ digit, confidence: prob }))
        .sort((a, b) => b.confidence - a.confidence);

      const result = {
        predictions: predictions.slice(0, 3), // Top 3
        bestDigit: predictions[0].digit,
        confidence: predictions[0].confidence,
        inferenceTime,
        isHeuristic: false
      };

      setLastPrediction(result);
      return result;
      */

    } catch (error) {
      console.error('[HandwritingRecognition] Recognition failed:', error);
      throw error;
    }
  }, [loadModel, recognizeHeuristic, mlWorker]);

  /**
   * Recognize multi-digit number (e.g., "42")
   * Segments the canvas and recognizes each digit
   */
  const recognizeNumber = useCallback(async (canvas) => {
    // For simplicity, assume single digit for now
    // In production, you'd segment the canvas into multiple digit regions
    const result = await recognizeDigit(canvas);

    return {
      number: result.bestDigit,
      confidence: result.confidence,
      digits: [result]
    };
  }, [recognizeDigit]);

  return {
    isReady,
    isLoading,
    lastPrediction,
    loadModel,
    recognizeDigit,
    recognizeNumber
  };
};
