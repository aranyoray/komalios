/**
 * Multi-Provider Authentication Form
 * Supports: Email, Phone, Google, Apple
 */

import React, { useState } from 'react';
import {
  Box,
  Button,
  TextField,
  Typography,
  Divider,
  Alert,
  IconButton,
  InputAdornment,
  Tab,
  Tabs,
  Paper
} from '@mui/material';
import {
  Google as GoogleIcon,
  Apple as AppleIcon,
  Phone as PhoneIcon,
  Email as EmailIcon,
  Visibility,
  VisibilityOff
} from '@mui/icons-material';
import {
  signUpWithEmail,
  signInWithEmail,
  signInWithPhone,
  verifyPhoneOTP,
  signInWithOAuth
} from '../../auth/supabaseAuth';
import { CompactLanguageSelector } from '../LanguageSelector';
import { useLanguage } from '../../i18n/LanguageContext';

export default function MultiAuthForm({ onSuccess }) {
  const { t } = useLanguage(); // Get translations
  const [mode, setMode] = useState('signin'); // 'signin' or 'signup'
  const [authMethod, setAuthMethod] = useState(0); // 0=email, 1=phone
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [phone, setPhone] = useState('');
  const [otp, setOtp] = useState('');
  const [otpSent, setOtpSent] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const handleEmailAuth = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    setSuccess('');

    try {
      if (mode === 'signup') {
        await signUpWithEmail(email, password);
        setSuccess('Check your email for verification link!');
      } else {
        const { session } = await signInWithEmail(email, password);
        if (session) {
          onSuccess?.(session.user);
        }
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handlePhoneAuth = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      if (!otpSent) {
        // Send OTP
        await signInWithPhone(phone);
        setOtpSent(true);
        setSuccess('OTP sent to your phone!');
      } else {
        // Verify OTP
        const { session } = await verifyPhoneOTP(phone, otp);
        if (session) {
          onSuccess?.(session.user);
        }
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleOAuthSignIn = async (provider) => {
    setLoading(true);
    setError('');

    try {
      await signInWithOAuth(provider);
      // Redirect happens automatically
    } catch (err) {
      setError(err.message);
      setLoading(false);
    }
  };

  return (
    <Paper elevation={3} sx={{ p: 4, maxWidth: 450, mx: 'auto', mt: 8 }}>
      {/* Language Selector */}
      <CompactLanguageSelector showLabel={true} />

      <Typography variant="h4" gutterBottom align="center">
        Welcome to Komal
      </Typography>

      {/* Mode Toggle */}
      <Box sx={{ mb: 3, display: 'flex', gap: 1 }}>
        <Button
          fullWidth
          variant={mode === 'signin' ? 'contained' : 'outlined'}
          onClick={() => setMode('signin')}
        >
          {t.auth.signIn}
        </Button>
        <Button
          fullWidth
          variant={mode === 'signup' ? 'contained' : 'outlined'}
          onClick={() => setMode('signup')}
        >
          {t.auth.signUp}
        </Button>
      </Box>

      {/* OAuth Providers */}
      <Box sx={{ mb: 3 }}>
        <Button
          fullWidth
          variant="outlined"
          startIcon={<GoogleIcon />}
          onClick={() => handleOAuthSignIn('google')}
          disabled={loading}
          sx={{ mb: 1 }}
        >
          {t.auth.continueWithGoogle}
        </Button>

        <Button
          fullWidth
          variant="outlined"
          startIcon={<AppleIcon />}
          onClick={() => handleOAuthSignIn('apple')}
          disabled={loading}
          sx={{ mb: 1, bgcolor: '#000', color: '#fff', '&:hover': { bgcolor: '#333' } }}
        >
          {t.auth.continueWithApple}
        </Button>
      </Box>

      <Divider sx={{ my: 2 }}>OR</Divider>

      {/* Auth Method Tabs */}
      <Tabs
        value={authMethod}
        onChange={(e, newValue) => {
          setAuthMethod(newValue);
          setOtpSent(false);
          setError('');
        }}
        sx={{ mb: 2 }}
      >
        <Tab icon={<EmailIcon />} label={t.auth.email} />
        <Tab icon={<PhoneIcon />} label={t.auth.phoneNumber} />
      </Tabs>

      {/* Email/Password Form */}
      {authMethod === 0 && (
        <form onSubmit={handleEmailAuth}>
          <TextField
            fullWidth
            label={t.auth.email}
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
            sx={{ mb: 2 }}
          />

          <TextField
            fullWidth
            label={t.auth.password}
            type={showPassword ? 'text' : 'password'}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
            sx={{ mb: 2 }}
            InputProps={{
              endAdornment: (
                <InputAdornment position="end">
                  <IconButton
                    onClick={() => setShowPassword(!showPassword)}
                    edge="end"
                  >
                    {showPassword ? <VisibilityOff /> : <Visibility />}
                  </IconButton>
                </InputAdornment>
              )
            }}
          />

          <Button
            type="submit"
            fullWidth
            variant="contained"
            disabled={loading}
            sx={{ mb: 2 }}
          >
            {loading ? t.messages.loading : mode === 'signin' ? t.auth.signIn : t.auth.signUp}
          </Button>
        </form>
      )}

      {/* Phone/OTP Form */}
      {authMethod === 1 && (
        <form onSubmit={handlePhoneAuth}>
          <TextField
            fullWidth
            label={t.auth.phoneNumber}
            type="tel"
            placeholder="+1234567890"
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            required
            disabled={otpSent}
            sx={{ mb: 2 }}
            helperText="Include country code (e.g., +1 for US)"
          />

          {otpSent && (
            <TextField
              fullWidth
              label={t.auth.enterOTP}
              type="text"
              value={otp}
              onChange={(e) => setOtp(e.target.value)}
              required
              sx={{ mb: 2 }}
              helperText="Enter the 6-digit code sent to your phone"
            />
          )}

          <Button
            type="submit"
            fullWidth
            variant="contained"
            disabled={loading}
            sx={{ mb: 2 }}
          >
            {loading ? t.messages.loading : otpSent ? t.auth.verifyOTP : t.auth.sendOTP}
          </Button>

          {otpSent && (
            <Button
              fullWidth
              variant="text"
              onClick={() => {
                setOtpSent(false);
                setOtp('');
              }}
            >
              Use Different Phone Number
            </Button>
          )}
        </form>
      )}

      {/* Error/Success Messages */}
      {error && (
        <Alert severity="error" sx={{ mt: 2 }}>
          {error}
        </Alert>
      )}

      {success && (
        <Alert severity="success" sx={{ mt: 2 }}>
          {success}
        </Alert>
      )}
    </Paper>
  );
}
