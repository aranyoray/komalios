/**
 * EmojiCheckIn Component
 *
 * Interactive emoji-based self-report system for children.
 * Supports pre-task, post-task, and mid-session check-ins.
 * Age-appropriate, multilingual, and accessible.
 */

import React, { useState } from 'react';
import {
  Box,
  Typography,
  Button,
  Card,
  CardContent,
  Grid,
  Fade,
  Grow,
  IconButton,
  Paper,
} from '@mui/material';
import { styled, keyframes } from '@mui/material/styles';
import CloseIcon from '@mui/icons-material/Close';
import { useLanguage } from '../../i18n/LanguageContext';
import { EMOJI_CHECKINS } from '../../assessment/detailedSubdomainFramework';

/**
 * Pulse animation for selected emoji
 */
const pulse = keyframes`
  0% {
    transform: scale(1);
  }
  50% {
    transform: scale(1.2);
  }
  100% {
    transform: scale(1);
  }
`;

/**
 * Styled emoji button with hover and selection effects
 */
const EmojiButton = styled(Button)(({ theme, selected, size = 'large' }) => {
  const sizes = {
    small: { fontSize: '2rem', padding: '12px', minWidth: '80px' },
    medium: { fontSize: '3rem', padding: '16px', minWidth: '100px' },
    large: { fontSize: '4rem', padding: '20px', minWidth: '120px' },
  };

  return {
    fontSize: sizes[size].fontSize,
    padding: sizes[size].padding,
    minWidth: sizes[size].minWidth,
    minHeight: sizes[size].minWidth,
    borderRadius: '16px',
    border: selected ? `4px solid ${theme.palette.primary.main}` : '2px solid transparent',
    backgroundColor: selected ? theme.palette.primary.light : theme.palette.background.paper,
    boxShadow: selected ? theme.shadows[8] : theme.shadows[2],
    transition: 'all 0.3s ease',
    animation: selected ? `${pulse} 0.6s ease-in-out` : 'none',

    '&:hover': {
      transform: 'scale(1.1)',
      boxShadow: theme.shadows[6],
      backgroundColor: theme.palette.action.hover,
    },

    '&:active': {
      transform: 'scale(0.95)',
    },

    display: 'flex',
    flexDirection: 'column',
    gap: '8px',
  };
});

/**
 * Main EmojiCheckIn component
 */
export default function EmojiCheckIn({
  checkInType = 'feeling_pre_task',
  onComplete,
  onSkip,
  ageBand = '6-10',
  showSkipButton = false,
  autoSubmit = true,
  variant = 'card', // 'card' | 'fullscreen' | 'inline'
}) {
  const { t } = useLanguage();
  const [selectedValue, setSelectedValue] = useState(null);
  const [selectedOption, setSelectedOption] = useState(null);
  const [submitted, setSubmitted] = useState(false);

  // Get check-in definition
  const checkIn = EMOJI_CHECKINS[checkInType];

  if (!checkIn) {
    console.error(`Invalid checkInType: ${checkInType}`);
    return null;
  }

  // Age-appropriate sizing
  const getSize = () => {
    switch (ageBand) {
      case '3-5':
        return 'large'; // Bigger for younger children
      case '6-10':
        return 'medium';
      case '11-15':
        return 'small';
      default:
        return 'medium';
    }
  };

  const size = getSize();

  /**
   * Handle emoji selection
   */
  const handleSelect = (option) => {
    setSelectedValue(option.value);
    setSelectedOption(option);

    // Auto-submit if enabled
    if (autoSubmit) {
      setTimeout(() => {
        handleSubmit(option);
      }, 600); // Wait for animation
    }
  };

  /**
   * Handle manual submit
   */
  const handleSubmit = (option = selectedOption) => {
    if (!option) return;

    setSubmitted(true);

    // Create measurement result
    const result = {
      tool: `emoji_checkin_${checkIn.type}`,
      subdomain: getSubdomainForCheckIn(checkIn.type),
      score: (option.value / 5) * 100, // Convert 1-5 to 0-100
      rawData: {
        checkInType,
        emoji: option.emoji,
        label: option.label,
        value: option.value,
        timing: checkIn.timing,
      },
      timestamp: Date.now(),
      confidence: 1.0, // Self-report is fully confident
    };

    // Callback with result
    if (onComplete) {
      onComplete(result);
    }
  };

  /**
   * Map check-in type to subdomain
   */
  const getSubdomainForCheckIn = (type) => {
    const mapping = {
      feeling: 'emotion_identification',
      difficulty: 'working_memory',
      motivation: 'task_persistence',
      understanding: 'comprehension',
    };
    return mapping[type] || 'emotion_identification';
  };

  /**
   * Handle skip
   */
  const handleSkip = () => {
    if (onSkip) {
      onSkip();
    }
  };

  /**
   * Render content
   */
  const renderContent = () => (
    <Box sx={{ textAlign: 'center', width: '100%' }}>
      {/* Question */}
      <Typography
        variant={size === 'large' ? 'h4' : size === 'medium' ? 'h5' : 'h6'}
        gutterBottom
        sx={{
          fontWeight: 600,
          mb: 4,
          color: '#111827',
        }}
      >
        {checkIn.question}
      </Typography>

      {/* Emoji options */}
      <Grid
        container
        spacing={2}
        justifyContent="center"
        sx={{ mb: 3 }}
      >
        {checkIn.options.map((option, index) => (
          <Grid item key={index}>
            <Grow in timeout={300 + index * 100}>
              <Box>
                <EmojiButton
                  size={size}
                  selected={selectedValue === option.value}
                  onClick={() => handleSelect(option)}
                  aria-label={option.label}
                >
                  <span role="img" aria-label={option.label}>
                    {option.emoji}
                  </span>
                  <Typography
                    variant={size === 'large' ? 'body1' : 'body2'}
                    sx={{
                      fontWeight: selectedValue === option.value ? 700 : 500,
                      fontSize: size === 'large' ? '1.1rem' : size === 'medium' ? '0.95rem' : '0.85rem',
                    }}
                  >
                    {option.label}
                  </Typography>
                </EmojiButton>
              </Box>
            </Grow>
          </Grid>
        ))}
      </Grid>

      {/* Submit button (if not auto-submit) */}
      {!autoSubmit && selectedOption && (
        <Fade in>
          <Button
            variant="contained"
            size={size}
            onClick={() => handleSubmit()}
            sx={{
              mt: 2,
              px: 4,
              py: 1.5,
              fontSize: size === 'large' ? '1.2rem' : '1rem',
            }}
          >
            {t?.buttons?.continue || 'Continue'}
          </Button>
        </Fade>
      )}

      {/* Skip button */}
      {showSkipButton && !submitted && (
        <Button
          variant="text"
          size="small"
          onClick={handleSkip}
          sx={{ mt: 2 }}
        >
          {t?.buttons?.skip || 'Skip'}
        </Button>
      )}
    </Box>
  );

  /**
   * Render based on variant
   */
  if (variant === 'fullscreen') {
    return (
      <Fade in>
        <Box
          sx={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            bgcolor: '#FFFFFF',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1300,
            p: 3,
          }}
        >
          {showSkipButton && (
            <IconButton
              onClick={handleSkip}
              sx={{
                position: 'absolute',
                top: 16,
                right: 16,
              }}
            >
              <CloseIcon />
            </IconButton>
          )}
          <Box sx={{ maxWidth: '800px', width: '100%' }}>
            {renderContent()}
          </Box>
        </Box>
      </Fade>
    );
  }

  if (variant === 'inline') {
    return (
      <Box sx={{ py: 2 }}>
        {renderContent()}
      </Box>
    );
  }

  // Default: card variant
  return (
    <Fade in>
      <Card
        elevation={4}
        sx={{
          maxWidth: '700px',
          mx: 'auto',
          my: 2,
          borderRadius: 3,
        }}
      >
        <CardContent sx={{ p: 4 }}>
          {renderContent()}
        </CardContent>
      </Card>
    </Fade>
  );
}

/**
 * Compact version for quick check-ins
 */
export function CompactEmojiCheckIn({
  checkInType = 'feeling_pre_task',
  onComplete,
  label,
}) {
  const checkIn = EMOJI_CHECKINS[checkInType];

  if (!checkIn) return null;

  const handleSelect = (option) => {
    const result = {
      tool: `emoji_checkin_${checkIn.type}`,
      subdomain: 'emotion_identification',
      score: (option.value / 5) * 100,
      rawData: {
        checkInType,
        emoji: option.emoji,
        label: option.label,
        value: option.value,
        timing: checkIn.timing,
      },
      timestamp: Date.now(),
      confidence: 1.0,
    };

    if (onComplete) {
      onComplete(result);
    }
  };

  return (
    <Paper
      elevation={1}
      sx={{
        p: 2,
        borderRadius: 2,
        display: 'inline-flex',
        alignItems: 'center',
        gap: 2,
      }}
    >
      {label && (
        <Typography variant="body2" sx={{ fontWeight: 500 }}>
          {label}
        </Typography>
      )}
      <Box sx={{ display: 'flex', gap: 1 }}>
        {checkIn.options.map((option, index) => (
          <IconButton
            key={index}
            onClick={() => handleSelect(option)}
            size="small"
            sx={{
              fontSize: '1.5rem',
              '&:hover': {
                transform: 'scale(1.2)',
              },
            }}
            aria-label={option.label}
          >
            <span role="img" aria-label={option.label}>
              {option.emoji}
            </span>
          </IconButton>
        ))}
      </Box>
    </Paper>
  );
}

/**
 * Multi-step check-in sequence component
 */
export function EmojiCheckInSequence({
  checkIns = ['feeling_pre_task'],
  onComplete,
  onSkip,
  ageBand = '6-10',
}) {
  const [currentIndex, setCurrentIndex] = useState(0);
  const [results, setResults] = useState([]);

  const handleCheckInComplete = (result) => {
    const newResults = [...results, result];
    setResults(newResults);

    // Move to next or complete
    if (currentIndex < checkIns.length - 1) {
      setTimeout(() => {
        setCurrentIndex(currentIndex + 1);
      }, 500);
    } else {
      // All done
      if (onComplete) {
        onComplete(newResults);
      }
    }
  };

  const handleSkipAll = () => {
    if (onSkip) {
      onSkip();
    }
  };

  if (currentIndex >= checkIns.length) {
    return null;
  }

  return (
    <Box>
      {/* Progress indicator */}
      {checkIns.length > 1 && (
        <Box sx={{ mb: 2, textAlign: 'center' }}>
          <Typography variant="caption" sx={{ color: '#6B7280' }}>
            Question {currentIndex + 1} of {checkIns.length}
          </Typography>
        </Box>
      )}

      {/* Current check-in */}
      <EmojiCheckIn
        checkInType={checkIns[currentIndex]}
        onComplete={handleCheckInComplete}
        onSkip={handleSkipAll}
        ageBand={ageBand}
        showSkipButton={true}
        autoSubmit={true}
        variant="card"
      />
    </Box>
  );
}
