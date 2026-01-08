/**
 * Layout Component
 * Uses separate Header, Footer, and Sidebar components
 */

import React, { useState } from 'react';
import { Box, useMediaQuery, useTheme } from '@mui/material';
import { useLocation } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import Header from './Header';
import Footer from './Footer';
import Sidebar from './Sidebar';

const Layout = ({ children, showHeader = true, showFooter = true }) => {
  const location = useLocation();
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));
  const { isAuthenticated } = useAuth();
  const [sidebarOpen, setSidebarOpen] = useState(false);

  // List of auth pages where header, footer, and sidebar should be hidden
  const authPages = [
    '/signin',
    '/signup', // If you have a separate signup page
    '/auth/forgot-password',
    '/auth/reset-password',
    '/create-profile'
  ];

  const isAuthPage = authPages.includes(location.pathname);
  const isHomePage = location.pathname === '/';
  const shouldShowHeader = showHeader && !isAuthPage && !isHomePage;
  const shouldShowFooter = showFooter && !isAuthPage && !isHomePage;
  const shouldShowSidebar = (isAuthenticated || location.pathname === '/mode-selection') && !isAuthPage && !isHomePage;

  const handleSidebarToggle = () => {
    if (isMobile) {
      setSidebarOpen(!sidebarOpen);
    } else {
      // On desktop, toggle sidebar visibility
      // For now, we'll keep it always open on desktop
      // You can implement collapse/expand functionality later if needed
      setSidebarOpen(!sidebarOpen);
    }
  };

  const handleSidebarClose = () => {
    setSidebarOpen(false);
  };

  return (
    <Box
      sx={{
        height: '100vh',
        display: 'flex',
        flexDirection: 'column',
        overflow: 'hidden',
        position: 'relative',
      }}
    >
      {/* Fixed Header */}
      <Header
        showHeader={shouldShowHeader}
        onSidebarToggle={shouldShowSidebar ? handleSidebarToggle : undefined}
      />

      {/* Main Layout Container */}
      <Box
        sx={{
          display: 'flex',
          flexGrow: 1,
          minHeight: 0,
          overflow: 'hidden',
          position: 'relative',
        }}
      >
        {/* Sidebar */}
        {shouldShowSidebar && (
          <Sidebar
            open={isMobile ? sidebarOpen : true}
            onClose={handleSidebarClose}
            variant={isMobile ? 'temporary' : 'permanent'}
          />
        )}

        {/* Main Content - Scrollable Area */}
        <Box
          component="main"
          sx={{
            flexGrow: 1,
            width: shouldShowSidebar && !isMobile ? `calc(100% - 280px)` : '100%',
            display: 'flex',
            flexDirection: 'column',
            overflowY: 'auto',
            overflowX: 'hidden',
            minHeight: 0,
            height: '100%',
            // Hide scrollbar on mobile while keeping scroll functionality
            scrollbarWidth: isMobile ? 'none' : 'thin',
            msOverflowStyle: isMobile ? 'none' : 'auto',
            WebkitOverflowScrolling: 'touch', // Smooth scrolling on iOS
            '&::-webkit-scrollbar': {
              display: isMobile ? 'none' : 'block',
              width: '8px',
            },
            '&::-webkit-scrollbar-track': {
              background: 'transparent',
            },
            '&::-webkit-scrollbar-thumb': {
              background: 'rgba(0, 0, 0, 0.2)',
              borderRadius: '4px',
              '&:hover': {
                background: 'rgba(0, 0, 0, 0.3)',
              },
            },
          }}
        >
          {/* Page Content Wrapper */}
          <Box
            sx={{
              flexGrow: 1,
              display: 'flex',
              flexDirection: 'column',
              minHeight: '100%',
              paddingTop: (shouldShowHeader && location.pathname !== '/learner')
                ? {
                  xs: `calc(56px + env(safe-area-inset-top, 0px))`,
                  sm: `calc(64px + env(safe-area-inset-top, 0px))`,
                }
                : 0,
            }}
          >
            {/* Page Content */}
            <Box
              sx={{
                flexGrow: 1,
                width: '100%',
              }}
            >
              {children}
            </Box>

            {/* Footer - Appears at bottom of content */}
            {/* <Footer showFooter={shouldShowFooter} /> */}
          </Box>
        </Box>
      </Box>
    </Box>
  );
};

export default Layout;
