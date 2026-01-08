/**
 * Mood Checker Component
 * 5 emoji options for children to express their feelings
 */

import React from 'react';
import { Box, Typography, IconButton } from '@mui/material';

const MOODS = [
  { emoji: '😭', name: 'crying', label: 'Very Sad' },
  { emoji: '😢', name: 'sad', label: 'Sad' },
  { emoji: '😐', name: 'neutral', label: 'Okay' },
  { emoji: '😊', name: 'happy', label: 'Happy' },
  { emoji: '😄', name: 'laugh', label: 'Excited' }
];

const MoodChecker = ({ onMoodSelect, currentMood = null }) => {
  return (
    <Box
      sx={{
        display: 'flex',
        gap: 1,
        alignItems: 'center',
        justifyContent: 'center',
        p: 2,
        borderRadius: 2,
        bgcolor: 'background.paper',
        boxShadow: 1
      }}
    >
      <Typography variant="body2" sx={{ mr: 1 }}>
        How are you feeling?
      </Typography>

      {MOODS.map((mood) => (
        <IconButton
          key={mood.name}
          onClick={() => onMoodSelect(mood.name, mood.emoji)}
          sx={{
            fontSize: '2rem',
            opacity: currentMood === mood.name ? 1 : 0.5,
            transform: currentMood === mood.name ? 'scale(1.2)' : 'scale(1)',
            transition: 'all 0.2s',
            '&:hover': {
              transform: 'scale(1.2)',
              opacity: 1
            }
          }}
          title={mood.label}
        >
          {mood.emoji}
        </IconButton>
      ))}
    </Box>
  );
};

export default MoodChecker;
