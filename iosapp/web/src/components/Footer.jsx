/**
 * Footer Component - Mobile-First Design
 * Modern, compact footer optimized for mobile devices
 */

import React from 'react';
import {
  Box,
  Container,
  Typography,
  Grid,
  Link,
  IconButton,
  useMediaQuery,
  useTheme,
} from '@mui/material';
import {
  GitHub,
  Email,
  PrivacyTip,
  Help,
} from '@mui/icons-material';
import { useLocation } from 'react-router-dom';
import { useLanguage } from '../i18n/LanguageContext';
import { getTranslation } from '../i18n/translations-ui';
import { gradients } from '../theme';

const Footer = ({ showFooter = true }) => {
  const location = useLocation();
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
  const { language } = useLanguage();
  const t = (key) => getTranslation(language, key);

  const isHomePage = location.pathname === '/';

  if (!showFooter || isHomePage) {
    return null;
  }

  const footerLinks = [
    { label: 'Privacy', icon: <PrivacyTip />, href: '/privacy' },
    { label: 'Help', icon: <Help />, href: '/help' },
    { label: 'Contact', icon: <Email />, href: '/contact' },
  ];

  return (
    <Box
      component="footer"
      sx={{
        mt: 'auto',
        background: isMobile
          ? 'linear-gradient(180deg, #FFFFFF 0%, #F8FAFC 100%)'
          : 'linear-gradient(180deg, #F8FAFC 0%, #EEF2FF 100%)',
        borderTop: '1px solid rgba(0, 0, 0, 0.06)',
        py: isMobile ? 3 : 4,
        px: isMobile ? 2 : 0,
      }}
    >
      <Container maxWidth="lg">
        {isMobile ? (
          // Mobile Layout - Stacked
          <Box
            sx={{
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              gap: 2.5,
            }}
          >
            {/* Logo */}
            <Typography
              variant="h6"
              sx={{
                fontWeight: 800,
                background: gradients.primary,
                backgroundClip: 'text',
                WebkitBackgroundClip: 'text',
                WebkitTextFillColor: 'transparent',
                fontSize: '1.1rem',
              }}
            >
              Komal
            </Typography>

            {/* Quick Links */}
            <Box
              sx={{
                display: 'flex',
                gap: 2,
                justifyContent: 'center',
                flexWrap: 'wrap',
              }}
            >
              {footerLinks.map((link) => (
                <Link
                  key={link.label}
                  href={link.href}
                  sx={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 0.5,
                    color: 'text.secondary',
                    textDecoration: 'none',
                    fontSize: '0.85rem',
                    fontWeight: 500,
                    '&:hover': {
                      color: 'primary.main',
                    },
                  }}
                >
                  {React.cloneElement(link.icon, { sx: { fontSize: 16 } })}
                  {link.label}
                </Link>
              ))}
            </Box>

            {/* Copyright */}
            <Typography
              variant="caption"
              sx={{
                color: 'text.secondary',
                fontSize: '0.75rem',
                textAlign: 'center',
                lineHeight: 1.6,
              }}
            >
              © 2024 Komal
              <br />
              {t('tagline')}
            </Typography>
          </Box>
        ) : (
          // Desktop Layout - Grid
          <Grid container spacing={3} alignItems="center">
            <Grid item xs={12} md={6}>
              <Box
                sx={{
                  display: 'flex',
                  flexDirection: 'column',
                  gap: 1,
                }}
              >
                <Typography
                  variant="h6"
                  sx={{
                    fontWeight: 800,
                    background: gradients.primary,
                    backgroundClip: 'text',
                    WebkitBackgroundClip: 'text',
                    WebkitTextFillColor: 'transparent',
                    mb: 0.5,
                  }}
                >
                  Komal
                </Typography>
                <Typography
                  variant="body2"
                  sx={{
                    color: 'text.secondary',
                    fontSize: '0.85rem',
                    maxWidth: 400,
                  }}
                >
                  {t('tagline')}
                </Typography>
              </Box>
            </Grid>

            <Grid item xs={12} md={6}>
              <Box
                sx={{
                  display: 'flex',
                  justifyContent: { xs: 'flex-start', md: 'flex-end' },
                  alignItems: 'center',
                  gap: 3,
                  flexWrap: 'wrap',
                }}
              >
                {/* Links */}
                <Box
                  sx={{
                    display: 'flex',
                    gap: 2.5,
                  }}
                >
                  {footerLinks.map((link) => (
                    <Link
                      key={link.label}
                      href={link.href}
                      sx={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: 0.75,
                        color: 'text.secondary',
                        textDecoration: 'none',
                        fontSize: '0.9rem',
                        fontWeight: 500,
                        transition: 'all 0.2s ease',
                        '&:hover': {
                          color: 'primary.main',
                          transform: 'translateY(-1px)',
                        },
                      }}
                    >
                      {React.cloneElement(link.icon, { sx: { fontSize: 18 } })}
                      {link.label}
                    </Link>
                  ))}
                </Box>

                {/* Copyright */}
                <Typography
                  variant="caption"
                  sx={{
                    color: 'text.secondary',
                    fontSize: '0.8rem',
                  }}
                >
                  © 2024
                </Typography>
              </Box>
            </Grid>
          </Grid>
        )}
      </Container>
    </Box>
  );
};

export default Footer;
