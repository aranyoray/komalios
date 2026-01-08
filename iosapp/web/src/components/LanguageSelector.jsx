/**
 * Language Selector Component
 *
 * Displays all 24 Indian languages in their native scripts.
 * Used in sign-up/sign-in screens and settings.
 */

import React, { useState } from 'react';
import {
  Dialog,
  DialogTitle,
  DialogContent,
  List,
  ListItem,
  ListItemButton,
  ListItemText,
  IconButton,
  Box,
  Typography,
  TextField,
  InputAdornment,
  Chip,
} from '@mui/material';
import {
  Language as LanguageIcon,
  Close as CloseIcon,
  Search as SearchIcon,
  Check as CheckIcon,
} from '@mui/icons-material';
import { useLanguage, getPrimaryLanguages } from '../i18n/LanguageContext';

/**
 * Language Selector Button Component
 *
 * Shows current language and opens selector dialog
 *
 * @param {Object} props
 * @param {string} props.variant - 'button' | 'chip' | 'text'
 * @param {boolean} props.showIcon - Show language icon
 * @param {string} props.size - 'small' | 'medium' | 'large'
 */
export function LanguageSelector({ variant = 'button', showIcon = true, size = 'medium' }) {
  const { currentLanguage, getCurrentLanguageName, changeLanguage, t } = useLanguage();
  const [dialogOpen, setDialogOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');

  // Use primary languages (same as LanguageSelection page)
  const primaryLanguages = getPrimaryLanguages();

  const handleOpen = () => setDialogOpen(true);
  const handleClose = () => {
    setDialogOpen(false);
    setSearchQuery('');
  };

  const handleLanguageSelect = (languageCode) => {
    changeLanguage(languageCode);
    handleClose();
  };

  // Filter languages based on search
  const filteredLanguages = primaryLanguages.filter(lang =>
    lang.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    lang.nativeName.toLowerCase().includes(searchQuery.toLowerCase())
  );

  // Render based on variant
  const renderTrigger = () => {
    switch (variant) {
      case 'chip':
        return (
          <Chip
            icon={showIcon ? <LanguageIcon /> : undefined}
            label={getCurrentLanguageName()}
            onClick={handleOpen}
            clickable
            size={size}
          />
        );

      case 'text':
        return (
          <Box
            onClick={handleOpen}
            sx={{
              display: 'flex',
              alignItems: 'center',
              gap: 1,
              cursor: 'pointer',
              '&:hover': { opacity: 0.7 },
            }}
          >
            {showIcon && <LanguageIcon fontSize={size} />}
            <Typography variant="body1">{getCurrentLanguageName()}</Typography>
          </Box>
        );

      default: // button
        return (
          <IconButton onClick={handleOpen} size={size} title="Change Language">
            <LanguageIcon />
          </IconButton>
        );
    }
  };

  return (
    <>
      {renderTrigger()}

      <Dialog
        open={dialogOpen}
        onClose={handleClose}
        maxWidth="sm"
        fullWidth
        PaperProps={{
          sx: {
            maxHeight: '80vh',
          },
        }}
      >
        <DialogTitle
          sx={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            pb: 1,
          }}
        >
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
            <LanguageIcon />
            <Typography variant="h6">{t.common.selectLanguage}</Typography>
          </Box>
          <IconButton onClick={handleClose} size="small">
            <CloseIcon />
          </IconButton>
        </DialogTitle>

        <DialogContent dividers>
          {/* Search bar */}
          <TextField
            fullWidth
            placeholder={t.common.searchLanguages}
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            size="small"
            sx={{ mb: 2 }}
            InputProps={{
              startAdornment: (
                <InputAdornment position="start">
                  <SearchIcon />
                </InputAdornment>
              ),
            }}
          />

          {/* Language list */}
          <List sx={{ pt: 0 }}>
            {filteredLanguages.map((lang) => {
              const isSelected = currentLanguage === lang.code;

              return (
                <ListItem key={lang.code} disablePadding>
                  <ListItemButton
                    onClick={() => handleLanguageSelect(lang.code)}
                    selected={isSelected}
                    sx={{
                      borderRadius: 1,
                      mb: 0.5,
                      '&.Mui-selected': {
                        backgroundColor: 'primary.light',
                        '&:hover': {
                          backgroundColor: 'primary.light',
                        },
                      },
                    }}
                  >
                    <ListItemText
                      primary={
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                          {/* Native script name - most prominent */}
                          <Typography
                            variant="h6"
                            component="span"
                            sx={{
                              fontWeight: isSelected ? 600 : 400,
                              fontSize: '1.1rem',
                            }}
                          >
                            {lang.nativeName}
                          </Typography>
                          {isSelected && <CheckIcon color="primary" fontSize="small" />}
                        </Box>
                      }
                      secondary={
                        <Typography variant="caption" color="text.secondary">
                          {lang.name}
                        </Typography>
                      }
                    />
                  </ListItemButton>
                </ListItem>
              );
            })}
          </List>

          {filteredLanguages.length === 0 && (
            <Box sx={{ textAlign: 'center', py: 4 }}>
              <Typography variant="body2" color="text.secondary">
                {t.common.noLanguagesFound}
              </Typography>
            </Box>
          )}
        </DialogContent>
      </Dialog>
    </>
  );
}

/**
 * Compact Language Selector for Auth Screens
 *
 * Shows language name prominently above sign-in/sign-up forms
 *
 * @param {Object} props
 * @param {boolean} props.showLabel - Show "Select Language" label
 */
export function CompactLanguageSelector({ showLabel = true }) {
  const { getCurrentLanguageName } = useLanguage();

  return (
    <Box
      sx={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: 1,
        mb: 2,
      }}
    >
      {showLabel && (
        <Typography variant="caption" color="text.secondary">
          Language / भाषा / ভাষা
        </Typography>
      )}
      <LanguageSelector variant="chip" showIcon={true} size="medium" />
    </Box>
  );
}

/**
 * USAGE EXAMPLES:
 *
 * // 1. In navigation bar (icon button)
 * <LanguageSelector />
 *
 * // 2. In settings (chip style)
 * <LanguageSelector variant="chip" size="medium" />
 *
 * // 3. In auth screens (compact with label)
 * <CompactLanguageSelector />
 *
 * // 4. As text with icon
 * <LanguageSelector variant="text" showIcon={true} />
 */
