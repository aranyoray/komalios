# Komal Web App

React-based web application for the Komal SEL platform.

## Setup

```bash
cd web
npm install
npm run dev
```

## Vercel Deployment

Set the **Root Directory** to `web` in Vercel project settings.

The app will build with Vite and deploy automatically.

## Structure

```
web/
├── src/
│   ├── components/    # React components
│   ├── pages/         # Page components
│   ├── hooks/         # Custom hooks
│   ├── contexts/      # React contexts
│   ├── services/      # API services
│   └── ml/            # ML utilities
├── public/            # Static assets
├── index.html         # Entry HTML
├── vite.config.js     # Vite configuration
└── package.json       # Dependencies
```

## Scripts

- `npm run dev` - Start dev server
- `npm run build` - Production build
- `npm run preview` - Preview build
