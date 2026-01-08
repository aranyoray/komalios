/**
 * Virtual Avatar Component
 * Animated avatar for therapeutic SEL interactions
 */

import React, { useState, useEffect, useRef } from 'react';
import { Box, Typography } from '@mui/material';

const AVATAR_STATES = {
  IDLE: 'idle',
  TALKING: 'talking',
  LISTENING: 'listening',
  HAPPY: 'happy',
  THINKING: 'thinking',
  ENCOURAGING: 'encouraging',
  CELEBRATING: 'celebrating',
};

const VirtualAvatar = ({
  state = AVATAR_STATES.IDLE,
  message = '',
  onAnimationComplete,
  avatarType = 'human', // 'human' or 'animal'
  animationLevel = 'medium', // 'off', 'medium', 'high'
  size = 200,
}) => {
  const [currentState, setCurrentState] = useState(state);
  const [isAnimating, setIsAnimating] = useState(false);
  const animationRef = useRef(null);

  useEffect(() => {
    setCurrentState(state);
    if (state !== AVATAR_STATES.IDLE && animationLevel !== 'off') {
      setIsAnimating(true);
      animationRef.current = setTimeout(() => {
        setIsAnimating(false);
        if (onAnimationComplete) onAnimationComplete();
      }, 2000);
    }

    return () => {
      if (animationRef.current) clearTimeout(animationRef.current);
    };
  }, [state]);

  const getAvatarEmoji = () => {
    if (avatarType === 'animal') {
      switch (currentState) {
        case AVATAR_STATES.HAPPY:
        case AVATAR_STATES.CELEBRATING:
          return '🐶';
        case AVATAR_STATES.THINKING:
          return '🦊';
        case AVATAR_STATES.ENCOURAGING:
          return '🐱';
        case AVATAR_STATES.TALKING:
          return '🐰';
        default:
          return '🐻';
      }
    }

    // Human avatar
    switch (currentState) {
      case AVATAR_STATES.HAPPY:
        return '😊';
      case AVATAR_STATES.TALKING:
        return '🗣️';
      case AVATAR_STATES.LISTENING:
        return '👂';
      case AVATAR_STATES.THINKING:
        return '🤔';
      case AVATAR_STATES.ENCOURAGING:
        return '💪';
      case AVATAR_STATES.CELEBRATING:
        return '🎉';
      default:
        return '😊';
    }
  };

  const getAnimation = () => {
    if (animationLevel === 'off') return {};

    const intensity = animationLevel === 'high' ? 1.2 : 1;

    switch (currentState) {
      case AVATAR_STATES.TALKING:
        return {
          '@keyframes talk': {
            '0%, 100%': { transform: 'scale(1)' },
            '25%': { transform: `scale(${1.05 * intensity})` },
            '75%': { transform: `scale(${0.95 * intensity})` },
          },
          animation: 'talk 0.3s infinite',
        };
      case AVATAR_STATES.HAPPY:
      case AVATAR_STATES.CELEBRATING:
        return {
          '@keyframes bounce': {
            '0%, 100%': { transform: 'translateY(0)' },
            '50%': { transform: `translateY(${-10 * intensity}px)` },
          },
          animation: 'bounce 0.5s infinite',
        };
      case AVATAR_STATES.THINKING:
        return {
          '@keyframes think': {
            '0%, 100%': { transform: 'rotate(0deg)' },
            '25%': { transform: `rotate(${-5 * intensity}deg)` },
            '75%': { transform: `rotate(${5 * intensity}deg)` },
          },
          animation: 'think 1s infinite',
        };
      case AVATAR_STATES.ENCOURAGING:
        return {
          '@keyframes pulse': {
            '0%, 100%': { transform: 'scale(1)' },
            '50%': { transform: `scale(${1.1 * intensity})` },
          },
          animation: 'pulse 1s infinite',
        };
      default:
        return {
          '@keyframes breathe': {
            '0%, 100%': { transform: 'scale(1)' },
            '50%': { transform: 'scale(1.02)' },
          },
          animation: 'breathe 3s infinite',
        };
    }
  };

  const getBackgroundColor = () => {
    switch (currentState) {
      case AVATAR_STATES.HAPPY:
      case AVATAR_STATES.CELEBRATING:
        return 'linear-gradient(135deg, #10B981 0%, #34D399 100%)';
      case AVATAR_STATES.ENCOURAGING:
        return 'linear-gradient(135deg, #F59E0B 0%, #FBBF24 100%)';
      case AVATAR_STATES.THINKING:
        return 'linear-gradient(135deg, #8B5CF6 0%, #A78BFA 100%)';
      default:
        return 'linear-gradient(135deg, #6366F1 0%, #818CF8 100%)';
    }
  };

  return (
    <Box
      sx={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: 2,
      }}
    >
      {/* Avatar Circle */}
      <Box
        sx={{
          width: size,
          height: size,
          borderRadius: '50%',
          background: getBackgroundColor(),
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          boxShadow: '0 10px 30px rgba(99, 102, 241, 0.3)',
          ...getAnimation(),
        }}
      >
        <Typography sx={{ fontSize: size * 0.5 }}>
          {getAvatarEmoji()}
        </Typography>
      </Box>

      {/* Speech Bubble */}
      {message && (
        <Box
          sx={{
            position: 'relative',
            bgcolor: 'white',
            borderRadius: 3,
            p: 2,
            maxWidth: 300,
            boxShadow: '0 4px 12px rgba(0,0,0,0.1)',
            '&::before': {
              content: '""',
              position: 'absolute',
              top: -8,
              left: '50%',
              transform: 'translateX(-50%)',
              width: 0,
              height: 0,
              borderLeft: '8px solid transparent',
              borderRight: '8px solid transparent',
              borderBottom: '8px solid white',
            },
          }}
        >
          <Typography variant="body1" textAlign="center">
            {message}
          </Typography>
        </Box>
      )}
    </Box>
  );
};

export { AVATAR_STATES };
export default VirtualAvatar;
