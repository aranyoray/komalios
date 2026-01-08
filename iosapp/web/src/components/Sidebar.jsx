/**
 * Sidebar Component - Mobile-First Design
 * Left-side navigation menu for logged-in users
 */

import React, { useState } from 'react';
import {
  Drawer,
  Box,
  List,
  ListItem,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Divider,
  Typography,
  Avatar,
  useMediaQuery,
  useTheme,
  IconButton,
  Tooltip,
} from '@mui/material';
import {
  Home,
  Person,
  School,
  Dashboard,
  Assessment,
  Settings,
  Logout,
  Menu as MenuIcon,
  Close,
} from '@mui/icons-material';
import { useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { useLanguage } from '../i18n/LanguageContext';
import { gradients } from '../theme';
const sidebarBg = '/assets/sidebarimage.png';

const drawerWidth = 280;
const mobileDrawerWidth = 280;

const Sidebar = ({ open, onClose, variant = 'temporary' }) => {
  const navigate = useNavigate();
  const location = useLocation();
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));
  const { logout, user, currentProfile } = useAuth();
  const { t } = useLanguage();

  const handleClose = () => {
    if (onClose) {
      onClose();
    }
  };

  const handleNavigation = (path) => {
    navigate(path);
    if (isMobile && onClose) {
      onClose();
    }
  };

  const handleLogout = async () => {
    try {
      await logout();
      navigate('/');
      if (isMobile && onClose) {
        onClose();
      }
    } catch (error) {
      console.error('Logout failed:', error);
    }
  };

  const menuItems = [
    {
      id: 'home',
      label: t.nav.home,
      icon: <Home />,
      path: '/mode-selection',
      show: true,
    },
    {
      id: 'learner',
      label: t.nav.learner,
      icon: <School />,
      path: '/learner',
      show: !!currentProfile,
    },
    {
      id: 'parent-dashboard',
      label: t.nav.parentDashboard,
      icon: <Dashboard />,
      path: '/parent/dashboard',
      show: true,
    },
    {
      id: 'reports',
      label: t.nav.reports,
      icon: <Assessment />,
      path: '/parent/reports',
      show: true,
    },
    {
      id: 'profile',
      label: t.nav.profile,
      icon: <Person />,
      path: '/profile',
      show: true,
    },
  ];

  const drawerContent = (
    <Box
      sx={{
        width: isMobile ? mobileDrawerWidth : drawerWidth,
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        background: 'linear-gradient(180deg, #FFFFFF 0%, #F8FAFC 100%)',
      }}
    >
      {/* Header Section */}
      <Box
        sx={{
          p: 3,
          pt: `calc(24px + env(safe-area-inset-top, 0px))`,
          backgroundImage: `url(${sidebarBg})`,
          backgroundSize: 'cover',
          backgroundPosition: 'center',
          color: 'white',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          gap: 1.5,
          position: 'relative', // Ensure close button is positioned relative to this box
        }}
      >
        {/* Close Button - Show on mobile, or on desktop if variant is temporary */}
        {(isMobile || variant === 'temporary') && (
          <IconButton
            onClick={handleClose}
            sx={{
              position: 'absolute',
              top: `calc(8px + env(safe-area-inset-top, 0px))`,
              right: 8,
              color: 'white',
              '&:hover': {
                background: 'rgba(255, 255, 255, 0.2)',
              },
            }}
            aria-label={t.nav.closeMenu}
          >
            <Close />
          </IconButton>
        )}
        <Avatar
          sx={{
            width: 64,
            height: 64,
            background: 'rgba(255, 255, 255, 0.2)',
            border: '2px solid rgba(255, 255, 255, 0.3)',
            fontSize: '1.5rem',
            fontWeight: 700,
          }}
        >
          {user?.email?.charAt(0).toUpperCase() || 'U'}
        </Avatar>
        <Typography variant="h6" fontWeight={700} textAlign="center">
          Komal
        </Typography>
        {user?.email && (
          <Typography
            variant="body2"
            sx={{
              opacity: 0.9,
              fontSize: '0.85rem',
              textAlign: 'center',
              maxWidth: '100%',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
            }}
          >
            {user.email}
          </Typography>
        )}
      </Box>

      {/* Navigation Items */}
      <Box sx={{ flexGrow: 1, overflow: 'auto', py: 2 }}>
        <List sx={{ px: 1.5 }}>
          {menuItems
            .filter((item) => item.show)
            .map((item) => {
              const isActive = location.pathname === item.path ||
                (item.path === '/profile' && location.pathname === '/profile');

              return (
                <ListItem key={item.id} disablePadding sx={{ mb: 0.5 }}>
                  <ListItemButton
                    onClick={() => handleNavigation(item.path)}
                    sx={{
                      borderRadius: 2,
                      py: 1.5,
                      px: 2,
                      backgroundColor: isActive
                        ? 'rgba(99, 102, 241, 0.1)'
                        : 'transparent',
                      '&:hover': {
                        backgroundColor: isActive
                          ? 'rgba(99, 102, 241, 0.15)'
                          : 'rgba(0, 0, 0, 0.04)',
                      },
                    }}
                  >
                    <ListItemIcon
                      sx={{
                        minWidth: 40,
                        color: isActive ? 'primary.main' : 'text.secondary',
                      }}
                    >
                      {item.icon}
                    </ListItemIcon>
                    <ListItemText
                      primary={item.label}
                      primaryTypographyProps={{
                        fontWeight: isActive ? 600 : 500,
                        fontSize: '0.95rem',
                        color: isActive ? 'primary.main' : 'text.primary',
                      }}
                    />
                  </ListItemButton>
                </ListItem>
              );
            })}
        </List>
      </Box>

      {/* Footer Section */}
      <Box sx={{ p: 2, borderTop: '1px solid rgba(0, 0, 0, 0.06)' }}>
        <List sx={{ px: 1.5 }}>
          <ListItem disablePadding>
            <ListItemButton
              onClick={handleLogout}
              sx={{
                borderRadius: 2,
                py: 1.5,
                px: 2,
                color: 'error.main',
                '&:hover': {
                  backgroundColor: 'rgba(211, 47, 47, 0.08)',
                },
              }}
            >
              <ListItemIcon sx={{ minWidth: 40, color: 'error.main' }}>
                <Logout />
              </ListItemIcon>
              <ListItemText
                primary={t.nav.logout}
                primaryTypographyProps={{
                  fontWeight: 500,
                  fontSize: '0.95rem',
                }}
              />
            </ListItemButton>
          </ListItem>
        </List>
      </Box>
    </Box>
  );

  if (isMobile) {
    return (
      <Drawer
        variant="temporary"
        open={open}
        onClose={handleClose}
        ModalProps={{
          keepMounted: true, // Better open performance on mobile
        }}
        sx={{
          display: { xs: 'block', md: 'none' },
          '& .MuiDrawer-paper': {
            boxSizing: 'border-box',
            width: mobileDrawerWidth,
            borderRight: 'none',
            boxShadow: '4px 0 24px rgba(0, 0, 0, 0.1)',
          },
        }}
      >
        {drawerContent}
      </Drawer>
    );
  }

  return (
    <Drawer
      variant={variant}
      open={open !== undefined ? open : true}
      sx={{
        width: drawerWidth,
        flexShrink: 0,
        display: { xs: 'none', md: 'block' },
        '& .MuiDrawer-paper': {
          width: drawerWidth,
          boxSizing: 'border-box',
          borderRight: '1px solid rgba(0, 0, 0, 0.06)',
          boxShadow: 'none',
        },
      }}
    >
      {drawerContent}
    </Drawer>
  );
};

// Sidebar Toggle Button Component
export const SidebarToggle = ({ onClick }) => {
  const { t } = useLanguage();
  return (
    <Tooltip title={t.nav.openMenu}>
      <IconButton
        onClick={onClick}
        sx={{
          mr: 2,
          color: 'text.primary',
          '&:hover': {
            background: 'rgba(99, 102, 241, 0.08)',
          },
        }}
      >
        <MenuIcon />
      </IconButton>
    </Tooltip>
  );
};

export default Sidebar;

