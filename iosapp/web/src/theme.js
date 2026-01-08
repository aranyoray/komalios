/**
 * Komal App Theme
 * A modern, calm, and friendly design system for children.
 * Inspired by clear, minimalistic, and high-quality educational apps.
 */

import { createTheme } from '@mui/material/styles';

// Core Palette
const colors = {
  deepViolet: '#240460',      // Primary Actions, Headers, Text
  lightCloud: '#BAADDD',      // App Background
  pinkishViolet: '#D8BDF7',   // Accents, Highlights
  white: '#FFFFFF',           // Cards, Surfaces

  // Semantic Colors (Softened for friendliness)
  success: '#2E7D32',         // Natural Green
  warning: '#ED6C02',         // Warm Orange
  error: '#D32F2F',           // Soft Red
  info: '#0288D1',            // Calm Blue

  // Text Colors
  textPrimary: '#240460',     // Deep Violet for maximum readability
  textSecondary: '#5D547A',   // Muted Violet-Gray

  // UI States
  actionHover: '#3A1C75',     // Slightly lighter violet for hovers
  cardShadow: 'rgba(36, 4, 96, 0.08)',
};

const theme = createTheme({
  palette: {
    primary: {
      main: colors.deepViolet,
      light: '#4C2889',
      dark: '#160045',
      contrastText: '#FFFFFF',
    },
    secondary: {
      main: colors.pinkishViolet,
      light: '#EADDFF',
      dark: '#BFA0E6',
      contrastText: colors.deepViolet,
    },
    background: {
      default: colors.lightCloud,
      paper: colors.white,
    },
    text: {
      primary: colors.textPrimary,
      secondary: colors.textSecondary,
    },
    success: {
      main: colors.success,
    },
    warning: {
      main: colors.warning,
    },
    error: {
      main: colors.error,
    },
    info: {
      main: colors.info,
    },
  },
  typography: {
    fontFamily: '"Poppins", "Varela Round", "Arial", sans-serif',
    fontSize: 16,
    h1: {
      fontSize: '2.5rem',
      fontWeight: 800,
      color: colors.deepViolet,
      lineHeight: 1.2,
      letterSpacing: '-0.02em',
    },
    h2: {
      fontSize: '2rem',
      fontWeight: 700,
      color: colors.deepViolet,
      lineHeight: 1.3,
    },
    h3: {
      fontSize: '1.75rem',
      fontWeight: 700,
      color: colors.deepViolet,
      lineHeight: 1.4,
    },
    h4: {
      fontSize: '1.5rem',
      fontWeight: 600,
      color: colors.deepViolet,
      lineHeight: 1.4,
    },
    h5: {
      fontSize: '1.25rem',
      fontWeight: 600,
      color: colors.deepViolet,
      lineHeight: 1.5,
    },
    h6: {
      fontSize: '1.125rem',
      fontWeight: 600,
      color: colors.deepViolet,
      lineHeight: 1.5,
    },
    body1: {
      fontSize: '1.05rem', // Slightly larger for readability
      lineHeight: 1.6,
      color: colors.textPrimary,
      fontWeight: 500,
    },
    body2: {
      fontSize: '0.9rem',
      lineHeight: 1.6,
      color: colors.textSecondary,
      fontWeight: 500,
    },
    button: {
      fontSize: '1rem',
      fontWeight: 700,
      textTransform: 'none',
      letterSpacing: '0.01em',
    },
  },
  shape: {
    borderRadius: 24, // Generous rounded corners everywhere
  },
  shadows: [
    'none',
    `0 2px 4px ${colors.cardShadow}`,
    `0 4px 8px ${colors.cardShadow}`,
    `0 8px 16px ${colors.cardShadow}`,
    `0 12px 24px ${colors.cardShadow}`,
    // ...standard MUI shadows replaced with softer violet-tinted shadows
    ...Array(20).fill('none'),
  ],
  components: {
    MuiCssBaseline: {
      styleOverrides: {
        body: {
          backgroundColor: colors.lightCloud,
          color: colors.textPrimary,
        },
      },
    },
    MuiButton: {
      styleOverrides: {
        root: {
          borderRadius: 9999, // Pill shape
          padding: '12px 32px',
          boxShadow: 'none', // Flat design
          fontSize: '1.1rem',
          transition: 'transform 0.1s ease, background-color 0.2s ease',
          '&:hover': {
            transform: 'translateY(-2px)',
            boxShadow: 'none',
          },
          '&:active': {
            transform: 'translateY(1px)',
          },
        },
        containedPrimary: {
          backgroundColor: colors.deepViolet,
          '&:hover': {
            backgroundColor: colors.actionHover,
            // Minimal lift effect
            boxShadow: `0 6px 0 ${colors.actionHover}`,
            transform: 'translateY(-2px)',
          },
          '&:active': {
            boxShadow: 'none',
            transform: 'translateY(4px)',
          },
        },
        containedSecondary: {
          backgroundColor: colors.pinkishViolet,
          color: colors.deepViolet,
          '&:hover': {
            backgroundColor: '#C5A3EB', // Slightly darker pink/violet
          },
        },
        outlined: {
          borderWidth: 2,
          borderColor: colors.deepViolet,
          color: colors.deepViolet,
          '&:hover': {
            borderWidth: 2,
            backgroundColor: 'rgba(36, 4, 96, 0.05)',
            borderColor: colors.deepViolet,
          },
        },
      },
    },
    MuiCard: {
      styleOverrides: {
        root: {
          borderRadius: 32, // Very rounded cards
          boxShadow: `0 4px 0 rgba(0,0,0,0.05)`, // Subtle, slightly raised look
          border: 'none',
          overflow: 'hidden',
        },
      },
    },
    MuiPaper: {
      styleOverrides: {
        root: {
          backgroundImage: 'none', // Disable MUI overlays
        },
        elevation1: {
          boxShadow: `0 4px 12px ${colors.cardShadow}`,
        },
        rounded: {
          borderRadius: 24,
        },
      },
    },
    MuiTextField: {
      styleOverrides: {
        root: {
          '& .MuiOutlinedInput-root': {
            backgroundColor: '#F5F2FA', // Very light violet tint for inputs
            borderRadius: 20,
            '& fieldset': {
              borderWidth: 2,
              borderColor: 'transparent', // Cleaner look by default
            },
            '&:hover fieldset': {
              borderColor: '#D8BDF7',
            },
            '&.Mui-focused fieldset': {
              borderColor: colors.deepViolet,
            },
            '&.Mui-focused': {
              backgroundColor: colors.white,
            },
          },
          '& .MuiInputBase-input': {
            color: colors.deepViolet,
            fontWeight: 600,
          },
          '& .MuiInputLabel-root': {
            color: colors.textSecondary,
            fontWeight: 500,
            '&.Mui-focused': {
              color: colors.deepViolet,
            }
          }
        },
      },
    },
    MuiChip: {
      styleOverrides: {
        root: {
          fontWeight: 600,
          borderRadius: 16,
        },
        colorSecondary: {
          backgroundColor: colors.pinkishViolet,
          color: colors.deepViolet,
        }
      }
    },
    MuiAlert: {
      styleOverrides: {
        root: {
          borderRadius: 20,
        },
        standardInfo: {
          backgroundColor: '#E3F2FD',
          color: '#0D47A1',
        },
        standardError: {
          backgroundColor: '#FFEBEE',
          color: '#C62828',
        }
      }
    },
    MuiAppBar: {
      styleOverrides: {
        root: {
          boxShadow: 'none',
          backgroundColor: 'transparent',
          color: colors.deepViolet,
        }
      }
    }
  },
});

// Custom gradient styles (updated to match new palette)
export const gradients = {
  primary: 'linear-gradient(135deg, #240460 0%, #4C2889 100%)',
  secondary: 'linear-gradient(135deg, #D8BDF7 0%, #BAADDD 100%)',
  success: 'linear-gradient(135deg, #2E7D32 0%, #4CAF50 100%)',
  warm: 'linear-gradient(135deg, #ED6C02 0%, #FFA726 100%)',
  cool: 'linear-gradient(135deg, #0288D1 0%, #4FC3F7 100%)',
  hero: 'linear-gradient(135deg, #240460 0%, #D8BDF7 100%)',
  subtle: 'linear-gradient(135deg, #BAADDD 0%, #D8BDF7 100%)',
};

export default theme;
