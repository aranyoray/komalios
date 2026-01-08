# Avatar Customizer Mobile App

Human-like avatar customizer for kids built with Ionic/Capacitor, PixiJS, and React.

## Features

- 🎨 **Human-like Avatars** - Realistic proportions and features
- 👤 **Multiple Characters** - Select from different character templates
- 🎭 **Full Customization**:
  - Gender (Male/Female/Neutral)
  - Hair (Style + Color)
  - Eyes (Shape + Color + Size)
  - Nose, Ears, Face Shape
  - Mouth (Style + Color)
  - Body/Clothing (Style + Color)
  - Accessories (Multiple + Colors)
  - Expressions
- 🎲 **Randomize Button** - Generate random avatars
- 💾 **Export** - Save as PNG and export JSON parameters
- ✨ **Animations** - Idle animations, expression changes
- 📱 **Mobile-First** - Built for iOS and Android

## Tech Stack

- **Ionic React** - UI Framework
- **Capacitor** - Native mobile capabilities
- **PixiJS** - 2.5D rendering engine
- **GSAP** - Animation library
- **Zustand** - State management
- **React Colorful** - Color picker
- **TypeScript** - Type safety

## Installation

```bash
# Install dependencies
npm install

# Run development server
npm run dev

# Build for production
npm run build

# Add iOS platform
npm run cap:add:ios
npm run cap:open:ios

# Add Android platform
npm run cap:add:android
npm run cap:open:android

# Sync Capacitor
npm run cap:sync
```

## Project Structure

```
src/
├── components/        # React components
│   ├── AvatarCanvas.tsx
│   ├── CharacterSelector.tsx
│   ├── ColorPicker.tsx
│   └── CustomizerPanel.tsx
├── pages/            # Page components
│   └── Home.tsx
├── stores/           # State management
│   └── avatarStore.ts
├── types/            # TypeScript types
│   └── avatar.ts
├── utils/            # Utilities
│   ├── renderer.ts   # PixiJS rendering
│   ├── randomizer.ts # Random generation
│   ├── export.ts     # Export functions
│   └── defaultConfig.ts
└── main.tsx         # Entry point
```

## Development

1. Start the dev server: `npm run dev`
2. Open http://localhost:3000
3. Customize your avatar!
4. Export as PNG or JSON

## Building for Mobile

1. Build the web app: `npm run build`
2. Sync with Capacitor: `npm run cap:sync`
3. Open in Xcode/Android Studio: `npm run cap:open:ios` or `npm run cap:open:android`

## License

MIT

