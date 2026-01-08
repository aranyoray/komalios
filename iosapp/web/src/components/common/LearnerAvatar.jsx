/**
 * Learner Avatar Component
 * Displays learner avatar image or fallback to initial letter
 */

import React, { useState } from 'react';
import { Avatar } from '@mui/material';
import { styled } from '@mui/material/styles';

const StyledAvatar = styled(Avatar)(({ theme }) => ({
  border: `2px solid ${theme.palette.divider}`,
  boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
}));

const LearnerAvatar = ({ 
  learner, 
  size = 40, 
  sx = {},
  onClick 
}) => {
  // Get avatar from profile_image field
  const avatarPath = learner?.profile_image;
  
  // Fallback color based on name
  const getAvatarColor = (name) => {
    if (!name) return '#6366F1';
    const colors = [
      '#6366F1', '#EC4899', '#10B981', '#F59E0B', '#8B5CF6',
      '#EF4444', '#06B6D4', '#F97316', '#84CC16', '#A855F7'
    ];
    const index = name.charCodeAt(0) % colors.length;
    return colors[index];
  };

  // If avatar path exists and is valid, show image
  const [imageError, setImageError] = useState(false);
  
  // Show avatar image if path exists and is valid, otherwise show first letter
  if (avatarPath && avatarPath.startsWith('/avatars/') && !imageError) {
    return (
      <StyledAvatar
        src={avatarPath}
        alt={learner?.name || 'Learner'}
        sx={{
          width: size,
          height: size,
          cursor: onClick ? 'pointer' : 'default',
          ...sx,
        }}
        onClick={onClick}
        onError={() => setImageError(true)}
      >
        {learner?.name?.charAt(0)?.toUpperCase() || '?'}
      </StyledAvatar>
    );
  }

  // Fallback to initial letter with colored background (when no avatar or image fails to load)
  return (
    <StyledAvatar
      sx={{
        width: size,
        height: size,
        bgcolor: getAvatarColor(learner?.name),
        color: 'white',
        fontWeight: 'bold',
        fontSize: size * 0.4,
        cursor: onClick ? 'pointer' : 'default',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        ...sx,
      }}
      onClick={onClick}
    >
      {learner?.name?.charAt(0)?.toUpperCase() || '?'}
    </StyledAvatar>
  );
};

export default LearnerAvatar;

