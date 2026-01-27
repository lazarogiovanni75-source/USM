# Ultimate Social Media Backend - Railway Deployment

## Overview

This is the **complete backend API** for your Ultimate Social Media platform, designed to run on Railway. It includes all your required integrations:

- 🎙️ **ElevenLabs** - Voice generation for AI content
- 🤖 **OpenAI** - AI content generation and campaign ideas
- 🎬 **Shotstack** - Video creation and editing
- 📱 **Make.ai** - Multi-platform social media posting

## Railway Deployment Steps

### 1. Create Railway Project
```bash
# Login to Railway
railway login

# Create new project
railway new

# Add environment variables
railway variables set ELEVENLABS_API_KEY=your_elevenlabs_key
railway variables set OPENAI_API_KEY=your_openai_key
railway variables set SHOTSTACK_API_KEY=your_shotstack_key
railway variables set MAKEAI_API_KEY=your_makeai_key
```

### 2. Deploy to Railway
```bash
# Initialize git (if not already done)
git init
git add .
git commit -m "Ultimate Social Media Backend"

# Connect to Railway
railway link

# Deploy
railway up
```

### 3. Get Your Railway URL
After deployment, Railway will provide you with a URL like:
`https://your-app.up.railway.app`

## API Endpoints

### 🎙️ Voice Generation (ElevenLabs)
```bash
POST /api/voice/generate
Content-Type: application/json

{
  "text": "Hello from Ultimate Social Media!",
  "voice": "pNInz6obpgDQGcFmaJgB",
  "speed": 1.0
}
```

### 🤖 AI Content Generation (OpenAI)
```bash
POST /api/ai/generate-content
Content-Type: application/json

{
  "prompt": "Create a social media post about productivity tips",
  "contentType": "post",
  "platform": "instagram",
  "campaign": "Productivity Week"
}
```

### 🎬 Video Generation (Shotstack)
```bash
POST /api/video/generate
Content-Type: application/json

{
  "script": "Welcome to our amazing product!",
  "voiceUrl": "https://your-railway-app.up.railway.app/api/voice/generate",
  "style": "social"
}
```

### 📱 Social Media Posting (Make.ai)
```bash
POST /api/social/post
Content-Type: application/json

{
  "content": "Check out our latest feature!",
  "platforms": ["instagram", "twitter", "facebook"],
  "scheduledTime": "2024-01-15T10:00:00Z"
}
```

### 📊 Analytics
```bash
GET /api/analytics/performance
```

## Frontend Integration

Your frontend should call the Railway-hosted API:

```javascript
// Set your Railway URL
const API_BASE = 'https://your-app.up.railway.app';

// Voice Generation
const generateVoice = async (text) => {
  const response = await fetch(`${API_BASE}/api/voice/generate`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text, voice: 'pNInz6obpgDQGcFmaJgB' })
  });
  return response.blob(); // Returns audio MP3
};

// AI Content Generation
const generateContent = async (prompt) => {
  const response = await fetch(`${API_BASE}/api/ai/generate-content`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ prompt, contentType: 'post', platform: 'instagram' })
  });
  return response.json();
};

// Social Media Posting
const postToSocial = async (content, platforms) => {
  const response = await fetch(`${API_BASE}/api/social/post`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ content, platforms })
  });
  return response.json();
};
```

## Security Features

- ✅ **CORS Protection** - Configurable allowed origins
- ✅ **Rate Limiting** - 100 requests per 15 minutes per IP
- ✅ **Helmet Security** - Security headers protection
- ✅ **API Key Protection** - All keys stored in Railway environment
- ✅ **Error Handling** - Comprehensive error responses
- ✅ **Request Logging** - Morgan logging for debugging

## Testing Locally

```bash
# Install dependencies
npm install

# Copy environment template
cp .env.example .env

# Edit .env with your API keys

# Start development server
npm run dev

# Test endpoints
curl http://localhost:3000/health
curl http://localhost:3000/api/voices
```

## Production Features

- **Health Check** - `/health` endpoint for Railway monitoring
- **Graceful Shutdown** - Proper process termination
- **Request IDs** - Track requests through logging
- **Compression** - Gzip compression for better performance
- **Environment Detection** - Different behavior for dev/prod

Your Ultimate Social Media backend is now **Railway-ready** with all integrations! 🎉