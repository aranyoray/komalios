# Client-Side ML for GANIT Web App

## Overview

This React app includes **battery-efficient, client-side machine learning** optimized for mobile devices, especially iPhones. All ML processing happens on the user's device for privacy and low latency.

## Features

### 🎯 Implemented ML Features

1. **Face Detection for Engagement Tracking**
   - Uses browser's native Face Detection API when available (iOS 16+)
   - Fallback to lightweight heuristic detection
   - Battery-aware throttling (2-10 FPS based on battery level)
   - Real-time engagement scoring

2. **Handwriting Recognition**
   - Touch-optimized canvas for drawing answers
   - Digit recognition (0-9) for math problems
   - Lightweight preprocessing
   - Can be extended with ONNX models

3. **Battery Management**
   - Automatic inference throttling based on battery level
   - Reduced FPS when battery is low
   - Model precision adjustment (fp32 → fp16 → int8)
   - Heavy operations disabled below 15% battery

4. **Model Caching**
   - Memory cache for loaded models
   - IndexedDB persistence for offline use
   - Lazy loading - models load only when needed
   - Idle-time preloading

## Architecture

```
src/
├── ml/
│   └── onnxInference.js          # ONNX Runtime manager
├── workers/
│   └── ml.worker.js              # Web Worker for background ML
├── utils/ml/
│   ├── batteryManager.js         # Battery-aware throttling
│   ├── modelCache.js             # Model loading & caching
│   └── throttle.js               # Inference rate limiting
├── hooks/
│   ├── useMLWorker.js            # React hook for ML Worker
│   ├── useFaceDetection.js       # Face detection hook
│   ├── useHandwritingRecognition.js  # Digit recognition
│   └── useEngagementTrackingML.js    # Enhanced engagement tracking
└── components/common/
    └── HandwritingCanvas.jsx     # Touch-optimized drawing canvas
```

## Battery Optimizations

### Adaptive Throttling
- **Charging or >50% battery**: 100ms (10 FPS)
- **20-50% battery**: 200ms (5 FPS)
- **<20% battery**: 500ms (2 FPS)
- **<15% battery**: Heavy ML disabled

### Model Precision
- **High battery**: FP32 (full precision)
- **Medium battery**: FP16 (2x faster, half memory)
- **Low battery**: INT8 (4x faster, quantized)

### Web Workers
- All ML runs in background threads
- UI remains responsive during inference
- Automatic result transfer

## Usage

### 1. Face Detection & Engagement Tracking

```javascript
import { useEngagementTrackingML } from './hooks/useEngagementTrackingML';

function Practice() {
  const {
    isTracking,
    confidence,
    metrics,
    startTracking,
    stopTracking
  } = useEngagementTrackingML();

  useEffect(() => {
    startTracking(); // Starts webcam + face detection
    return () => stopTracking();
  }, []);

  return (
    <div>
      <p>Engagement: {(confidence * 100).toFixed(0)}%</p>
      <p>Face detected: {metrics.faceDetected ? 'Yes' : 'No'}</p>
    </div>
  );
}
```

### 2. Handwriting Recognition

```javascript
import HandwritingCanvas from './components/common/HandwritingCanvas';
import { useHandwritingRecognition } from './hooks/useHandwritingRecognition';

function MathProblem() {
  const { recognizeDigit, isReady } = useHandwritingRecognition();

  const handleComplete = async ({ canvas }) => {
    const result = await recognizeDigit(canvas);
    console.log('Recognized digit:', result.bestDigit);
    console.log('Confidence:', result.confidence);
  };

  return (
    <HandwritingCanvas
      onComplete={handleComplete}
      width={280}
      height={140}
    />
  );
}
```

### 3. Custom ML Models (ONNX)

```javascript
import { useMLWorker } from './hooks/useMLWorker';

function CustomML() {
  const { loadModel, runInference, isReady } = useMLWorker();

  useEffect(() => {
    if (isReady) {
      loadModel('my-model', '/models/my-model.onnx');
    }
  }, [isReady]);

  const predict = async (imageData) => {
    const input = preprocessImage(imageData);
    const result = await runInference('my-model', { input });
    return result.outputs;
  };
}
```

## iPhone Compatibility

### ✅ Supported
- **iOS Safari 14+**: WASM, WebGL acceleration
- **iOS Safari 16+**: Native Face Detection API
- **Touch events**: Fully optimized for touch input
- **High DPI**: Retina display support
- **Offline**: Models cached in IndexedDB

### ⚠️ Limitations
- Battery API not available on iOS < 16 (graceful fallback)
- WebGL may have memory limits on older iPhones
- Model size should be < 50MB for best performance

## Performance Tips

### For Best Battery Life
1. Use native Face Detection API (iOS 16+) when available
2. Keep model sizes small (< 10MB preferred)
3. Use quantized models (INT8) when possible
4. Limit inference to 5-10 FPS max
5. Run inference only when needed (not continuously)

### For Best Accuracy
1. Use FP32 models when battery allows
2. Increase inference rate when charging
3. Use larger models (up to 50MB)
4. Combine multiple signals (face + cursor + touch)

## Adding New Models

1. **Convert to ONNX format** (if not already)
   ```bash
   python -m tf2onnx.convert --saved-model mymodel --output model.onnx
   ```

2. **Quantize for mobile** (optional but recommended)
   ```bash
   python -m onnxruntime.quantization.quantize_dynamic model.onnx model_int8.onnx
   ```

3. **Load in your component**
   ```javascript
   const { loadModel } = useMLWorker();
   await loadModel('my-model', '/models/model_int8.onnx');
   ```

## Browser Support

| Feature | Chrome | Safari iOS | Safari Desktop | Firefox |
|---------|--------|------------|----------------|---------|
| ONNX Runtime | ✅ | ✅ | ✅ | ✅ |
| Web Workers | ✅ | ✅ | ✅ | ✅ |
| WebGL | ✅ | ✅ (14+) | ✅ | ✅ |
| Face Detection API | ❌ | ✅ (16+) | ❌ | ❌ |
| Battery API | ✅ | ❌ | ✅ | ✅ |
| IndexedDB | ✅ | ✅ | ✅ | ✅ |

## Next Steps

### To Deploy with Real Models:

1. **Add ONNX models to `public/models/`**
   - `digit-recognition.onnx` - Handwriting recognition
   - `face-landmarks.onnx` - Enhanced face detection (optional)

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Update model URLs** in hooks to point to your models

4. **Test on real devices** - especially iPhones with different battery levels

## Security & Privacy

- ✅ All processing happens **client-side**
- ✅ No data sent to servers
- ✅ Webcam streams stay local
- ✅ Models cached locally
- ✅ Works completely offline after first load

## Troubleshooting

### Models not loading?
- Check CORS headers for model files
- Verify WASM files are accessible
- Check browser console for errors

### Slow inference?
- Reduce model size or use quantized versions
- Lower inference rate (increase throttle)
- Use WASM instead of WebGL on older devices

### Face detection not working?
- Check webcam permissions
- Try heuristic fallback mode
- Verify browser compatibility

## License

MIT
