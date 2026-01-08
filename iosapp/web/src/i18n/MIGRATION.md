# i18n Migration Guide

## Overview

The i18n system has been reorganized into a professional, modular structure. This guide helps you understand the new structure and migrate existing code.

## New Structure Benefits

✅ **Feature-Based Organization**: Each feature has its own translation file  
✅ **Type Safety**: Full TypeScript support  
✅ **Scalable**: Easy to add new languages or features  
✅ **Maintainable**: Reduced merge conflicts  
✅ **Professional**: Industry best practices  

## File Structure

```
i18n/
├── types.ts                    # Type definitions
├── LanguageContext.jsx         # React context (unchanged)
├── translations/
│   ├── index.ts               # Main entry point
│   └── en/                    # English translations
│       ├── common.ts
│       ├── auth.ts
│       ├── nav.ts
│       ├── buttons.ts
│       ├── onboarding.ts
│       ├── reports.ts
│       ├── settings.ts
│       ├── learners.ts
│       ├── session.ts
│       ├── chat.ts
│       ├── messages.ts
│       └── index.ts
└── README.md
```

## Breaking Changes

### Import Path
**Old:**
```typescript
import { getTranslation } from './translations';
```

**New:**
```typescript
import { getTranslation } from './translations/index';
```

### Translation Structure
**Old:**
```typescript
t.buttons.save
t.messages.loading
```

**New:**
```typescript
t.buttons.save        // Same
t.messages.loading    // Same
t.common.loading      // New: shared translations
```

## Migration Steps

### For Components

No changes needed! The `useLanguage()` hook works the same way:

```typescript
import { useLanguage } from '../i18n/LanguageContext';

function MyComponent() {
  const { t } = useLanguage();
  return <button>{t.buttons.save}</button>;
}
```

### For Adding New Translations

1. **Add to types** (`types.ts`)
2. **Create feature file** (`translations/en/newFeature.ts`)
3. **Add to language index** (`translations/en/index.ts`)
4. **Use in components**

See `README.md` for detailed examples.

## Old Files Status

The old translation files (`translations.ts`, `translations-part*.ts`) are still present but will be deprecated. They can coexist with the new structure during migration.

## Next Steps

1. ✅ New structure is ready
2. ⏳ Migrate other languages (hi, bn, etc.) to new structure
3. ⏳ Remove old translation files after migration
4. ⏳ Update any direct imports from old files

