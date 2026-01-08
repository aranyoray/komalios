# i18n Translation System

Professional, scalable, and maintainable internationalization system for the Komal app.

## 📁 Structure

```
i18n/
├── types.ts                    # TypeScript interfaces for all translations
├── LanguageContext.jsx         # React context provider for language management
├── translations/
│   ├── index.ts               # Main entry point, exports all languages
│   ├── en/                    # English translations
│   │   ├── common.ts         # Shared/common translations
│   │   ├── auth.ts           # Authentication translations
│   │   ├── nav.ts            # Navigation translations
│   │   ├── buttons.ts        # Button labels
│   │   ├── onboarding.ts     # Onboarding screen translations
│   │   ├── reports.ts        # Reports feature translations
│   │   ├── settings.ts       # Settings translations
│   │   ├── learners.ts       # Learner management translations
│   │   ├── session.ts        # Session translations
│   │   ├── chat.ts           # Chat feature translations
│   │   ├── messages.ts       # Common messages/notifications
│   │   └── index.ts          # Combines all English translations
│   ├── hi/                    # Hindi translations (to be added)
│   ├── bn/                    # Bengali translations (to be added)
│   └── ...                    # Other languages
└── README.md                  # This file
```

## 🎯 Design Principles

1. **Feature-Based Organization**: Translations are organized by feature/screen, making it easy to find and maintain
2. **Type Safety**: Full TypeScript support with interfaces for all translation objects
3. **Scalability**: Easy to add new languages or features without affecting existing code
4. **Maintainability**: Each feature has its own file, reducing merge conflicts
5. **Consistency**: Shared translations (common, buttons) prevent duplication

## 📝 Adding a New Translation

### Step 1: Add to Types
Update `types.ts` to add the new translation interface:

```typescript
export interface Translation {
  // ... existing interfaces
  newFeature: NewFeatureTranslations;
}

export interface NewFeatureTranslations {
  title: string;
  description: string;
  // ... other fields
}
```

### Step 2: Create Translation Files
Create files for each language:

**`translations/en/newFeature.ts`**
```typescript
export const newFeature = {
  title: 'New Feature',
  description: 'Description here',
};
```

### Step 3: Add to Language Index
Update `translations/en/index.ts`:

```typescript
import { newFeature } from './newFeature';

export const en: Translation = {
  // ... existing translations
  newFeature,
};
```

### Step 4: Use in Components
```typescript
import { useLanguage } from '../i18n/LanguageContext';

function MyComponent() {
  const { t } = useLanguage();
  
  return <h1>{t.newFeature.title}</h1>;
}
```

## 🌍 Adding a New Language

### Step 1: Create Language Directory
Create `translations/[language-code]/` directory (e.g., `translations/hi/` for Hindi)

### Step 2: Create Translation Files
Copy structure from `en/` and translate each file:
- `common.ts`
- `auth.ts`
- `nav.ts`
- etc.

### Step 3: Create Language Index
Create `translations/hi/index.ts`:

```typescript
import { Translation } from '../types';
import { common } from './common';
import { auth } from './auth';
// ... import all features

export const hi: Translation = {
  languageName: 'Hindi',
  languageNameInScript: 'हिंदी',
  common,
  auth,
  // ... all features
};
```

### Step 4: Register in Main Index
Update `translations/index.ts`:

```typescript
import { hi } from './hi';

export const translations: Record<string, Translation> = {
  en,
  hi,
  // ... other languages
};
```

## 💡 Usage Examples

### Basic Usage
```typescript
import { useLanguage } from '../i18n/LanguageContext';

function MyComponent() {
  const { t, currentLanguage, changeLanguage } = useLanguage();
  
  return (
    <div>
      <h1>{t.nav.home}</h1>
      <button onClick={() => changeLanguage('hi')}>
        Switch to Hindi
      </button>
      <p>Current: {currentLanguage}</p>
    </div>
  );
}
```

### Using Nested Translations
```typescript
function OnboardingStep() {
  const { t } = useLanguage();
  
  return (
    <div>
      <h1>{t.onboarding.steps.welcome.title}</h1>
      <p>{t.onboarding.steps.welcome.description}</p>
    </div>
  );
}
```

### Using Common Translations
```typescript
function ActionButtons() {
  const { t } = useLanguage();
  
  return (
    <>
      <button>{t.buttons.save}</button>
      <button>{t.buttons.cancel}</button>
      {t.messages.loading && <span>{t.messages.loading}</span>}
    </>
  );
}
```

## 🔧 Best Practices

1. **Always use types**: Import from `types.ts` to ensure type safety
2. **Keep translations organized**: One file per feature
3. **Reuse common translations**: Use `common.ts` and `buttons.ts` for shared strings
4. **Maintain consistency**: Use the same key names across languages
5. **Test translations**: Ensure all keys exist in all languages
6. **Document context**: Add comments for ambiguous translations

## 📊 Translation Coverage

- ✅ English (en) - Complete
- ⏳ Hindi (hi) - To be added
- ⏳ Bengali (bn) - To be added
- ⏳ Other languages - To be added

## 🚀 Migration from Old Structure

The old `translations.ts` file is being phased out. To migrate:

1. Extract translations from old file
2. Organize into feature-based files
3. Update imports in components
4. Test thoroughly

## 📚 Additional Resources

- [TypeScript Handbook - Types](https://www.typescriptlang.org/docs/handbook/types.html)
- [React Context API](https://react.dev/reference/react/createContext)
- [i18n Best Practices](https://phrase.com/blog/posts/i18n-best-practices/)
