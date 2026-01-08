import React from 'react';
import { IconButton } from '@mui/material';
import { VolumeUp } from '@mui/icons-material';

const AudioButton = ({ onClick, text, disabled = false }) => {
  return (
    <IconButton
      onClick={onClick}
      disabled={disabled}
      sx={{ 
        bgcolor: 'rgba(255,255,255,0.2)',
        color: 'white',
        '&:hover': { bgcolor: 'rgba(255,255,255,0.3)' }
      }}
      aria-label={`Read aloud: ${text}`}
    >
      <VolumeUp />
    </IconButton>
  );
};

export default AudioButton;
