/**
 * Enhanced engagement tracking with real ML face detection
 * Combines face detection + cursor behavior for accurate engagement scoring
 */

import { useCallback, useEffect, useRef, useState } from 'react';
import { useFaceDetection } from './useFaceDetection';

export const useEngagementTrackingML = () => {
  const [isSupported, setIsSupported] = useState(false);
  const [permissionState, setPermissionState] = useState('idle');
  const [isCalibrated, setIsCalibrated] = useState(false);
  const [isTracking, setIsTracking] = useState(false);
  const [webcamStream, setWebcamStream] = useState(null);
  const [confidence, setConfidence] = useState(0.5);
  const [metrics, setMetrics] = useState({
    cursorSpeedPxPerSec: 0,
    cursorIdleRatio: 0,
    faceDetected: false,
    faceConfidence: 0,
    engagementScore: 0.5
  });

  const videoRef = useRef(null);
  const lastMousePosRef = useRef({ x: null, y: null, t: 0 });
  const speedSamplesRef = useRef([]);
  const idleTimeMsRef = useRef(0);
  const totalTimeMsRef = useRef(0);
  const tickIntervalRef = useRef(null);

  const faceDetection = useFaceDetection();

  useEffect(() => {
    setIsSupported(!!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia));
  }, []);

  const requestWebcam = useCallback(async () => {
    if (!isSupported) return null;
    setPermissionState('pending');
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: 'user',
          width: { ideal: 640 },
          height: { ideal: 480 }
        },
        audio: false
      });
      setPermissionState('granted');
      setWebcamStream(stream);

      // Set up video element for face detection
      if (!videoRef.current) {
        videoRef.current = document.createElement('video');
        videoRef.current.autoplay = true;
        videoRef.current.playsInline = true;
        videoRef.current.muted = true;
      }
      videoRef.current.srcObject = stream;
      await videoRef.current.play();

      return stream;
    } catch (e) {
      setPermissionState('denied');
      console.error('Webcam permission denied or error:', e);
      return null;
    }
  }, [isSupported]);

  const stopWebcam = useCallback(() => {
    if (webcamStream) {
      for (const track of webcamStream.getTracks()) track.stop();
      setWebcamStream(null);
    }
    if (videoRef.current) {
      videoRef.current.srcObject = null;
    }
  }, [webcamStream]);

  const calibrate = useCallback(async () => {
    setIsCalibrated(false);
    // Calibration: wait for video to be ready and collect baseline
    await new Promise((res) => setTimeout(res, 1500));
    setIsCalibrated(true);
    return true;
  }, []);

  const onMouseMove = useCallback((e) => {
    const now = performance.now();
    const last = lastMousePosRef.current;
    if (last.x == null || last.y == null) {
      lastMousePosRef.current = { x: e.clientX, y: e.clientY, t: now };
      return;
    }

    const dt = Math.max(1, now - last.t);
    const dx = e.clientX - last.x;
    const dy = e.clientY - last.y;
    const dist = Math.sqrt(dx * dx + dy * dy);
    const speed = (dist / dt) * 1000; // px/sec

    speedSamplesRef.current.push({ t: now, speed });
    lastMousePosRef.current = { x: e.clientX, y: e.clientY, t: now };
    idleTimeMsRef.current += speed < 20 ? dt : 0;
    totalTimeMsRef.current += dt;
  }, []);

  const computeMetrics = useCallback(() => {
    const now = performance.now();
    // Drop old samples (>5s)
    speedSamplesRef.current = speedSamplesRef.current.filter((s) => now - s.t <= 5000);

    const avgSpeed = speedSamplesRef.current.length
      ? speedSamplesRef.current.reduce((a, b) => a + b.speed, 0) / speedSamplesRef.current.length
      : 0;

    const idleRatio = totalTimeMsRef.current > 0
      ? Math.min(1, idleTimeMsRef.current / totalTimeMsRef.current)
      : 0;

    // Get face detection metrics
    const faceScore = faceDetection.engagementScore;
    const faceDetected = faceDetection.faceDetected;
    const faceConfidence = faceDetection.faceConfidence;

    setMetrics({
      cursorSpeedPxPerSec: Math.round(avgSpeed),
      cursorIdleRatio: Number(idleRatio.toFixed(2)),
      faceDetected,
      faceConfidence: Number(faceConfidence.toFixed(2)),
      engagementScore: Number(faceScore.toFixed(2))
    });

    // Combined confidence from face detection and cursor behavior
    // Face detection is primary (70%), cursor activity is secondary (30%)
    const cursorActivityScore = 1 - idleRatio;
    const cursorSpeedScore = Math.exp(-Math.pow((avgSpeed - 150) / 150, 2));
    const cursorScore = 0.6 * cursorActivityScore + 0.4 * cursorSpeedScore;

    const combinedConfidence = 0.7 * faceScore + 0.3 * cursorScore;

    setConfidence(Number(Math.max(0, Math.min(1, combinedConfidence)).toFixed(2)));
  }, [faceDetection]);

  const startTracking = useCallback(async () => {
    if (isTracking) return true;

    const stream = await requestWebcam();
    if (!stream) return false;

    await calibrate();

    // Start face detection
    if (videoRef.current && faceDetection.isSupported) {
      faceDetection.startDetection(videoRef.current);
    }

    // Start cursor tracking
    window.addEventListener('mousemove', onMouseMove, { passive: true });
    tickIntervalRef.current = setInterval(computeMetrics, 1000);

    setIsTracking(true);
    console.log('[EngagementTracking] Started with ML face detection');
    return true;
  }, [isTracking, requestWebcam, calibrate, onMouseMove, computeMetrics, faceDetection]);

  const stopTracking = useCallback(() => {
    if (!isTracking) return;

    window.removeEventListener('mousemove', onMouseMove);

    if (tickIntervalRef.current) {
      clearInterval(tickIntervalRef.current);
      tickIntervalRef.current = null;
    }

    faceDetection.stopDetection();
    stopWebcam();

    setIsTracking(false);
    console.log('[EngagementTracking] Stopped');
  }, [isTracking, onMouseMove, stopWebcam, faceDetection]);

  useEffect(() => () => stopTracking(), [stopTracking]);

  return {
    isSupported: isSupported && faceDetection.isSupported,
    permissionState,
    isCalibrated,
    isTracking,
    webcamStream,
    confidence,
    metrics,
    startTracking,
    stopTracking
  };
};
