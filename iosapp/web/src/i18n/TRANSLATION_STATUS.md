# Translation Status

## Overview
This document tracks the translation status for all primary languages in the Komal app.

## Primary Languages (15 total)
1. English (en) - ✅ Complete
2. Bengali (bn) - ✅ Complete  
3. Hindi (hi) - 🟡 In Progress
4. Tamil (ta) - ⏳ Pending
5. Telugu (te) - ⏳ Pending
6. Marathi (mr) - ⏳ Pending
7. Gujarati (gu) - ⏳ Pending
8. Kannada (kn) - ⏳ Pending
9. Malayalam (ml) - ⏳ Pending
10. Odia (or) - ⏳ Pending
11. Punjabi (pa) - ⏳ Pending
12. Urdu (ur) - ⏳ Pending
13. Sindhi (sd) - ⏳ Pending
14. Assamese (as) - ⏳ Pending
15. Nepali (ne) - ⏳ Pending

## Translation Files Required Per Language (18 files)
1. common.ts
2. auth.ts
3. nav.ts
4. buttons.ts
5. onboarding.ts
6. reports.ts
7. settings.ts
8. learners.ts
9. session.ts
10. chat.ts
11. messages.ts
12. profileSelect.ts
13. createProfile.ts
14. learner.ts
15. profile.ts
16. editLearnerProfile.ts
17. parentDashboard.ts
18. index.ts

## Total Files Needed
- 15 languages × 18 files = 270 files
- Currently created: ~20 files (English + Bengali + partial Hindi)

## Approach
1. Extract translations from old translation files (`translations-part*.ts`, `translations-extended.ts`, `translations.ts`)
2. Organize into new modular structure
3. Create missing translations based on language knowledge
4. Generate index.ts files for each language
5. Update main translations/index.ts

## Notes
- Old translation files contain translations for all languages but in flat structure
- Need to convert to new modular structure
- Some new translation keys (like auth.signInPage, etc.) need to be added to all languages

