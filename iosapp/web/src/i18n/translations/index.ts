/**
 * Translations Index
 * Main entry point for all translations
 * 
 * Structure:
 * - translations/
 *   - en/ (English)
 *     - common.ts
 *     - auth.ts
 *     - nav.ts
 *     - buttons.ts
 *     - onboarding.ts
 *     - reports.ts
 *     - settings.ts
 *     - learners.ts
 *     - session.ts
 *     - chat.ts
 *     - messages.ts
 *     - index.ts
 *   - hi/ (Hindi) - ✅ Complete
 *   - bn/ (Bengali) - ✅ Complete
 *   - as/ (Assamese) - ✅ Complete
 *   - gu/ (Gujarati) - ✅ Complete
 *   - kn/ (Kannada) - ✅ Complete
 *   - ml/ (Malayalam) - ✅ Complete
 *   - mr/ (Marathi) - ✅ Complete
 *   - ne/ (Nepali) - ✅ Complete
 *   - or/ (Odia) - ✅ Complete
 *   - pa/ (Punjabi) - ✅ Complete
 *   - ur/ (Urdu) - ✅ Complete
 *   - sd/ (Sindhi) - ✅ Complete
 *   - ta/ (Tamil) - ✅ Complete
 *   - te/ (Telugu) - ✅ Complete
 *   - etc...
 */

import { Translation } from '../types';
import { en } from './en';
import { bn } from './bn';
import { hi } from './hi';
import { as } from './as';
import { gu } from './gu';
import { kn } from './kn';
import { ml } from './ml';
import { mr } from './mr';
import { ne } from './ne';
import { or } from './or';
import { pa } from './pa';
import { ur } from './ur';
import { sd } from './sd';
import { ta } from './ta';
import { te } from './te';

// Export all translations
export const translations: Record<string, Translation> = {
  en,
  bn,
  hi,
  as,
  gu,
  kn,
  ml,
  mr,
  ne,
  or,
  pa,
  ur,
  sd,
  ta,
  te,
  // Add other languages here as they are created
  // etc...
};

/**
 * Get translation for a specific language
 * Falls back to English if language not found
 */
export function getTranslation(languageCode: string): Translation {
  return translations[languageCode] || translations.en;
}

/**
 * Supported languages list
 */
export const supportedLanguages = [
  { code: 'en', name: 'English', nativeName: 'English' },
  { code: 'hi', name: 'Hindi', nativeName: 'हिंदी' },
  { code: 'hi-en', name: 'Hinglish', nativeName: 'Hinglish' },
  { code: 'bn', name: 'Bengali', nativeName: 'বাংলা' },
  { code: 'te', name: 'Telugu', nativeName: 'తెలుగు' },
  { code: 'mr', name: 'Marathi', nativeName: 'मराठी' },
  { code: 'ta', name: 'Tamil', nativeName: 'தமிழ்' },
  { code: 'ur', name: 'Urdu', nativeName: 'اردو' },
  { code: 'gu', name: 'Gujarati', nativeName: 'ગુજરાતી' },
  { code: 'kn', name: 'Kannada', nativeName: 'ಕನ್ನಡ' },
  { code: 'ml', name: 'Malayalam', nativeName: 'മലയാളം' },
  { code: 'or', name: 'Odia', nativeName: 'ଓଡ଼ିଆ' },
  { code: 'pa', name: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ' },
  { code: 'as', name: 'Assamese', nativeName: 'অসমীয়া' },
  { code: 'mai', name: 'Maithili', nativeName: 'मैथिली' },
  { code: 'sat', name: 'Santali', nativeName: 'ᱥᱟᱱᱛᱟᱲᱤ' },
  { code: 'ks', name: 'Kashmiri', nativeName: 'کٲشُر' },
  { code: 'ne', name: 'Nepali', nativeName: 'नेपाली' },
  { code: 'gom', name: 'Konkani', nativeName: 'कोंकणी' },
  { code: 'sd', name: 'Sindhi', nativeName: 'سنڌي' },
  { code: 'doi', name: 'Dogri', nativeName: 'डोगरी' },
  { code: 'mni', name: 'Manipuri', nativeName: 'মৈতৈলোন্' },
  { code: 'brx', name: 'Bodo', nativeName: 'बड़ो' },
  { code: 'sa', name: 'Sanskrit', nativeName: 'संस्कृत' },
];

