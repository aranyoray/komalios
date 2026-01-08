/**
 * Language Selection Component
 * Full-screen language selection page that appears after splash screen
 * Reuses language management from LanguageContext
 */

import React, { useState } from 'react';
import {
  Box,
  Container,
  Typography,
  Grid,
  Card,
  CardContent,
  Button,
  Fade,
} from '@mui/material';
import { Language as LanguageIcon, Check as CheckIcon } from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { useLanguage } from '../i18n/LanguageContext';

const LanguageSelection = ({ onLanguageSelect }) => {
  const navigate = useNavigate();
  const { primaryLanguages, changeLanguage, currentLanguage } = useLanguage();
  const [selectedLanguage, setSelectedLanguage] = useState(null);

  const handleLanguageSelect = (languageCode) => {
    setSelectedLanguage(languageCode);
    // Use the existing changeLanguage function from LanguageContext
    // This handles localStorage, HTML lang/dir attributes, and RTL support
    changeLanguage(languageCode);
    
    // Call the callback if provided
    if (onLanguageSelect) {
      onLanguageSelect(languageCode);
    }
    
    // Navigate to onboarding page
    navigate('/');
  };

  return (
    <Fade in={true} timeout={800}>
      <Box
        sx={{
          minHeight: '100vh',
          background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          py: { xs: 3, sm: 4 },
          px: { xs: 2, sm: 3 },
        }}
      >
        <Container maxWidth="md">
          {/* Header */}
          <Box
            sx={{
              textAlign: 'center',
              mb: { xs: 4, sm: 5 },
              color: 'white',
            }}
          >
            <LanguageIcon
              sx={{
                fontSize: { xs: 48, sm: 64 },
                mb: 2,
                opacity: 0.9,
              }}
            />
            <Typography
              variant="h4"
              fontWeight={700}
              sx={{
                mb: 1,
                fontSize: { xs: '1.75rem', sm: '2.25rem', md: '2.5rem' },
              }}
            >
              Select Your Language
            </Typography>
            <Typography
              variant="body1"
              sx={{
                opacity: 0.9,
                fontSize: { xs: '0.95rem', sm: '1.1rem' },
                maxWidth: '600px',
                mx: 'auto',
              }}
            >
              Choose your preferred language to continue
            </Typography>
          </Box>

          {/* Language Grid */}
          <Grid container spacing={2} sx={{ mb: 3 }}>
            {primaryLanguages.map((language) => {
              const isSelected = selectedLanguage === language.code || currentLanguage === language.code;
              
              return (
                <Grid item xs={6} sm={4} md={3} key={language.code}>
                  <Card
                    onClick={() => handleLanguageSelect(language.code)}
                    sx={{
                      cursor: 'pointer',
                      transition: 'all 0.3s ease',
                      background: 'white',
                      borderRadius: 3,
                      height: '100%',
                      display: 'flex',
                      flexDirection: 'column',
                      border: isSelected
                        ? '3px solid #667eea'
                        : '2px solid transparent',
                      boxShadow: isSelected
                        ? '0 8px 24px rgba(102, 126, 234, 0.4)'
                        : '0 2px 8px rgba(0, 0, 0, 0.1)',
                      '&:hover': {
                        transform: 'translateY(-4px)',
                        boxShadow: '0 8px 24px rgba(102, 126, 234, 0.3)',
                        border: '2px solid #667eea',
                      },
                      '&:active': {
                        transform: 'translateY(-2px)',
                      },
                    }}
                  >
                    <CardContent
                      sx={{
                        p: { xs: 2, sm: 2.5 },
                        textAlign: 'center',
                        flex: 1,
                        display: 'flex',
                        flexDirection: 'column',
                        justifyContent: 'center',
                        alignItems: 'center',
                        position: 'relative',
                      }}
                    >
                      {isSelected && (
                        <CheckIcon
                          sx={{
                            position: 'absolute',
                            top: 8,
                            right: 8,
                            color: '#667eea',
                            fontSize: { xs: 20, sm: 24 },
                          }}
                        />
                      )}
                      <Typography
                        variant="h6"
                        fontWeight={isSelected ? 700 : 600}
                        sx={{
                          fontSize: { xs: '1rem', sm: '1.125rem' },
                          mb: 0.5,
                          color: 'text.primary',
                        }}
                      >
                        {language.nativeName}
                      </Typography>
                      <Typography
                        variant="body2"
                        color="text.secondary"
                        sx={{
                          fontSize: { xs: '0.75rem', sm: '0.875rem' },
                        }}
                      >
                        {language.name}
                      </Typography>
                    </CardContent>
                  </Card>
                </Grid>
              );
            })}
          </Grid>

          {/* Continue Button */}
          {(selectedLanguage || currentLanguage) && (
            <Fade in={selectedLanguage !== null || currentLanguage !== 'en'} timeout={500}>
              <Box sx={{ textAlign: 'center', mt: 3 }}>
                <Button
                  variant="contained"
                  size="large"
                  onClick={() => handleLanguageSelect(selectedLanguage || currentLanguage)}
                  sx={{
                    background: 'white',
                    color: '#667eea',
                    px: 5,
                    py: 1.5,
                    fontSize: '1.1rem',
                    fontWeight: 600,
                    textTransform: 'none',
                    borderRadius: 3,
                    boxShadow: '0 4px 20px rgba(0, 0, 0, 0.2)',
                    '&:hover': {
                      background: 'rgba(255, 255, 255, 0.95)',
                      transform: 'translateY(-2px)',
                      boxShadow: '0 6px 24px rgba(0, 0, 0, 0.25)',
                    },
                    transition: 'all 0.3s ease',
                  }}
                >
                  Continue
                </Button>
              </Box>
            </Fade>
          )}
        </Container>
      </Box>
    </Fade>
  );
};

export default LanguageSelection;

