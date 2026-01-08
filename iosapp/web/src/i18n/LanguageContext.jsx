/**
 * Language Context Provider
 *
 * Provides language selection and translation capabilities throughout the app.
 * Persists language selection in localStorage.
 */

import React, { createContext, useContext, useState, useEffect, useMemo } from 'react';
import { getTranslation, supportedLanguages } from './translations/index';

const LanguageContext = createContext();

/**
 * Primary languages for language selection screens
 * Limited to the most commonly used languages
 */
const PRIMARY_LANGUAGE_CODES = [
  'en', // English
  'as', // Assamese
  'bn', // Bengali
  'gu', // Gujarati
  'hi', // Hindi
  'kn', // Kannada
  'ml', // Malayalam
  'mr', // Marathi
  'ne', // Nepali
  'or', // Odia
  'pa', // Punjabi
  'ur', // Urdu
  'sd', // Sindhi
  'ta', // Tamil
  'te', // Telugu
];

/**
 * Get filtered list of primary languages
 */
export const getPrimaryLanguages = () => {
  return supportedLanguages.filter(lang => PRIMARY_LANGUAGE_CODES.includes(lang.code));
};

/**
 * Language Provider Component
 *
 * Wraps the app to provide language context
 *
 * @param {Object} props
 * @param {React.ReactNode} props.children
 */
export function LanguageProvider({ children }) {
  // Default to English
  const [currentLanguage, setCurrentLanguage] = useState('en');
  const [translations, setTranslations] = useState(getTranslation('en'));

  // Load saved language preference on mount
  useEffect(() => {
    const savedLanguage = localStorage.getItem('komal_app_language');
    if (savedLanguage && supportedLanguages.some(lang => lang.code === savedLanguage)) {
      changeLanguage(savedLanguage);
    }
  }, []);

  /**
   * Change the current language
   *
   * @param {string} languageCode - Language code (e.g., 'hi', 'bn', 'ta')
   */
  const changeLanguage = (languageCode) => {
    const newTranslations = getTranslation(languageCode);
    setCurrentLanguage(languageCode);
    setTranslations(newTranslations);

    // Persist to localStorage
    localStorage.setItem('komal_app_language', languageCode);

    // Update HTML lang attribute for accessibility
    document.documentElement.lang = languageCode;

    // Set direction for RTL languages (Urdu, Kashmiri, Sindhi)
    const rtlLanguages = ['ur', 'ks', 'sd'];
    document.documentElement.dir = rtlLanguages.includes(languageCode) ? 'rtl' : 'ltr';
  };

  /**
   * Get language info by code
   *
   * @param {string} languageCode
   * @returns {Object} Language info
   */
  const getLanguageInfo = (languageCode) => {
    return supportedLanguages.find(lang => lang.code === languageCode) || supportedLanguages[0];
  };

  /**
   * Get current language name in native script
   *
   * @returns {string}
   */
  const getCurrentLanguageName = () => {
    const langInfo = getLanguageInfo(currentLanguage);
    return langInfo.nativeName;
  };

  /**
   * Check if current language is RTL
   *
   * @returns {boolean}
   */
  const isRTL = () => {
    const rtlLanguages = ['ur', 'ks', 'sd'];
    return rtlLanguages.includes(currentLanguage);
  };

  // Memoize primary languages list
  const primaryLanguages = useMemo(() => getPrimaryLanguages(), []);

  const contextValue = {
    currentLanguage,
    translations,
    t: translations, // Alias for convenience
    changeLanguage,
    supportedLanguages, // All languages (for settings/advanced)
    primaryLanguages, // Filtered list for selection screens
    getLanguageInfo,
    getCurrentLanguageName,
    isRTL,
  };

  return (
    <LanguageContext.Provider value={contextValue}>
      {children}
    </LanguageContext.Provider>
  );
}

/**
 * Hook to use language context
 *
 * @returns {Object} Language context
 *
 * @example
 * const { t, changeLanguage, currentLanguage } = useLanguage();
 * return <button>{t.buttons.save}</button>;
 */
export function useLanguage() {
  const context = useContext(LanguageContext);
  if (!context) {
    throw new Error('useLanguage must be used within a LanguageProvider');
  }
  return context;
}

/**
 * USAGE EXAMPLE:
 *
 * // 1. Wrap your app with LanguageProvider
 * <LanguageProvider>
 *   <App />
 * </LanguageProvider>
 *
 * // 2. Use in any component
 * function MyComponent() {
 *   const { t, currentLanguage, changeLanguage } = useLanguage();
 *
 *   return (
 *     <div>
 *       <h1>{t.nav.home}</h1>
 *       <button onClick={() => changeLanguage('hi')}>
 *         Switch to Hindi
 *       </button>
 *       <p>Current: {currentLanguage}</p>
 *     </div>
 *   );
 * }
 */
