# Emoji Web Customizer

Kid-friendly web app for customizing 2.5D emoji avatars.

## Requirements
- Node.js 18+
- npm or yarn

## Install

```bash
cd emoji_web_customizer
npm install
```

## Run Development Server

```bash
npm run dev
```

Open http://localhost:3000

## Features
- Canvas-based emoji preview
- Hair style and color picker
- Accessory selection
- Export avatar as PNG + JSON params
- Accessibility options
- Safe presets only

## Privacy & Safety
- All data stored locally
- No real child data without consent
- Use --accept_real_data flag explicitly for production

## API Server (optional)

To enable Python engine rendering:

```bash
node api/render_stub.js
```

Then set `RENDER_API=http://localhost:3001` in .env.local

## Build

```bash
npm run build
npm start
```
