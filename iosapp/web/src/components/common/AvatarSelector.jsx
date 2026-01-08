/**
 * Avatar Selector Component
 * Horizontal scrolling display of all available avatars for selection
 */

import React, { useState, useEffect, useRef } from 'react';
import { Box, Typography } from '@mui/material';
import { styled } from '@mui/material/styles';

// List of available avatars from public/avatars folder
const AVATAR_LIST = [
  'animal1.png',
  'animal2.png',
  'animal3.png',
  'animal4.png',
  'animal5.png',
  'animal6.png',
  'animal7.png',
  'animal8.png',
  'animal9.png',
  'animal10.png',
  'animal11.png'
];

// Default avatar (first one)
const DEFAULT_AVATAR = AVATAR_LIST[0];

const ScrollContainer = styled(Box)(({ theme, showScrollbar }) => ({
  position: 'relative',
  width: '100%',
  overflowX: 'auto',
  overflowY: 'hidden',
  padding: theme.spacing(1, 0),
  scrollBehavior: 'smooth',
  // Hide scrollbar for Firefox by default
  scrollbarWidth: showScrollbar ? 'thin' : 'none',
  scrollbarColor: showScrollbar
    ? `${theme.palette.primary.main}40 ${theme.palette.grey[50]}`
    : 'transparent transparent',
  // Custom scrollbar for WebKit browsers (Chrome, Safari, Edge)
  '&::-webkit-scrollbar': {
    height: showScrollbar ? '6px' : '0px',
    transition: 'height 0.3s ease',
  },
  '&::-webkit-scrollbar-track': {
    background: showScrollbar ? theme.palette.grey[50] : 'transparent',
    borderRadius: '10px',
    margin: '0 16px',
    transition: 'background 0.3s ease',
  },
  '&::-webkit-scrollbar-thumb': {
    background: showScrollbar
      ? `linear-gradient(90deg, ${theme.palette.primary.main}80, ${theme.palette.primary.main}60)`
      : 'transparent',
    borderRadius: '10px',
    border: showScrollbar ? `1px solid ${theme.palette.primary.main}20` : 'none',
    transition: 'background 0.3s ease, border 0.3s ease',
    '&:hover': {
      background: showScrollbar
        ? `linear-gradient(90deg, ${theme.palette.primary.main}, ${theme.palette.primary.main}80)`
        : 'transparent',
    },
  },
  // Show scrollbar on focus/hover/active
  '&:focus': {
    scrollbarWidth: 'thin',
    scrollbarColor: `${theme.palette.primary.main}40 ${theme.palette.grey[50]}`,
    '&::-webkit-scrollbar': {
      height: '6px',
    },
    '&::-webkit-scrollbar-track': {
      background: theme.palette.grey[50],
    },
    '&::-webkit-scrollbar-thumb': {
      background: `linear-gradient(90deg, ${theme.palette.primary.main}80, ${theme.palette.primary.main}60)`,
      border: `1px solid ${theme.palette.primary.main}20`,
    },
  },
  '&:hover': {
    scrollbarWidth: 'thin',
    scrollbarColor: `${theme.palette.primary.main}40 ${theme.palette.grey[50]}`,
    '&::-webkit-scrollbar': {
      height: '6px',
    },
    '&::-webkit-scrollbar-track': {
      background: theme.palette.grey[50],
    },
    '&::-webkit-scrollbar-thumb': {
      background: `linear-gradient(90deg, ${theme.palette.primary.main}80, ${theme.palette.primary.main}60)`,
      border: `1px solid ${theme.palette.primary.main}20`,
    },
  },
  '&:active': {
    scrollbarWidth: 'thin',
    scrollbarColor: `${theme.palette.primary.main}40 ${theme.palette.grey[50]}`,
    '&::-webkit-scrollbar': {
      height: '6px',
    },
    '&::-webkit-scrollbar-track': {
      background: theme.palette.grey[50],
    },
    '&::-webkit-scrollbar-thumb': {
      background: `linear-gradient(90deg, ${theme.palette.primary.main}80, ${theme.palette.primary.main}60)`,
      border: `1px solid ${theme.palette.primary.main}20`,
    },
  },
  // Gradient fade effects on edges
  '&::before': {
    content: '""',
    position: 'absolute',
    left: 0,
    top: 0,
    bottom: 0,
    width: '40px',
    background: 'linear-gradient(to right, rgba(255,255,255,0.95), transparent)',
    pointerEvents: 'none',
    zIndex: 1,
  },
  '&::after': {
    content: '""',
    position: 'absolute',
    right: 0,
    top: 0,
    bottom: 0,
    width: '40px',
    background: 'linear-gradient(to left, rgba(255,255,255,0.95), transparent)',
    pointerEvents: 'none',
    zIndex: 1,
  },
}));

const ScrollContent = styled(Box)(({ theme }) => ({
  display: 'flex',
  gap: '20px',
  padding: '12px 24px',
  minWidth: 'max-content',
  alignItems: 'center',
}));

const AvatarCard = styled(Box)(({ theme, selected }) => ({
  position: 'relative',
  flexShrink: 0,
  width: '100px',
  height: '100px',
  borderRadius: '50%',
  cursor: 'pointer',
  border: `3px solid ${selected ? theme.palette.primary.main : 'rgba(0,0,0,0.08)'}`,
  boxShadow: selected
    ? `0 8px 24px ${theme.palette.primary.main}40, 0 0 0 4px ${theme.palette.primary.main}10`
    : '0 2px 8px rgba(0,0,0,0.08)',
  transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
  overflow: 'hidden',
  backgroundColor: theme.palette.grey[50],
  zIndex: selected ? 2 : 1,
  '&:hover': {
    transform: 'translateY(-4px) scale(1.05)',
    boxShadow: selected
      ? `0 12px 32px ${theme.palette.primary.main}50, 0 0 0 4px ${theme.palette.primary.main}15`
      : '0 8px 20px rgba(0,0,0,0.12)',
    borderColor: selected ? theme.palette.primary.main : theme.palette.primary.light,
  },
  '&:active': {
    transform: 'translateY(-2px) scale(1.02)',
  },
}));

const AvatarImage = styled('img')({
  width: '100%',
  height: '100%',
  objectFit: 'cover',
  borderRadius: '50%',
});

const SelectionIndicator = styled(Box)(({ theme }) => ({
  position: 'absolute',
  bottom: '-8px',
  left: '50%',
  transform: 'translateX(-50%)',
  width: '24px',
  height: '24px',
  borderRadius: '50%',
  backgroundColor: theme.palette.primary.main,
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  color: 'white',
  fontSize: '14px',
  fontWeight: 'bold',
  boxShadow: `0 4px 12px ${theme.palette.primary.main}40`,
}));

const AvatarSelector = ({
  selectedAvatar,
  onAvatarSelect,
  defaultAvatar = DEFAULT_AVATAR
}) => {
  const [showScrollbar, setShowScrollbar] = useState(false);
  const scrollContainerRef = useRef(null);
  const timeoutRef = useRef(null);

  // Initialize with default avatar if none selected
  useEffect(() => {
    if (!selectedAvatar && defaultAvatar) {
      onAvatarSelect(defaultAvatar);
    }
  }, []);

  // Show scrollbar temporarily when interacting
  const showScrollbarTemporarily = () => {
    setShowScrollbar(true);
    // Clear existing timeout
    if (timeoutRef.current) {
      clearTimeout(timeoutRef.current);
    }
    // Hide scrollbar after 2 seconds of no interaction
    timeoutRef.current = setTimeout(() => {
      setShowScrollbar(false);
    }, 2000);
  };

  // Cleanup timeout on unmount
  useEffect(() => {
    return () => {
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
      }
    };
  }, []);

  const handleAvatarClick = (avatar) => {
    showScrollbarTemporarily();
    onAvatarSelect(avatar);
  };

  const handleScrollContainerFocus = () => {
    setShowScrollbar(true);
  };

  const handleScrollContainerBlur = () => {
    // Hide scrollbar after a delay when focus is lost
    setTimeout(() => {
      setShowScrollbar(false);
    }, 500);
  };

  const handleScrollContainerMouseEnter = () => {
    setShowScrollbar(true);
  };

  const handleScrollContainerMouseLeave = () => {
    // Hide scrollbar when mouse leaves (unless recently interacted)
    setTimeout(() => {
      setShowScrollbar(false);
    }, 500);
  };

  return (
    <Box>
      <Typography
        variant="subtitle1"
        fontWeight="bold"
        gutterBottom
        sx={{ textAlign: 'center' }}
      >
        Choose Your Avatar!
      </Typography>

      <ScrollContainer
        ref={scrollContainerRef}
        showScrollbar={showScrollbar}
        onFocus={handleScrollContainerFocus}
        onBlur={handleScrollContainerBlur}
        onMouseEnter={handleScrollContainerMouseEnter}
        onMouseLeave={handleScrollContainerMouseLeave}
        tabIndex={0}
      >
        <ScrollContent>
          {AVATAR_LIST.map((avatar, index) => {
            const isSelected = selectedAvatar === avatar;
            const avatarPath = `/avatars/${avatar}`;

            return (
              <AvatarCard
                key={avatar}
                selected={isSelected}
                onClick={() => handleAvatarClick(avatar)}
              >
                <AvatarImage
                  src={avatarPath}
                  alt={`Avatar ${index + 1}`}
                  onError={(e) => {
                    // Fallback if image doesn't load
                    e.target.style.display = 'none';
                  }}
                />
                {isSelected && (
                  <SelectionIndicator>
                    ✓
                  </SelectionIndicator>
                )}
              </AvatarCard>
            );
          })}
        </ScrollContent>
      </ScrollContainer>
    </Box>
  );
};

export default AvatarSelector;
export { DEFAULT_AVATAR, AVATAR_LIST };

