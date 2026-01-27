# ElevenLabs Voice Generation Architecture

## Overview

This implementation uses a **clean architecture separation** for ElevenLabs voice generation:

- **Node.js Backend Service** - Handles ElevenLabs API integration (secure API key handling)
- **Rails API Endpoint** - Proxy endpoint that calls the Node.js service
- **Frontend** - Only calls Rails API, never directly communicates with ElevenLabs

## Architecture Components

### 1. Node.js Voice Service (`/node-voice-service/`)

**Purpose:** Secure ElevenLabs API integration
**Location:** `/node-voice-service/`
**Port:** 3001 (configurable)

**Endpoints:**
- `POST /voice/generate` - Generate speech from text
- `GET /voices` - Get available voice list
- `GET /health` - Health check

**Security:**
- ElevenLabs API key stored in Node.js environment variables
- CORS configuration for allowed origins
- No API keys exposed to frontend

### 2. Rails API Endpoint (`/api/v1/voice`)

**Purpose:** Proxy service for Node.js voice service
**URL:** `/api/v1/voice/generate`

**Functionality:**
- Accepts JSON `{ text, voice }`
- Forwards request to Node.js service
- Returns audio stream or error response
- Handles timeout and error scenarios

### 3. Frontend Integration

**Frontend should ONLY call:**
```javascript
// Example frontend usage
const response = await fetch('/api/v1/voice/generate', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    text: 'Hello world',
    voice: 'pNInz6obpgDQGcFmaJgB'
  })
});
```

**Frontend should NEVER:**
- Include ElevenLabs API keys
- Call ElevenLabs directly
- Store or handle ElevenLabs credentials

## Setup Instructions

### 1. Start Node.js Voice Service

```bash
cd node-voice-service
npm install
cp .env.example .env
# Edit .env with your ElevenLabs API key
npm start
```

### 2. Configure Rails Application

```bash
# Add HTTParty gem (already added)
bundle install

# Set environment variable
export VOICE_SERVICE_URL=http://localhost:3001
```

### 3. Environment Variables

**Node.js Service (.env):**
```bash
ELEVENLABS_API_KEY=your_elevenlabs_api_key_here
PORT=3001
ALLOWED_ORIGINS=http://localhost:3000,https://yourdomain.com
```

**Rails Application:**
```bash
VOICE_SERVICE_URL=http://localhost:3001
```

## API Usage Examples

### Generate Voice

```bash
curl -X POST http://localhost:3000/api/v1/voice/generate \
  -H "Content-Type: application/json" \
  -d '{"text": "Hello from Ultimate Social Media!", "voice": "pNInz6obpgDQGcFmaJgB"}'
```

### Get Available Voices

```bash
curl http://localhost:3000/api/v1/voices
```

## Security Benefits

1. **API Key Security** - ElevenLabs keys never exposed to frontend
2. **Single Point of Control** - All voice generation goes through Rails
3. **Rate Limiting** - Can add rate limiting at Rails level
4. **Error Handling** - Centralized error handling and logging
5. **CORS Protection** - Configurable origin restrictions

## Error Handling

The system handles various error scenarios:

- **400** - Invalid input (missing text)
- **401** - Invalid ElevenLabs API key
- **413** - Text too long
- **422** - Invalid voice ID
- **500** - Internal service error
- **Timeout** - Service unavailable

All errors are logged and returned in a consistent format.