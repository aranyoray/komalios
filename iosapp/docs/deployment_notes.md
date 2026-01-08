# Deployment Notes

## Overview

The Komal Emoji Avatar system consists of three main components:
1. Python rendering engine
2. Web customizer (Next.js)
3. Mobile customizer (Expo/React Native)

## Requirements

### Python Engine
- Python 3.8+
- Pillow, NumPy, imageio
- Optional: scipy, numba (for compute-heavy mode)

### Web Customizer
- Node.js 18+
- Next.js 13+

### Mobile Customizer
- Node.js 18+
- Expo CLI
- iOS/Android development environment

## Deployment Options

### Local Development

```bash
# Setup
./scripts/setup_env.sh

# Run Python engine
python emoji_avatar_engine.py --emoji smile --seconds 3

# Run web app
cd emoji_web_customizer && npm run dev

# Run mobile app
cd emoji_mobile_customizer && npx expo start
```

### Docker

```dockerfile
FROM python:3.10-slim
WORKDIR /app
COPY emoji_avatar_engine.py .
COPY assets/ ./assets/
RUN pip install pillow numpy imageio
CMD ["python", "emoji_avatar_engine.py", "--help"]
```

### Cloud Deployment

#### Web App (Vercel)
```bash
cd emoji_web_customizer
vercel deploy
```

#### API Server (Railway/Render)
- Deploy `emoji_web_customizer/api/render_stub.js`
- Set environment variables for Python path

### Mobile App Stores

#### iOS (App Store)
```bash
cd emoji_mobile_customizer
npx expo build:ios
# Upload to App Store Connect
```

#### Android (Play Store)
```bash
cd emoji_mobile_customizer
npx expo build:android
# Upload to Play Console
```

## Performance Considerations

- **Standard mode**: ~50ms per frame (CPU)
- **Compute-heavy mode**: ~200ms per frame (additional effects)
- **Batch generation**: Uses multiprocessing for parallel rendering

## Security Notes

- No external data collection
- All processing happens locally
- Parent dashboard uses local storage only
- Child-safe emoji set (no negative expressions)

## Monitoring

For production deployments, consider:
- Error tracking (Sentry)
- Performance monitoring
- Usage analytics (privacy-compliant)

## Support

For issues, contact the development team or file a GitHub issue.
