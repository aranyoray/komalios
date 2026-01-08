/**
 * Handwriting Canvas Component
 * Optimized for touch input on mobile devices (especially iPhones)
 * Allows kids to draw their answers
 */

import React, { useRef, useEffect, useState, useCallback } from 'react';
import { Box, IconButton, Chip } from '@mui/material';
import { Delete, Check } from '@mui/icons-material';

const HandwritingCanvas = ({ onComplete, onClear, width = 280, height = 140 }) => {
  const canvasRef = useRef(null);
  const [isDrawing, setIsDrawing] = useState(false);
  const [hasContent, setHasContent] = useState(false);
  const lastPosRef = useRef({ x: 0, y: 0 });

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');

    // Set up canvas for high DPI displays (iPhones have high pixel density)
    const dpr = window.devicePixelRatio || 1;
    const rect = canvas.getBoundingClientRect();

    canvas.width = rect.width * dpr;
    canvas.height = rect.height * dpr;

    ctx.scale(dpr, dpr);

    // Set drawing style
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.lineWidth = 3;
    ctx.strokeStyle = '#000';

    // Clear with white background
    ctx.fillStyle = '#fff';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
  }, []);

  const getCoordinates = useCallback((e) => {
    const canvas = canvasRef.current;
    const rect = canvas.getBoundingClientRect();

    if (e.touches && e.touches.length > 0) {
      // Touch event (mobile)
      return {
        x: e.touches[0].clientX - rect.left,
        y: e.touches[0].clientY - rect.top
      };
    } else {
      // Mouse event (desktop)
      return {
        x: e.clientX - rect.left,
        y: e.clientY - rect.top
      };
    }
  }, []);

  const startDrawing = useCallback((e) => {
    e.preventDefault();
    const pos = getCoordinates(e);
    lastPosRef.current = pos;
    setIsDrawing(true);
    setHasContent(true);
  }, [getCoordinates]);

  const draw = useCallback((e) => {
    if (!isDrawing) return;
    e.preventDefault();

    const canvas = canvasRef.current;
    const ctx = canvas.getContext('2d');
    const pos = getCoordinates(e);

    ctx.beginPath();
    ctx.moveTo(lastPosRef.current.x, lastPosRef.current.y);
    ctx.lineTo(pos.x, pos.y);
    ctx.stroke();

    lastPosRef.current = pos;
  }, [isDrawing, getCoordinates]);

  const stopDrawing = useCallback((e) => {
    if (!isDrawing) return;
    e.preventDefault();
    setIsDrawing(false);
  }, [isDrawing]);

  const handleClear = useCallback(() => {
    const canvas = canvasRef.current;
    const ctx = canvas.getContext('2d');

    ctx.fillStyle = '#fff';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    setHasContent(false);
    if (onClear) onClear();
  }, [onClear]);

  const handleComplete = useCallback(() => {
    if (!hasContent) return;

    const canvas = canvasRef.current;

    // Get image data for ML processing
    const imageData = canvas.toDataURL('image/png');

    if (onComplete) {
      onComplete({
        imageData,
        canvas,
        width: canvas.width,
        height: canvas.height
      });
    }
  }, [hasContent, onComplete]);

  return (
    <Box sx={{ position: 'relative' }}>
      <Box
        sx={{
          border: '2px dashed #ccc',
          borderRadius: 2,
          overflow: 'hidden',
          touchAction: 'none', // Prevent scrolling while drawing on mobile
          userSelect: 'none',
          WebkitUserSelect: 'none'
        }}
      >
        <canvas
          ref={canvasRef}
          style={{
            display: 'block',
            width: width + 'px',
            height: height + 'px',
            cursor: 'crosshair',
            backgroundColor: '#fff'
          }}
          onMouseDown={startDrawing}
          onMouseMove={draw}
          onMouseUp={stopDrawing}
          onMouseLeave={stopDrawing}
          onTouchStart={startDrawing}
          onTouchMove={draw}
          onTouchEnd={stopDrawing}
          onTouchCancel={stopDrawing}
        />
      </Box>

      <Box
        sx={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          mt: 1
        }}
      >
        <IconButton
          onClick={handleClear}
          disabled={!hasContent}
          size="small"
          color="error"
        >
          <Delete />
        </IconButton>

        {hasContent && (
          <Chip
            label="Draw your answer above"
            size="small"
            color="primary"
            variant="outlined"
          />
        )}

        <IconButton
          onClick={handleComplete}
          disabled={!hasContent}
          size="small"
          color="success"
        >
          <Check />
        </IconButton>
      </Box>
    </Box>
  );
};

export default HandwritingCanvas;
