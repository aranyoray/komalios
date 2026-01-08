/**
 * Face Detection Setup Component
 *
 * Guides user to position their face correctly for tracking.
 * Shows camera preview with face detection overlay.
 */

import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  Box,
  Typography,
  Button,
  CircularProgress,
  Fade,
  Alert,
  Paper,
} from '@mui/material';
import { styled } from '@mui/material/styles';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import VideocamIcon from '@mui/icons-material/Videocam';
import VideocamOffIcon from '@mui/icons-material/VideocamOff';
import FaceIcon from '@mui/icons-material/Face';
import { Camera } from '@capacitor/camera';
import { Capacitor } from '@capacitor/core';
import { CameraPreview } from '@capacitor-community/camera-preview';
import { useLanguage } from '../../i18n/LanguageContext';

/**
 * Video preview container with face guide overlay
 */
const VideoContainer = styled(Box)(({ theme }) => ({
  position: 'relative',
  width: '100%',
  maxWidth: '400px',
  aspectRatio: '4/3',
  borderRadius: theme.shape.borderRadius * 2,
  overflow: 'hidden',
  backgroundColor: theme.palette.grey[900],
  margin: '0 auto',
}));

/**
 * Face guide oval overlay
 */
const FaceGuide = styled(Box)(({ theme, detected }) => ({
  position: 'absolute',
  top: '15%',
  left: '25%',
  width: '50%',
  height: '70%',
  border: `3px ${detected ? 'solid' : 'dashed'} ${detected ? theme.palette.success.main : theme.palette.primary.main
    }`,
  borderRadius: '50%',
  pointerEvents: 'none',
  transition: 'all 0.3s ease',
}));

/**
 * Styled video element to hide default play button overlay
 */
const StyledVideo = styled('video')({
  '&::-webkit-media-controls': {
    display: 'none !important',
  },
  '&::-webkit-media-controls-enclosure': {
    display: 'none !important',
  },
  '&::-webkit-media-controls-panel': {
    display: 'none !important',
  },
  '&::-webkit-media-controls-play-button': {
    display: 'none !important',
  },
  '&::-webkit-media-controls-start-playback-button': {
    display: 'none !important',
  },
});

/**
 * Main Face Detection Setup Component
 */
export default function FaceDetectionSetup({
  onComplete,
  onSkip,
  requiredConfidence = 0.7,
  requiredDuration = 2000, // ms of stable detection
}) {
  const { t } = useLanguage();
  const [cameraPermission, setCameraPermission] = useState('pending');
  const [isFaceDetected, setIsFaceDetected] = useState(false);
  const [faceConfidence, setFaceConfidence] = useState(0);
  const [isStable, setIsStable] = useState(false);
  const [isComplete, setIsComplete] = useState(false);
  const [error, setError] = useState(null);
  const [isVideoReady, setIsVideoReady] = useState(false);
  const [useNativePreview, setUseNativePreview] = useState(false);

  // Debug logging
  useEffect(() => {
    console.log('[FaceDetection] 🎬 Component mounted');
    console.log('[FaceDetection] 📋 Config:', { requiredConfidence, requiredDuration });
  }, []);

  const videoRef = useRef(null);
  const streamRef = useRef(null);
  const detectionIntervalRef = useRef(null);
  const stableTimerRef = useRef(null);
  const stableStartRef = useRef(null);

  /**
   * Request camera permission and start video
   * 
   * FLOW EXPLANATION:
   * 1. On NATIVE (Android/iOS):
   *    - Try CameraPreview.start() → Creates NATIVE overlay (NOT HTML video)
   *    - If successful: Return early (getUserMedia NOT called)
   *    - If fails: Fall through to getUserMedia (for HTML video element)
   * 
   * 2. On WEB:
   *    - Skip CameraPreview, go directly to getUserMedia
   *    - Attach stream to <video> element
   * 
   * IMPORTANT: CameraPreview does NOT provide a stream to video tag!
   * It's a native Android/iOS view that overlays on top of the webview.
   */
  const startCamera = useCallback(async () => {
    console.log('[FaceDetection] 📹 Starting camera...');
    try {
      // Check if running on native platform (Android/iOS)
      const isNative = Capacitor.isNativePlatform();
      console.log('[FaceDetection] 🌐 Platform:', isNative ? 'NATIVE (Android/iOS)' : 'WEB');

      if (isNative) {
        // Request camera permission using Capacitor
        try {
          const permission = await Camera.requestPermissions({ permissions: ['camera'] });

          if (permission.camera !== 'granted') {
            console.error('[FaceDetection] ❌ Camera permission denied');
            setCameraPermission('denied');
            setError(t.session.faceSetup.error.permissionDeniedNative);
            return;
          }
          console.log('[FaceDetection] ✅ Camera permission granted');
        } catch (permError) {
          console.error('Permission request error:', permError);
          setCameraPermission('denied');
          setError(t.session.faceSetup.error.permissionDeniedNative);
          return;
        }

        // OPTION 1: Try using Capacitor Camera Preview (NATIVE overlay - NOT HTML video)
        // This creates a native Android/iOS camera view that overlays on top of webview
        // It does NOT attach to <video> element - it's a completely separate native view
        try {
          // Wait a bit for DOM to be ready
          await new Promise(resolve => setTimeout(resolve, 300));

          // Get container dimensions - use the VideoContainer element
          const container = document.getElementById('video-container');
          if (!container) {
            throw new Error('Video container not found');
          }

          const rect = container.getBoundingClientRect();

          // Calculate position relative to window (CameraPreview uses window coordinates)
          const x = Math.round(rect.left);
          const y = Math.round(rect.top);
          const width = Math.round(rect.width);
          const height = Math.round(rect.height);

          console.log('[NATIVE] Starting CameraPreview overlay at:', { x, y, width, height });

          // Start native camera preview overlay
          // This creates a NATIVE camera view - NOT an HTML video element!
          await CameraPreview.start({
            position: 'front', // 'front' or 'rear'
            width: width,
            height: height,
            x: x,
            y: y,
            toBack: false, // false = overlay on top, true = behind webview
            disableAudio: true, // Disable audio for camera preview
          });

          console.log('[NATIVE] ✅ CameraPreview started successfully - using NATIVE overlay');
          console.log('[NATIVE] ⚠️ CameraPreview does NOT provide a stream to <video> tag');
          console.log('[NATIVE] ⚠️ It creates a native Android/iOS view that overlays the webview');
          console.log('[NATIVE] 🚫 Returning early - getUserMedia will NOT be called');

          setUseNativePreview(true);
          setCameraPermission('granted');
          setIsVideoReady(true);

          // IMPORTANT: CameraPreview does NOT provide a MediaStream
          // It's a native overlay, not an HTML video element
          // For face detection, we'll need to use CameraPreview.capture() periodically
          // OR get a separate stream (but this may conflict on some devices)

          // Return early - do NOT call getUserMedia when using CameraPreview
          return;

        } catch (previewErr) {
          console.error('[NATIVE] CameraPreview failed:', previewErr);
          console.warn('[NATIVE] Falling back to getUserMedia (HTML video element)');
          // Fall through to getUserMedia - this will use HTML <video> element
          setUseNativePreview(false);
        }
      }

      // OPTION 2: Use getUserMedia (for WEB or as fallback on NATIVE)
      // This provides a MediaStream that we attach to HTML <video> element
      console.log('[WEB/FALLBACK] 📹 Using getUserMedia() - will attach stream to <video> element');
      console.log('[WEB/FALLBACK] This is called when:');
      console.log('[WEB/FALLBACK]   - Running on web browser (not native), OR');
      console.log('[WEB/FALLBACK]   - CameraPreview failed on native device');

      const stream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: 'user',
          width: { ideal: 640 },
          height: { ideal: 480 },
        },
        audio: false,
      });

      streamRef.current = stream;
      setCameraPermission('granted');
      setUseNativePreview(false);

      console.log('[WEB/FALLBACK] ✅ Got MediaStream from getUserMedia()');
      console.log('[WEB/FALLBACK] 📺 Attaching stream to <video srcObject={stream}>');

      // Set stream to video element if it exists
      // Wait a bit to ensure video element is in DOM
      setTimeout(() => {
        if (videoRef.current) {
          console.log('[WEB/FALLBACK] 🔗 Attaching stream to video element');
          videoRef.current.srcObject = stream;

          // On Android, we need to ensure video can play
          // Set additional attributes for Android WebView compatibility
          videoRef.current.setAttribute('playsinline', 'true');
          videoRef.current.setAttribute('webkit-playsinline', 'true');
          videoRef.current.setAttribute('x5-playsinline', 'true');

          // Try to play immediately with retry logic for Android
          const attemptPlay = async (attempt = 0) => {
            try {
              await videoRef.current.play();
              console.log('Video playing immediately after stream attachment');
              setIsVideoReady(true);
            } catch (err) {
              console.warn(`Play attempt ${attempt + 1} failed:`, err);
              if (attempt < 5) {
                // Retry with increasing delay (Android WebView sometimes needs multiple attempts)
                setTimeout(() => attemptPlay(attempt + 1), (attempt + 1) * 200);
              } else {
                console.error('Failed to play video after multiple attempts');
                // Still mark as ready - video might play on user interaction
                setIsVideoReady(true);
              }
            }
          };

          attemptPlay();
        }
      }, 100);
    } catch (err) {
      console.error('Camera access error:', err);
      setCameraPermission('denied');

      // Provide more helpful error messages
      if (err.name === 'NotAllowedError' || err.name === 'PermissionDeniedError') {
        if (Capacitor.isNativePlatform()) {
          setError(t.session.faceSetup.error.permissionDeniedNative);
        } else {
          setError(t.session.faceSetup.error.permissionDenied);
        }
      } else if (err.name === 'NotFoundError' || err.name === 'DevicesNotFoundError') {
        setError(t.session.faceSetup.error.noCamera);
      } else {
        setError(t.session.faceSetup.error.cameraError);
      }
    }
  }, []);

  /**
   * Complete setup and call onComplete
   */
  const completeSetup = useCallback((confidence) => {
    console.log('[FaceDetection] 🎉 Setup complete!', {
      confidence: (confidence * 100).toFixed(1) + '%',
      timestamp: new Date().toISOString()
    });

    // Stop detection loop
    if (detectionIntervalRef.current) {
      clearInterval(detectionIntervalRef.current);
      console.log('[FaceDetection] 🛑 Stopped detection loop');
    }

    setIsComplete(true);

    // Callback with results
    setTimeout(() => {
      if (onComplete) {
        const result = {
          faceDetected: true,
          confidence,
          timestamp: Date.now(),
          // Keep stream reference for session tracking
          stream: streamRef.current,
        };
        console.log('[FaceDetection] 📤 Calling onComplete with result:', result);
        onComplete(result);
      }
    }, 1000);
  }, [onComplete]);

  /**
   * Start face detection loop
   * 
   * HOW IT WORKS:
   * 1. The video stream is attached to videoRef.current via: videoRef.current.srcObject = stream
   * 2. The video element plays the stream, showing frames continuously
   * 3. We use canvas to capture frames from the video element
   * 4. Canvas.drawImage(videoElement) extracts the current frame
   * 5. We analyze the frame pixels for face detection (or use ML model)
   * 6. Detection runs in a loop (every 200ms) to continuously check for faces
   */
  const startFaceDetection = useCallback(() => {
    // Clear any existing interval
    if (detectionIntervalRef.current) {
      clearInterval(detectionIntervalRef.current);
    }

    // Check if we have a video element with a stream
    if (!videoRef.current || !videoRef.current.srcObject) {
      console.warn('No video stream available for face detection');
      return;
    }

    // Create canvas for frame extraction
    const canvas = document.createElement('canvas');
    canvas.width = 160; // Low res for efficiency
    canvas.height = 120;
    const ctx = canvas.getContext('2d');

    // Face detection loop - runs every 200ms
    detectionIntervalRef.current = setInterval(() => {
      const video = videoRef.current;

      // Check if video is ready and playing
      if (!video || video.readyState < 2 || video.paused) {
        return;
      }

      try {
        // STEP 1: Extract current frame from video stream
        // drawImage copies the current video frame to canvas
        ctx.drawImage(video, 0, 0, canvas.width, canvas.height);

        // STEP 2: Get pixel data from canvas
        const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
        const data = imageData.data; // RGBA pixel array

        // STEP 3: Analyze pixels for face detection
        // This is a simple heuristic - in production, use TensorFlow.js, MediaPipe, etc.
        let totalBrightness = 0;
        let pixelCount = 0;
        let skinTonePixels = 0;

        // Analyze center region (where face is likely to be)
        const centerX = Math.floor(canvas.width / 2);
        const centerY = Math.floor(canvas.height / 2);
        const regionSize = 60;

        for (let y = centerY - regionSize / 2; y < centerY + regionSize / 2; y++) {
          for (let x = centerX - regionSize / 2; x < centerX + regionSize / 2; x++) {
            if (x < 0 || x >= canvas.width || y < 0 || y >= canvas.height) continue;

            const i = (y * canvas.width + x) * 4;
            const r = data[i];     // Red
            const g = data[i + 1]; // Green
            const b = data[i + 2]; // Blue

            const brightness = (r + g + b) / 3;
            totalBrightness += brightness;
            pixelCount++;

            // Rough skin tone detection
            if (r > 95 && g > 40 && b > 20 &&
              r > g && r > b &&
              Math.abs(r - g) > 15) {
              skinTonePixels++;
            }
          }
        }

        const avgBrightness = totalBrightness / pixelCount;
        const skinRatio = skinTonePixels / pixelCount;

        // Heuristic: face likely present if moderate brightness + skin tones
        const brightnessOk = avgBrightness > 50 && avgBrightness < 220;
        const skinToneOk = skinRatio > 0.15;

        const detected = brightnessOk && skinToneOk;
        const confidence = detected ? Math.min(0.9, skinRatio * 2) : 0;

        // STEP 4: Update state with detection results
        const prevDetected = isFaceDetected;
        const prevConfidence = faceConfidence;
        setIsFaceDetected(detected);
        setFaceConfidence(confidence);

        // Log detection changes
        if (detected !== prevDetected || Math.abs(confidence - prevConfidence) > 0.1) {
          console.log('[FaceDetection] 👤 Face detection:', {
            detected,
            confidence: (confidence * 100).toFixed(1) + '%',
            required: (requiredConfidence * 100).toFixed(1) + '%',
            stable: detected && confidence >= requiredConfidence
          });
        }

        // STEP 5: Check if face is stable for required duration
        if (detected && confidence >= requiredConfidence) {
          if (!stableStartRef.current) {
            stableStartRef.current = Date.now();
            console.log('[FaceDetection] ⏱️ Starting stability timer...');
          } else {
            const elapsed = Date.now() - stableStartRef.current;
            const remaining = requiredDuration - elapsed;
            if (remaining > 0 && remaining < 500) {
              // Log every 500ms when close to completion
              console.log('[FaceDetection] ⏱️ Stability:', {
                elapsed: (elapsed / 1000).toFixed(1) + 's',
                required: (requiredDuration / 1000).toFixed(1) + 's',
                remaining: (remaining / 1000).toFixed(1) + 's'
              });
            }
            if (Date.now() - stableStartRef.current >= requiredDuration) {
              console.log('[FaceDetection] ✅ Face stable! Completing setup...');
              setIsStable(true);
              completeSetup(confidence);
            }
          }
        } else {
          if (stableStartRef.current) {
            console.log('[FaceDetection] ⚠️ Face lost stability, resetting timer');
          }
          stableStartRef.current = null;
          setIsStable(false);
        }
      } catch (err) {
        console.error('Face detection error:', err);
      }
    }, 200); // Run every 200ms
  }, [requiredConfidence, requiredDuration, completeSetup]);

  /**
   * Stop camera and cleanup
   */
  const stopCamera = useCallback(async () => {
    if (detectionIntervalRef.current) {
      clearInterval(detectionIntervalRef.current);
    }

    // Stop native camera preview if active
    if (useNativePreview) {
      try {
        await CameraPreview.stop();
        setUseNativePreview(false);
      } catch (err) {
        console.error('Error stopping camera preview:', err);
      }
    }

    if (streamRef.current) {
      streamRef.current.getTracks().forEach(track => track.stop());
      streamRef.current = null;
    }

    if (videoRef.current) {
      videoRef.current.srcObject = null;
    }

    setIsVideoReady(false);
  }, [useNativePreview]);

  /**
   * Initialize on mount
   */
  useEffect(() => {
    console.log('[FaceDetection] 🚀 Initializing face detection setup...');
    startCamera();

    return () => {
      stopCamera();
    };
  }, [startCamera, stopCamera]);

  /**
   * Handle video stream attachment when stream is ready (only for web/non-native preview)
   */
  useEffect(() => {
    if (useNativePreview) {
      return; // Skip video element handling when using native preview
    }

    const video = videoRef.current;
    const stream = streamRef.current;

    if (stream && video && cameraPermission === 'granted') {
      // Set stream source
      if (video.srcObject !== stream) {
        console.log('Setting video srcObject');
        video.srcObject = stream;
      }

      // Ensure video plays - try multiple times with different strategies
      const playVideo = async (retryCount = 0) => {
        try {
          // Wait a bit for video element to be ready
          if (video.readyState === 0) {
            await new Promise(resolve => setTimeout(resolve, 100));
          }

          if (video.paused) {
            await video.play();
            console.log('Video started playing');
            setIsVideoReady(true);
          } else {
            console.log('Video already playing');
            setIsVideoReady(true);
          }
        } catch (err) {
          console.error(`Video play error (attempt ${retryCount + 1}):`, err);

          // Retry up to 3 times with increasing delays
          if (retryCount < 3) {
            setTimeout(() => {
              playVideo(retryCount + 1);
            }, (retryCount + 1) * 300);
          } else {
            console.error('Failed to play video after multiple attempts');
            // Still set as ready to show the video (user can click play if needed)
            setIsVideoReady(true);
          }
        }
      };

      // Wait for metadata then play
      const handleLoadedMetadata = () => {
        console.log('Video metadata loaded, readyState:', video.readyState);
        playVideo();
      };

      const handleCanPlay = () => {
        console.log('Video can play, paused:', video.paused);
        if (video.paused) {
          playVideo();
        } else {
          setIsVideoReady(true);
        }
      };

      const handlePlay = () => {
        console.log('Video play event');
        setIsVideoReady(true);
      };

      // Add event listeners
      video.addEventListener('loadedmetadata', handleLoadedMetadata);
      video.addEventListener('canplay', handleCanPlay);
      video.addEventListener('play', handlePlay);

      // If already loaded, play immediately
      if (video.readyState >= 2) {
        playVideo();
      } else {
        // Also try to play after a short delay in case events don't fire
        setTimeout(() => {
          if (video && video.srcObject && video.paused) {
            playVideo();
          }
        }, 500);
      }

      return () => {
        video.removeEventListener('loadedmetadata', handleLoadedMetadata);
        video.removeEventListener('canplay', handleCanPlay);
        video.removeEventListener('play', handlePlay);
      };
    }
  }, [cameraPermission, useNativePreview]);

  /**
   * Start face detection when video is ready
   */
  useEffect(() => {
    if (isVideoReady && cameraPermission === 'granted' && !detectionIntervalRef.current) {
      startFaceDetection();
    }
  }, [isVideoReady, cameraPermission, startFaceDetection]);

  /**
   * Render camera permission denied
   */
  if (cameraPermission === 'denied') {
    return (
      <Fade in>
        <Box
          sx={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            height: '100%',
            minHeight: '400px',
            p: 4,
            textAlign: 'center',
          }}
        >
          <VideocamOffIcon sx={{ fontSize: 60, color: 'error.main', mb: 2 }} />

          <Typography variant="h5" gutterBottom sx={{ color: '#111827' }}>
            {t.session.faceSetup.title}
          </Typography>

          <Alert severity="error" sx={{ mb: 3, maxWidth: 400 }}>
            {error || t.session.faceSetup.error.permissionDenied}
          </Alert>

          <Box sx={{ display: 'flex', gap: 2 }}>
            <Button variant="contained" onClick={startCamera}>
              {t.common.tryAgain}
            </Button>
            {onSkip && (
              <Button variant="text" onClick={onSkip}>
                {t.session.faceSetup.skip}
              </Button>
            )}
          </Box>
        </Box>
      </Fade>
    );
  }

  /**
   * Render loading state
   */
  if (cameraPermission === 'pending') {
    return (
      <Box
        sx={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          height: '100%',
          minHeight: '400px',
        }}
      >
        <CircularProgress size={48} sx={{ mb: 2 }} />
        <Typography sx={{ color: '#6B7280' }}>
          {t.session.faceSetup.detecting}
        </Typography>
      </Box>
    );
  }

  /**
   * Render setup complete
   */
  if (isComplete) {
    return (
      <Fade in>
        <Box
          sx={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            height: '100%',
            minHeight: '400px',
            p: 4,
            textAlign: 'center',
          }}
        >
          <CheckCircleIcon sx={{ fontSize: 80, color: 'success.main', mb: 2 }} />

          <Typography variant="h4" gutterBottom sx={{ fontWeight: 600, color: '#111827' }}>
            {t.session.faceSetup.complete}
          </Typography>

          <Typography variant="body1" sx={{ color: '#6B7280' }}>
            {t.session.faceSetup.detected}
          </Typography>
        </Box>
      </Fade>
    );
  }

  /**
   * Render camera preview with face detection
   */
  return (
    <Fade in>
      <Box
        sx={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          p: 4,
        }}
      >
        <Typography variant="h5" gutterBottom sx={{ fontWeight: 600, color: '#111827' }}>
          {t.session.faceSetup.positionFace}
        </Typography>

        <Typography variant="body2" sx={{ mb: 3, color: '#6B7280' }}>
          {t.session.faceSetup.instructions}
        </Typography>

        {/* Video preview */}
        <VideoContainer id="video-container">
          {!isVideoReady && cameraPermission === 'granted' && (
            <Box
              sx={{
                position: 'absolute',
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                bgcolor: 'grey.900',
                zIndex: 1,
              }}
            >
              <CircularProgress sx={{ color: 'white' }} />
            </Box>
          )}
          {/* 
            When using native preview: CameraPreview overlays a native camera view
            When using web preview: Show <video> element with getUserMedia stream
          */}
          {useNativePreview ? (
            // Native preview is active - CameraPreview overlays the camera view
            // We still need a hidden video element for face detection if we got a stream
            <video
              ref={videoRef}
              autoPlay
              playsInline
              muted
              style={{
                width: '100%',
                height: '100%',
                objectFit: 'cover',
                display: 'none', // Hidden - native preview shows the camera
              }}
            />
          ) : (
            // Web preview - use <video> element with getUserMedia stream
            <StyledVideo
              ref={videoRef}
              autoPlay
              playsInline
              muted
              controls={false}
              webkit-playsinline="true"
              x5-playsinline="true"
              style={{
                width: '100%',
                height: '100%',
                objectFit: 'cover',
                transform: 'scaleX(-1)', // Mirror
                backgroundColor: '#000',
                display: 'block', // Always show - don't hide it
                opacity: isVideoReady ? 1 : 0.3, // Fade in when ready
                transition: 'opacity 0.3s ease',
                pointerEvents: 'none', // Prevent click-to-play overlay
              }}
              onClick={(e) => {
                // On Android, user click can trigger play
                if (videoRef.current && videoRef.current.paused) {
                  videoRef.current.play().catch(err => {
                    console.error('Play on click failed:', err);
                  });
                }
              }}
              onLoadedMetadata={() => {
                console.log('Video metadata loaded, readyState:', videoRef.current?.readyState);
                // Force play when metadata is loaded
                if (videoRef.current && videoRef.current.paused) {
                  videoRef.current.play()
                    .then(() => {
                      console.log('Video playing from onLoadedMetadata');
                      setIsVideoReady(true);
                    })
                    .catch(err => {
                      console.error('Play on loadedMetadata failed:', err);
                    });
                }
              }}
              onCanPlay={() => {
                console.log('Video can play, paused:', videoRef.current?.paused);
                // Force play when video can play
                if (videoRef.current && videoRef.current.paused) {
                  videoRef.current.play()
                    .then(() => {
                      console.log('Video playing from onCanPlay');
                      setIsVideoReady(true);
                    })
                    .catch(err => {
                      console.error('Play on canPlay failed:', err);
                    });
                } else if (videoRef.current && !videoRef.current.paused) {
                  setIsVideoReady(true);
                }
              }}
              onPlaying={() => {
                console.log('Video is playing');
                setIsVideoReady(true);
              }}
              onPlay={() => {
                console.log('Video play event fired');
                setIsVideoReady(true);
              }}
              onError={(e) => {
                console.error('Video error:', e, videoRef.current?.error);
                setError('Failed to load camera video. Please try again.');
              }}
            />
          )}

          {/* Face guide overlay */}
          <FaceGuide detected={isFaceDetected && faceConfidence >= requiredConfidence} />

          {/* Detection indicator */}
          <Box
            sx={{
              position: 'absolute',
              bottom: 16,
              left: '50%',
              transform: 'translateX(-50%)',
              display: 'flex',
              alignItems: 'center',
              gap: 1,
              bgcolor: isFaceDetected ? 'success.main' : 'warning.main',
              color: 'white',
              px: 2,
              py: 0.5,
              borderRadius: 2,
            }}
          >
            <FaceIcon fontSize="small" />
            <Typography variant="body2">
              {isFaceDetected
                ? `${t.session.faceSetup.detected} (${Math.round(faceConfidence * 100)}%)`
                : t.session.faceSetup.detecting}
            </Typography>
          </Box>
        </VideoContainer>

        {/* Status */}
        <Paper
          elevation={0}
          sx={{
            mt: 3,
            p: 2,
            bgcolor: isStable ? 'success.light' : 'grey.100',
            borderRadius: 2,
            textAlign: 'center',
            minWidth: 300,
          }}
        >
          {isStable ? (
            <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 1 }}>
              <CheckCircleIcon color="success" />
              <Typography color="success.dark">{t.session.faceSetup.keepStill}</Typography>
            </Box>
          ) : (
            <Typography color="text.secondary">
              {isFaceDetected
                ? t.session.faceSetup.keepStill
                : t.session.faceSetup.positionFace}
            </Typography>
          )}
        </Paper>

        {/* Skip button */}
        {onSkip && (
          <Button
            variant="text"
            onClick={onSkip}
            sx={{ mt: 2 }}
          >
            {t.session.faceSetup.skip}
          </Button>
        )}
      </Box>
    </Fade>
  );
}

/**
 * Compact face status indicator
 */
export function FaceStatusIndicator({ detected, confidence }) {
  return (
    <Box
      sx={{
        display: 'flex',
        alignItems: 'center',
        gap: 0.5,
        px: 1,
        py: 0.5,
        borderRadius: 1,
        bgcolor: detected ? 'success.light' : 'warning.light',
      }}
    >
      <FaceIcon sx={{ fontSize: 16, color: detected ? 'success.main' : 'warning.main' }} />
      <Typography variant="caption">
        {detected ? `${Math.round(confidence * 100)}%` : 'No face'}
      </Typography>
    </Box>
  );
}
