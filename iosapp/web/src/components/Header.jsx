/**
 * Header Component - Mobile-First Design
 * Modern mobile app design with optimized touch targets and spacing
 */

import React, { useState } from 'react';
import {
  AppBar,
  Toolbar,
  Typography,
  Button,
  IconButton,
  Menu,
  MenuItem,
  Box,
  Container,
  useScrollTrigger,
  Slide,
  ListItemText,
  Divider,
  Chip,
  useMediaQuery,
  useTheme,
} from '@mui/material';
import {
  AccountCircle,
  Logout,
  Home,
  Menu as MenuIcon,
} from '@mui/icons-material';
// Sidebar toggle is handled in Layout component
import { useNavigate, useLocation } from 'react-router-dom';
import { useLanguage } from '../i18n/LanguageContext';
import { getTranslation } from '../i18n/translations-ui';
import { useAuth } from '../contexts/AuthContext';
const monkeyLogo = '/assets/finalstrokemonkey.png';

// Primary gradient used throughout the app
const primaryGradient = 'linear-gradient(135deg, #6366F1 0%, #8B5CF6 100%)';

// Hide AppBar on scroll down, show on scroll up
function HideOnScroll({ children }) {
  const trigger = useScrollTrigger({
    threshold: 100,
  });
  return (
    <Slide appear={false} direction="down" in={!trigger}>
      {children}
    </Slide>
  );
}

const Header = ({ showHeader = true, onSidebarToggle }) => {
  const navigate = useNavigate();
  const location = useLocation();
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
  const { language } = useLanguage();
  const { isAuthenticated } = useAuth();

  const t = (key) => getTranslation(language, key);


  const isAuthPage = ['/signin', '/create-profile'].includes(location.pathname);
  const isHomePage = location.pathname === '/';

  if (!showHeader || isAuthPage || isHomePage) {
    return null;
  }

  return (
    <HideOnScroll>
      <AppBar
        position="fixed"
        elevation={0}
        sx={{
          top: 0, // Ensure header starts at the very top (behind status bar)
          left: 0,
          right: 0,
          background: location.pathname === '/learner'
            ? 'transparent'
            : (isMobile ? 'rgba(255, 255, 255, 0.98)' : 'rgba(255, 255, 255, 0.95)'),
          backdropFilter: location.pathname === '/learner' ? 'none' : 'blur(10px)',
          WebkitBackdropFilter: location.pathname === '/learner' ? 'none' : 'blur(20px)',
          borderBottom: 'none',
          boxShadow: 'none',
          borderBottomLeftRadius: 0,
          borderBottomRightRadius: 0,
          zIndex: 1100,
          // Extend header behind status bar (edge-to-edge)
          // Add safe-area padding so content doesn't overlap with status bar icons
          paddingTop: 'env(safe-area-inset-top, 0px)',
          minHeight: 'calc(64px + env(safe-area-inset-top, 0px))',
          // Ensure header extends to top edge (no margin)
          marginTop: 0,
          marginLeft: 0,
          marginRight: 0,
          // Ensure header covers full width including behind status bar
          width: '100%',
        }}
      >
        <Container maxWidth="lg" disableGutters={isMobile}>
          <Toolbar
            sx={{
              py: isMobile ? 1 : 1.5,
              px: isMobile ? 2 : 0,
              minHeight: isMobile ? 56 : 64,
              justifyContent: 'space-between',
              position: 'relative',
              // paddingTop: `calc(${isMobile ? 1 : 1.5} * 8px + env(safe-area-inset-top, 0px))`,
            }}
          >
            {/* Left Section - Menu/Home Icon */}
            <Box
              sx={{
                display: 'flex',
                alignItems: 'center',
                flex: 1,
                justifyContent: 'flex-start',
              }}
            >
              {/* Burger Menu Icon (for authenticated users or mode-selection page) */}
              {(isAuthenticated || location.pathname === '/mode-selection') && onSidebarToggle && (
                <IconButton
                  onClick={onSidebarToggle}
                  sx={{
                    p: isMobile ? 0.75 : 1,
                    color: location.pathname === '/learner' ? 'white' : 'text.primary',
                    '&:hover': {
                      background: 'rgba(99, 102, 241, 0.08)',
                    },
                  }}
                  aria-label="Open menu"
                >
                  <MenuIcon sx={{ fontSize: isMobile ? 24 : 28 }} />
                </IconButton>
              )}

              {/* Home Icon (only show if not authenticated or no sidebar toggle, AND not on mode-selection) */}
              {(!isAuthenticated || !onSidebarToggle) && location.pathname !== '/mode-selection' && (
                <IconButton
                  onClick={() => navigate('/mode-selection')}
                  sx={{
                    p: isMobile ? 0.75 : 1,
                    '&:hover': {
                      background: 'rgba(99, 102, 241, 0.08)',
                    },
                  }}
                  aria-label="Home"
                >
                  <Home sx={{ fontSize: isMobile ? 20 : 24, color: location.pathname === '/learner' ? 'white' : 'primary.main' }} />
                </IconButton>
              )}
            </Box>

            {/* Center Section - Komal Logo */}
            <Box
              sx={{
                position: 'absolute',
                left: '50%',
                transform: 'translateX(-50%)',
                display: 'flex',
                alignItems: 'center',
              }}
            >
              <Typography
                variant="h6"
                onClick={() => navigate('/mode-selection')}
                sx={{
                  fontWeight: 900,
                  color: location.pathname === '/learner' ? 'white' : 'primary.main',
                  cursor: 'pointer',
                  fontSize: isMobile ? '1.5rem' : '1.8rem',
                  letterSpacing: '0.05em',
                  textTransform: 'uppercase',
                  '&:hover': {
                    opacity: 0.8,
                  },
                }}
              >
                Komal
              </Typography>
            </Box>

            {/* Right Section */}
            <Box
              sx={{
                display: 'flex',
                alignItems: 'center',
                gap: isMobile ? 0.5 : 1.5,
                flex: 1,
                justifyContent: 'flex-end',
              }}
            >
              {/* Sign In Button (only show if not authenticated and not on mode-selection) */}
              {!isAuthenticated && location.pathname !== '/mode-selection' && (
                <Button
                  variant="contained"
                  onClick={() => navigate('/signin')}
                  sx={{
                    background: primaryGradient,
                    fontSize: isMobile ? '0.85rem' : '0.9rem',
                    px: isMobile ? 2 : 2.5,
                    py: isMobile ? 0.75 : 0.875,
                    minHeight: isMobile ? 40 : 44,
                    borderRadius: 2,
                    fontWeight: 600,
                    textTransform: 'none',
                    boxShadow: '0 4px 12px rgba(99, 102, 241, 0.3)',
                    '&:hover': {
                      background: primaryGradient,
                      opacity: 0.9,
                      boxShadow: '0 6px 16px rgba(99, 102, 241, 0.4)',
                      transform: 'translateY(-1px)',
                    },
                    '&:active': {
                      transform: 'translateY(0)',
                    },
                  }}
                >
                  {isMobile ? t('signIn').split(' ')[0] : t('signIn')}
                </Button>
              )}
            </Box>
            {/* Monkey Mascot Image */}
            {['/learner', '/parent/dashboard', '/parent/reports', '/profile', '/mode-selection'].includes(location.pathname) && (
              <Box
                component="img"
                src={monkeyLogo}
                alt="Monkey Mascot"
                sx={{
                  height: isMobile ? 45 : 55,
                  width: 'auto',
                  objectFit: 'contain',
                  filter: 'drop-shadow(0 4px 8px rgba(0,0,0,0.2))',
                }}
              />
            )}
          </Toolbar>
        </Container>
      </AppBar>
    </HideOnScroll>
  );
};

export default Header;
