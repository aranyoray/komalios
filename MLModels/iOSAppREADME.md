# iOS Content Safety Test App

Complete iOS app that integrates with your Komalweb Flask backend.

## Features

✅ **Content Filter** - Analyze text for safety using `/api/filter` endpoint
✅ **Chatbot** - Safety assistant using `/api/chat` endpoint  
✅ **Speech-to-Text** - Voice input using Apple's Speech framework
✅ **Age-Based Filtering** - Select age group for analysis
✅ **Real-time Results** - See categories, confidence, and verdicts

## Setup Instructions

### 1. Open in Xcode

```bash
cd /repo/iOSApp
open ContentSafetyTest.xcodeproj
```

### 2. Configure Backend URL

In `KomalWebAPI.swift`, change the baseURL:

```swift
// For local testing:
private let baseURL = "http://localhost:5000"

// For deployed backend:
private let baseURL = "https://your-komalweb-backend.com"
```

### 3. Start Your Flask Backend

Make sure your Komalweb backend is running:

```bash
cd path/to/komalweb
python app.py
```

The backend should have these endpoints:
- `POST /api/filter` - Content safety analysis
- `POST /api/chat` - Chatbot conversation
- `GET /api/health` - Health check

### 4. Build & Run

1. Select target: **iPhone 15 Pro** (or any simulator)
2. Press **Cmd + R** to build and run
3. Grant **Microphone** and **Speech Recognition** permissions when prompted

## App Structure

```
ContentSafetyTest/
├── ContentSafetyTestApp.swift    # App entry point
├── MainTabView.swift              # Tab interface
├── KomalWebAPI.swift              # Backend API client
├── ContentFilterView.swift        # Content analysis tab
├── ChatbotView.swift              # Chatbot tab
├── SpeechRecognizer.swift         # Voice-to-text
└── Info.plist                     # Permissions
```

## Usage

### Content Filter Tab

1. **Enter text** to analyze
2. **Select age group** (<10, 10-13, 13-16, 16-18, 18+)
3. **Optional**: Add domain name
4. **Press "Analyze Content"**
5. **View results**:
   - Verdict (ALLOW/GATE/BLOCK)
   - Confidence score
   - Categories detected
   - Detailed breakdown

### Chatbot Tab

1. **Type** or **tap mic button** to speak
2. **Send message** to chatbot
3. **Receive response** with safety filtering
4. **View conversation history**
5. **Clear** conversation with trash button

## API Format

### Filter Request

```json
{
  "text": "Content to analyze",
  "age_group": "10-13",
  "domain": "example.com",
  "has_media": false
}
```

### Filter Response

```json
{
  "action": "GATE",
  "categories": ["violence"],
  "confidence": 0.75,
  "reason": "May contain violence",
  "details": {
    "major_categories": {
      "violence": 0.75,
      "explicit": 0.1
    },
    "needs_vision": false,
    "processing_time_ms": 45.2
  }
}
```

### Chat Request

```json
{
  "message": "How do I stay safe online?",
  "conversation_id": "abc123"
}
```

### Chat Response

```json
{
  "response": "Here are some tips...",
  "conversation_id": "abc123",
  "safety_check": {
    "is_safe": true,
    "filtered_content": false
  }
}
```

## Permissions Required

The app requires these permissions (configured in Info.plist):

- **NSMicrophoneUsageDescription** - For voice input
- **NSSpeechRecognitionUsageDescription** - For speech-to-text
- **NSAppTransportSecurity** - For localhost HTTP (development only)

## Testing on Simulator

### Test Content Filter

Try these examples:

1. **Safe Content**:
   ```
   "Educational content about science and nature"
   ```

2. **Violence**:
   ```
   "This video contains fighting, blood, and weapons"
   ```

3. **Explicit**:
   ```
   "XXX adult content porn explicit photos"
   ```

### Test Chatbot

Ask questions like:
- "How do I stay safe online?"
- "What should I do if I see something scary?"
- "Tell me about age-appropriate content"

### Test Voice Input

1. Tap **microphone button** in chatbot
2. Speak your message
3. Tap **microphone again** to stop
4. Message appears in text field
5. Press **send**

## Troubleshooting

### Backend Connection Errors

**Problem**: "Failed to connect to server"

**Solutions**:
1. Check Flask backend is running: `curl http://localhost:5000/api/health`
2. For simulator, use `http://localhost:5000`
3. For real device, use your computer's IP: `http://192.168.1.X:5000`

### Speech Recognition Not Working

**Problem**: "Speech recognition not authorized"

**Solutions**:
1. Go to **Settings → Privacy → Speech Recognition**
2. Enable for ContentSafetyTest
3. Go to **Settings → Privacy → Microphone**
4. Enable for ContentSafetyTest
5. Restart app

### Build Errors

**Problem**: "Missing Info.plist"

**Solution**:
1. Make sure `Info.plist` is in the project
2. Check **Build Settings → Info.plist File** points to `Info.plist`

## Next Steps

### Connect to Real Backend

1. Deploy your Komalweb backend (Heroku, Railway, etc.)
2. Update `baseURL` in `KomalWebAPI.swift`
3. Remove `NSAllowsArbitraryLoads` from Info.plist (use HTTPS only)

### Add Features

- Image upload for vision analysis
- Save conversation history locally
- User profiles and settings
- Dark mode support
- iPad optimization

### Deploy to TestFlight

1. Archive the app: **Product → Archive**
2. Upload to App Store Connect
3. Distribute via TestFlight
4. Get beta testers

## Requirements

- **Xcode**: 15.0+
- **iOS Deployment**: 17.0+
- **Swift**: 5.9+
- **Backend**: Komalweb Flask API running

## License

MIT

---

**Ready to test!** Just open the project in Xcode and run on iPhone simulator. 🚀
