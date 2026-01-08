/**
 * Main App Component for Komal
 * Knowledge-Oriented Mental-Health & Affective Learning
 */

import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate, useNavigate } from 'react-router-dom';
import { ThemeProvider } from '@mui/material/styles';
import { CssBaseline, Box, Typography, Button, CircularProgress } from '@mui/material';
import { Capacitor } from '@capacitor/core';
import { App as CapacitorApp } from '@capacitor/app';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import { LanguageProvider } from './i18n/LanguageContext';
import theme from './theme';
import Layout from './components/Layout';
import SplashScreen from './components/SplashScreen';

// Error Boundary Component
class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    console.error('App Error:', error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        <Box sx={{
          p: 4,
          textAlign: 'center',
          minHeight: '100vh',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center'
        }}>
          <Typography variant="h4" color="error" gutterBottom>
            Something went wrong
          </Typography>
          <Typography variant="body1" color="text.secondary" sx={{ mb: 3 }}>
            {this.state.error?.message || 'An unexpected error occurred'}
          </Typography>
          <Button
            variant="contained"
            onClick={() => window.location.reload()}
            size="large"
          >
            Reload Page
          </Button>
        </Box>
      );
    }
    return this.props.children;
  }
}

// Auth pages
import SignIn from './pages/Auth/SignIn';
import ForgotPassword from './pages/Auth/ForgotPassword';
import ResetPassword from './pages/Auth/ResetPassword';
import EmailConfirm from './pages/Auth/EmailConfirm';
import ProfileSelect from './pages/Auth/ProfileSelect';
import CreateProfile from './pages/Auth/CreateProfile';

// Learner pages
import LearnerHome from './pages/Learner/Home';

// Session pages
import SessionFlow from './pages/Session/SessionFlow';

// Parent pages
import ParentDashboard from './pages/Parent/Dashboard';
import ParentReports from './pages/Parent/Reports';

// Profile page
import Profile from './pages/Profile/Profile';
import EditLearnerProfile from './pages/Profile/EditLearnerProfile';

// Common pages
import Home from './pages/Home';

// Language selection
import LanguageSelection from './components/LanguageSelection';
// Mode selection
import ModeSelection from './components/ModeSelection';

// Loading component
const LoadingScreen = () => (
  <Box sx={{
    minHeight: '100vh',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    background: 'linear-gradient(135deg, #F8FAFC 0%, #EEF2FF 100%)',
  }}>
    <CircularProgress size={48} />
  </Box>
);

// Protected route wrapper
const ProtectedRoute = ({ children, requireProfile = false }) => {
  const { isAuthenticated, currentProfile, isLoading } = useAuth();

  if (isLoading) {
    return <LoadingScreen />;
  }

  if (!isAuthenticated) {
    return <Navigate to="/signin" />;
  }

  if (requireProfile && !currentProfile) {
    return <Navigate to="/profile-select" />;
  }

  return children;
};

// Wrapper component for routes that need Layout
function LayoutWrapper({ children }) {
  return <Layout>{children}</Layout>;
}

function AppRoutes() {
  const navigate = useNavigate();
  const [hasCheckedLanguage, setHasCheckedLanguage] = React.useState(false);

  // Check if language has been selected on initial load
  React.useEffect(() => {
    if (hasCheckedLanguage) return;

    const savedLanguage = localStorage.getItem('komal_app_language');
    const currentPath = window.location.pathname;

    // Only redirect if no language is saved and we're not already on select-language or other auth pages
    if (!savedLanguage &&
      currentPath !== '/select-language' &&
      !currentPath.startsWith('/auth/') &&
      !currentPath.startsWith('/signin')) {
      navigate('/select-language', { replace: true });
    }
    setHasCheckedLanguage(true);
  }, [navigate, hasCheckedLanguage]);

  const handleLanguageSelect = (languageCode) => {
    navigate('/', { replace: true });
  };

  return (
    <Routes>
      {/* Language selection route - outside Layout for full-screen experience */}
      <Route
        path="/select-language"
        element={<LanguageSelection onLanguageSelect={handleLanguageSelect} />}
      />
      <Route
        path="/mode-selection"
        element={<LayoutWrapper><ModeSelection /></LayoutWrapper>}
      />
      {/* All other routes inside Layout */}
      <Route path="/" element={<LayoutWrapper><Home /></LayoutWrapper>} />
      <Route path="/signin" element={<LayoutWrapper><SignIn /></LayoutWrapper>} />
      <Route path="/auth/forgot-password" element={<LayoutWrapper><ForgotPassword /></LayoutWrapper>} />
      <Route path="/auth/reset-password" element={<LayoutWrapper><ResetPassword /></LayoutWrapper>} />
      <Route path="/auth/confirm" element={<LayoutWrapper><EmailConfirm /></LayoutWrapper>} />

      {/* Auth flow routes */}
      <Route
        path="/profile-select"
        element={
          <LayoutWrapper>
            <ProtectedRoute>
              <ProfileSelect />
            </ProtectedRoute>
          </LayoutWrapper>
        }
      />
      <Route
        path="/create-profile"
        element={
          <LayoutWrapper>
            <ProtectedRoute>
              <CreateProfile />
            </ProtectedRoute>
          </LayoutWrapper>
        }
      />

      {/* Learner routes */}
      <Route
        path="/learner"
        element={
          <LayoutWrapper>
            <ProtectedRoute requireProfile>
              <LearnerHome />
            </ProtectedRoute>
          </LayoutWrapper>
        }
      />

      {/* Session routes - No Layout wrapper for full-screen experience */}
      <Route
        path="/session/:learnerId?"
        element={
          <ProtectedRoute requireProfile>
            <SessionFlow />
          </ProtectedRoute>
        }
      />

      {/* Parent routes */}
      <Route
        path="/parent/dashboard"
        element={
          <LayoutWrapper>
            <ProtectedRoute requireProfile>
              <ParentDashboard />
            </ProtectedRoute>
          </LayoutWrapper>
        }
      />
      <Route
        path="/parent/reports"
        element={
          <LayoutWrapper>
            <ProtectedRoute requireProfile>
              <ParentReports />
            </ProtectedRoute>
          </LayoutWrapper>
        }
      />

      {/* Profile routes */}
      <Route
        path="/profile"
        element={
          <LayoutWrapper>
            <ProtectedRoute>
              <Profile />
            </ProtectedRoute>
          </LayoutWrapper>
        }
      />
      <Route
        path="/profile/edit-learner/:learnerId?"
        element={
          <LayoutWrapper>
            <ProtectedRoute>
              <EditLearnerProfile />
            </ProtectedRoute>
          </LayoutWrapper>
        }
      />

      {/* Fallback */}
      <Route path="*" element={<LayoutWrapper><Navigate to="/" /></LayoutWrapper>} />
    </Routes>
  );
}

// Deep link handler component
function DeepLinkHandler() {
  const navigate = useNavigate();

  React.useEffect(() => {
    // Only handle deep links on native platforms
    if (!Capacitor.isNativePlatform()) {
      return;
    }

    // Handle app URL open (deep link)
    const handleAppUrl = async (event) => {
      console.log('[App] Deep link received:', event.url);

      try {
        const url = new URL(event.url);

        // Handle email confirmation deep link
        // Support multiple schemes:
        // - com.komalkids.app://auth/confirm (app ID based)
        // - komal://auth/confirm (custom scheme)
        // - https://komal.app/auth/confirm (HTTPS)
        if (url.pathname === '/auth/confirm' ||
          (url.host === 'auth' && url.pathname === '/confirm') ||
          url.pathname.includes('/auth/confirm')) {

          // Preserve hash fragments (Supabase sends tokens in hash)
          const hash = url.hash || '';
          const search = url.search || '';

          // Navigate to email confirmation page with all parameters
          const fullPath = `/auth/confirm${search}${hash}`;
          console.log('[App] Navigating to:', fullPath);
          navigate(fullPath);
        }
      } catch (error) {
        console.error('[App] Error handling deep link:', error);
        // If URL parsing fails, try to extract path manually
        if (event.url.includes('/auth/confirm')) {
          const hashIndex = event.url.indexOf('#');
          const queryIndex = event.url.indexOf('?');
          const pathIndex = event.url.indexOf('/auth/confirm');

          if (pathIndex !== -1) {
            const path = event.url.substring(pathIndex);
            console.log('[App] Navigating to (fallback):', path);
            navigate(path);
          }
        }
      }
    };

    // Listen for app URL open events
    const listener = CapacitorApp.addListener('appUrlOpen', handleAppUrl);

    // Check if app was opened via deep link
    CapacitorApp.getLaunchUrl().then((result) => {
      if (result?.url) {
        handleAppUrl({ url: result.url });
      }
    }).catch((error) => {
      console.log('[App] No launch URL:', error);
    });

    return () => {
      listener.remove();
    };
  }, [navigate]);

  return null;
}

function App() {
  // Track if splash screen has completed
  // Use sessionStorage so splash only plays once per browser session
  const [showSplash, setShowSplash] = useState(() => {
    return sessionStorage.getItem('komal_splash_shown') !== 'true';
  });

  const handleSplashComplete = () => {
    sessionStorage.setItem('komal_splash_shown', 'true');
    setShowSplash(false);
  };

  // Show splash screen first, then the main app
  if (showSplash) {
    return (
      <ThemeProvider theme={theme}>
        <CssBaseline />
        <SplashScreen onComplete={handleSplashComplete} />
      </ThemeProvider>
    );
  }

  return (
    <ErrorBoundary>
      <ThemeProvider theme={theme}>
        <CssBaseline />
        <LanguageProvider>
          <AuthProvider>
            <Router>
              <DeepLinkHandler />
              <AppRoutes />
            </Router>
          </AuthProvider>
        </LanguageProvider>
      </ThemeProvider>
    </ErrorBoundary>
  );
}

export default App;
