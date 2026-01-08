/**
 * Virtual Avatar Component
 * Displays animated avatar for therapeutic interaction
 */

import React, { useState, useEffect } from 'react';
import { Box, Typography } from '@mui/material';
import { motion } from 'framer-motion';

const AVATARS = {
  animal: {
    bear: { emoji: '🐻', name: 'Friendly Bear' },
    cat: { emoji: '🐱', name: 'Calm Cat' },
    dog: { emoji: '🐶', name: 'Happy Dog' },
    rabbit: { emoji: '🐰', name: 'Gentle Rabbit' }
  },
  human: {
    boy: { emoji: '👦', name: 'Sam' },
    girl: { emoji: '👧', name: 'Maya' },
    teacher: { emoji: '👨‍🏫', name: 'Mr. Guide' }
  }
};

const EMOTIONS = {
  neutral: '😐',
  happy: '😊',
  excited: '🤩',
  sad: '😢',
  surprised: '😮',
  thinking: '🤔'
};

const Avatar = ({
  type = 'animal',
  avatar = 'bear',
  emotion = 'neutral',
  isTalking = false,
  message = '',
  size = 150
}) => {
  const [currentEmotion, setCurrentEmotion] = useState(emotion);
  const avatarData = AVATARS[type]?.[avatar] || AVATARS.animal.bear;

  useEffect(() => {
    setCurrentEmotion(emotion);
  }, [emotion]);

  return (
    <Box
      sx={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: 2
      }}
    >
      {/* Avatar with animation */}
      <motion.div
        animate={{
          scale: isTalking ? [1, 1.05, 1] : 1,
          rotate: isTalking ? [0, 2, -2, 0] : 0
        }}
        transition={{
          duration: 0.5,
          repeat: isTalking ? Infinity : 0
        }}
      >
        <Box
          sx={{
            fontSize: `${size}px`,
            position: 'relative',
            userSelect: 'none'
          }}
        >
          {avatarData.emoji}

          {/* Emotion indicator (small emoji on corner) */}
          <Box
            sx={{
              position: 'absolute',
              bottom: -5,
              right: -5,
              fontSize: `${size * 0.3}px`,
              bgcolor: 'white',
              borderRadius: '50%',
              boxShadow: 2
            }}
          >
            {EMOTIONS[currentEmotion]}
          </Box>
        </Box>
      </motion.div>

      {/* Avatar name */}
      <Typography variant="h6" fontWeight="bold">
        {avatarData.name}
      </Typography>

      {/* Speech bubble */}
      {message && (
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0 }}
        >
          <Box
            sx={{
              bgcolor: 'primary.light',
              color: 'white',
              p: 2,
              borderRadius: 2,
              maxWidth: 300,
              position: 'relative',
              '&::before': {
                content: '""',
                position: 'absolute',
                top: -10,
                left: '50%',
                transform: 'translateX(-50%)',
                width: 0,
                height: 0,
                borderLeft: '10px solid transparent',
                borderRight: '10px solid transparent',
                borderBottom: '10px solid',
                borderBottomColor: 'primary.light'
              }
            }}
          >
            <Typography variant="body1">{message}</Typography>
          </Box>
        </motion.div>
      )}
    </Box>
  );
};

export default Avatar;
