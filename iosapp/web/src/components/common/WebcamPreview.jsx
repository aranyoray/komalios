import React, { useEffect, useRef } from 'react';
import { Box, CircularProgress, Typography } from '@mui/material';

const WebcamPreview = ({ stream, status = 'idle' }) => {
  const videoRef = useRef(null);

  useEffect(() => {
    if (videoRef.current && stream) {
      videoRef.current.srcObject = stream;
      videoRef.current.play().catch(() => {});
    }
  }, [stream]);

  return (
    <Box sx={{ position: 'relative', width: '100%', borderRadius: 1, overflow: 'hidden', bgcolor: '#000', height: 160 }}>
      {!stream && (
        <Box sx={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'white' }}>
          {status === 'pending' ? (
            <>
              <CircularProgress size={24} sx={{ mr: 1, color: 'white' }} />
              <Typography variant="caption">Requesting webcam permission…</Typography>
            </>
          ) : (
            <Typography variant="caption">Webcam not active</Typography>
          )}
        </Box>
      )}
      <video ref={videoRef} muted playsInline style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
    </Box>
  );
};

export default WebcamPreview;
