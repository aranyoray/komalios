/**
 * Splash Screen Component
 * Simple video splash screen using HTML5 video
 */

import React, { useEffect, useRef, useState, useCallback } from 'react';
import { Box, Typography } from '@mui/material';
import { Capacitor } from '@capacitor/core';

const SplashScreen = ({ onComplete }) => {
  const videoRef = useRef(null);
  const startTimeRef = useRef(null);
  const [videoUrl, setVideoUrl] = useState('');
  const [showDebug, setShowDebug] = useState(false);
  const [videoReady, setVideoReady] = useState(false);
  const [isPlaying, setIsPlaying] = useState(false);
  const [isFading, setIsFading] = useState(false);

  // Get video path - memoized to prevent re-renders
  const videoPath = React.useMemo(() => {
    // New splash video in assets folder (MP4 for browser compatibility)
    return '/assets/123123.mp4';
  }, []);

  // Check if running on native platform
  const isNative = Capacitor.isNativePlatform();

  // Aggressively try to play video as soon as possible
  const attemptPlay = useCallback(() => {
    if (videoRef.current && videoRef.current.paused) {
      const playPromise = videoRef.current.play();
      if (playPromise !== undefined) {
        playPromise
          .then(() => {
            console.log('[SplashScreen] Video playing successfully');
            setIsPlaying(true);

            // Only try to unmute on native platforms (browsers block this)
            if (isNative && videoRef.current && videoRef.current.muted) {
              try {
                videoRef.current.muted = false;
                console.log('[SplashScreen] Video unmuted after play (native)');
              } catch (error) {
                console.warn('[SplashScreen] Could not unmute:', error);
              }
            }
          })
          .catch((error) => {
            console.warn('[SplashScreen] Play error:', error);
            // Don't retry on NotAllowedError (autoplay blocked)
            if (error.name === 'NotAllowedError') {
              console.warn('[SplashScreen] Autoplay blocked, keeping muted (this is expected on web)');
              // On web, just mark as playing since the video will play muted
              setIsPlaying(true);
              return;
            }
            // Retry after a short delay for other errors
            setTimeout(attemptPlay, 100);
          });
      }
    }
  }, [isNative]);

  useEffect(() => {
    startTimeRef.current = Date.now();
    setVideoUrl(videoPath);

    // Set body styles
    document.body.style.backgroundColor = '#000';
    document.body.style.overflow = 'hidden';

    // Try to play immediately after a short delay (for Android)
    const timer = setTimeout(() => {
      attemptPlay();
    }, 100);

    return () => {
      clearTimeout(timer);
      document.body.style.backgroundColor = '';
      document.body.style.overflow = '';
    };
  }, [videoPath, attemptPlay]);

  // Wait for video to be ready before playing
  const handleCanPlay = () => {
    console.log('[SplashScreen] Video can play, readyState:', videoRef.current?.readyState);
    setVideoReady(true);
    attemptPlay();
  };

  const handleLoadedMetadata = () => {
    console.log('[SplashScreen] Video metadata loaded');
    console.log('[SplashScreen] Video URL:', videoRef.current?.src);
    console.log('[SplashScreen] Video currentSrc:', videoRef.current?.currentSrc);
    attemptPlay();
  };

  const handleLoadedData = () => {
    console.log('[SplashScreen] Video data loaded');
    setVideoReady(true);
    attemptPlay();
  };

  const handlePlaying = () => {
    console.log('[SplashScreen] Video is now playing');
    setIsPlaying(true);

    // Only unmute on native platforms - browsers require user interaction to unmute
    if (isNative && videoRef.current && videoRef.current.muted) {
      try {
        videoRef.current.muted = false;
        console.log('[SplashScreen] Video unmuted successfully (native)');
      } catch (error) {
        console.warn('[SplashScreen] Could not unmute video:', error);
      }
    }
  };

  // Handle video end with fade out
  const handleVideoEnd = () => {
    // Start fade out animation
    setIsFading(true);

    // Wait for fade animation to complete, then notify parent
    setTimeout(() => {
      onComplete?.();
    }, 800); // Match the CSS transition duration
  };

  const handleClick = (e) => {
    // Toggle debug info
    // setShowDebug(!showDebug);

    // Also try to play if paused
    if (videoRef.current && videoRef.current.paused) {
      attemptPlay();
    }
  };

  return (
    <Box
      sx={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        width: '100vw',
        height: '100vh',
        zIndex: 9999,
        backgroundColor: '#000',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        opacity: isFading ? 0 : 1,
        transition: 'opacity 0.8s ease-out',
        pointerEvents: isFading ? 'none' : 'auto',
      }}
    >
      <video
        ref={videoRef}
        src={videoPath}
        autoPlay
        muted
        playsInline
        preload="auto"
        controls={false}
        disablePictureInPicture
        disableRemotePlayback
        onEnded={handleVideoEnd}
        onLoadedMetadata={handleLoadedMetadata}
        onLoadedData={handleLoadedData}
        onCanPlay={handleCanPlay}
        onCanPlayThrough={() => {
          console.log('[SplashScreen] Video can play through');
          setVideoReady(true);
          attemptPlay();
        }}
        onPlaying={handlePlaying}
        onClick={handleClick}
        style={{
          maxWidth: '100%',
          maxHeight: '100%',
          objectFit: 'contain',
          cursor: 'pointer',
          pointerEvents: 'auto',
          // Hide any default controls
          WebkitAppearance: 'none',
          appearance: 'none',
        }}
        className="splash-video"
      />

      {/* Loading overlay - hides when video is playing */}
      {!isPlaying && (
        <Box
          sx={{
            position: 'absolute',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            backgroundColor: '#000',
            zIndex: 10001,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        />
      )}

      {/* Debug info overlay */}
      {showDebug && (
        <Box
          sx={{
            position: 'absolute',
            top: 20,
            left: 20,
            right: 20,
            backgroundColor: 'rgba(0, 0, 0, 0.8)',
            color: 'white',
            p: 2,
            borderRadius: 2,
            zIndex: 10000,
            fontSize: '0.85rem',
            fontFamily: 'monospace',
          }}
        >
          <Typography variant="body2" sx={{ mb: 1, fontWeight: 'bold' }}>
            Video Debug Info:
          </Typography>
          <Typography variant="body2" sx={{ mb: 0.5 }}>
            URL: {videoUrl || videoRef.current?.src || 'Not set'}
          </Typography>
          <Typography variant="body2" sx={{ mb: 0.5 }}>
            Current Src: {videoRef.current?.currentSrc || 'N/A'}
          </Typography>
          <Typography variant="body2" sx={{ mb: 0.5 }}>
            Ready State: {videoRef.current?.readyState || 'N/A'}
          </Typography>
          <Typography variant="body2" sx={{ mb: 0.5 }}>
            Network State: {videoRef.current?.networkState || 'N/A'}
          </Typography>
          <Typography variant="body2" sx={{ mb: 0.5 }}>
            Paused: {videoRef.current?.paused ? 'Yes' : 'No'}
          </Typography>
          <Typography variant="body2" sx={{ mb: 0.5 }}>
            Video Ready: {videoReady ? 'Yes' : 'No'}
          </Typography>
          <Typography variant="body2" sx={{ mb: 0.5 }}>
            Platform: {Capacitor.getPlatform()}
          </Typography>
          <Typography variant="body2" sx={{ fontSize: '0.75rem', mt: 1, opacity: 0.7 }}>
            Click again to hide
          </Typography>
        </Box>
      )}
    </Box>
  );
};

export default SplashScreen;
