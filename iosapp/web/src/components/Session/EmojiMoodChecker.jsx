/**
 * Emoji Mood Checker
 * 5 mood options at session start
 */

import React, { useState } from 'react';
import { Box, Typography } from '@mui/material';
import { Haptics, ImpactStyle } from '@capacitor/haptics';

const moods = [
  { id: 'crying', emoji: '😢', label: 'Very Sad', value: 1 },
  { id: 'sad', emoji: '😞', label: 'Sad', value: 2 },
  { id: 'neutral', emoji: '😐', label: 'Okay', value: 3 },
  { id: 'happy', emoji: '😊', label: 'Happy', value: 4 },
  { id: 'laugh', emoji: '😄', label: 'Excited', value: 5 },
];

const EmojiMoodChecker = ({ onMoodSelect, selectedMood, size = 'medium' }) => {
  const [selected, setSelected] = useState(selectedMood || null);

  const handleSelect = async (mood) => {
    setSelected(mood.id);

    // Haptic feedback
    try {
      await Haptics.impact({ style: ImpactStyle.Medium });
    } catch (e) { }

    if (onMoodSelect) {
      onMoodSelect(mood);
    }
  };

  const getSize = () => {
    switch (size) {
      case 'small': return { emoji: '1.5rem', container: 36 };
      case 'large': return { emoji: '2.5rem', container: 60 };
      default: return { emoji: '2rem', container: 48 };
    }
  };

  const sizes = getSize();

  return (
    <Box
      sx={{
        display: 'flex',
        justifyContent: 'space-between',
        width: '100%',
        gap: { xs: 1, sm: 2 },
      }}
    >
      {moods.map((mood) => (
        <Box
          key={mood.id}
          onClick={() => handleSelect(mood)}
          sx={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            cursor: 'pointer',
            transition: 'all 0.2s ease',
            transform: selected === mood.id ? 'scale(1.1)' : 'scale(1)',
            opacity: selected && selected !== mood.id ? 0.4 : 1,
            flex: 1,
          }}
        >
          <Box
            sx={{
              width: sizes.container,
              height: sizes.container,
              borderRadius: '50%',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              bgcolor: selected === mood.id ? '#C7D2FE' : 'transparent', // Soft Indigo
              border: '2px solid',
              borderColor: selected === mood.id ? '#4338CA' : 'transparent', // Indigo 700
              transition: 'all 0.2s ease',
            }}
          >
            <Typography sx={{ fontSize: sizes.emoji, lineHeight: 1 }}>
              {mood.emoji}
            </Typography>
          </Box>
          <Typography
            variant="caption"
            sx={{
              mt: 0.5,
              fontWeight: selected === mood.id ? 700 : 500,
              color: selected === mood.id ? '#4338CA' : 'text.secondary',
              fontSize: '0.7rem',
              textAlign: 'center',
            }}
          >
            {mood.label}
          </Typography>
        </Box>
      ))}
    </Box>
  );
};

export default EmojiMoodChecker;
