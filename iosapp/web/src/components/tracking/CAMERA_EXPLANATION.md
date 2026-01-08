# Camera Preview vs getUserMedia - How They Work

## Key Concept: CameraPreview does NOT send stream to HTML video tag!

### Method 1: CameraPreview (Native Overlay)
```
┌─────────────────────────────────────┐
│  Native Android/iOS Layer           │
│  ┌───────────────────────────────┐  │
│  │ CameraPreview.start()         │  │
│  │ → Creates NATIVE camera view   │  │
│  │ → Overlays on top of WebView  │  │
│  │ → NOT an HTML element!        │  │
│  └───────────────────────────────┘  │
├─────────────────────────────────────┤
│  WebView (HTML/CSS/JS)              │
│  ┌───────────────────────────────┐  │
│  │ <div id="video-container">    │  │
│  │   (CameraPreview positioned   │  │
│  │    over this div)             │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

**What happens:**
- `CameraPreview.start({ x, y, width, height })` creates a native Android/iOS camera view
- This native view is positioned at coordinates (x, y) with size (width, height)
- It overlays on top of the WebView - it's NOT an HTML element
- **NO stream is sent to <video> tag** - there's no stream at all!
- The camera feed appears because the native view is positioned over your HTML container

### Method 2: getUserMedia (HTML Video Element)
```
┌─────────────────────────────────────┐
│  WebView (HTML/CSS/JS)              │
│  ┌───────────────────────────────┐  │
│  │ navigator.mediaDevices        │  │
│  │   .getUserMedia()             │  │
│  │ → Returns: MediaStream        │  │
│  └───────────────────────────────┘  │
│           ↓                          │
│  ┌───────────────────────────────┐  │
│  │ <video srcObject={stream}>    │  │
│  │ → Stream attached to element  │  │
│  │ → HTML video plays stream     │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

**What happens:**
- `getUserMedia()` returns a `MediaStream` object
- We attach it to video element: `video.srcObject = stream`
- The HTML `<video>` element plays the stream
- This is a standard web API

## Code Flow

```javascript
if (isNative) {
  // Try CameraPreview first
  try {
    await CameraPreview.start({...});
    setUseNativePreview(true);
    return; // ← EXIT HERE - getUserMedia NOT called
  } catch {
    // CameraPreview failed, fall through
  }
}

// Only reached if:
// 1. Not native (web browser)
// 2. CameraPreview failed on native
const stream = await getUserMedia({...});
video.srcObject = stream; // ← Attach to HTML video
```

## Why Both Aren't Called

The code uses `return` statement when CameraPreview succeeds:
- ✅ CameraPreview succeeds → `return` → getUserMedia NOT called
- ❌ CameraPreview fails → falls through → getUserMedia IS called
- 🌐 Web browser → skips CameraPreview → getUserMedia IS called

## For Face Detection

**With CameraPreview:**
- No MediaStream available
- Must use `CameraPreview.capture()` to get frames
- Or get separate stream (may conflict)

**With getUserMedia:**
- MediaStream available
- Can use `canvas.drawImage(videoElement)` to get frames
- Standard web approach

