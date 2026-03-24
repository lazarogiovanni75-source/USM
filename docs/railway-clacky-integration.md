# Railway + ClackyAI Integration Guide

This guide covers connecting your Ultimate Social Media platform with Railway for deployment and configuring all external service integrations (ElevenLabs, OpenAI, Zapier, Atlas Cloud).

## Architecture Overview

Your application uses a dual-backend architecture:

- **Rails Backend (ClackyAI)**: Handles core application logic, database, authentication, and user interface
- **Node.js Backend (Railway)**: Handles external API integrations (voice, AI, video, automation)

## Part 1: Connecting Railway and ClackyAI

### Step 1.1: Deploy Node.js Backend to Railway

1. **Push your code to GitHub**
   ```bash
   git add .
   git commit -m "Prepare for Railway deployment"
   git push origin main
   ```

2. **Create a new Railway project**
   - Go to [Railway.app](https://railway.app)c
   - Sign in with GitHub
   - Click "New Project"
   - Select "Deploy from GitHub repo"
   - Choose your repository
   - Select the `railway-backend` directory as the root

3. **Configure Railway Environment Variables**
   
   In your Railway project dashboard, go to Variables and add:
   ```
   # Required - Get from respective service websites
   ELEVENLABS_API_KEY=your_elevenlabs_api_key
   OPENAI_API_KEY=your_openai_api_key
   ATLAS_CLOUD_API_KEY=your_atlas_cloud_api_key
   MAKEAI_API_KEY=your_makeai_api_key
   
   # Service Configuration
   PORT=3000
   NODE_ENV=production
   
   # CORS - Update with your ClackyAI domain
   ALLOWED_ORIGINS=https://your-thread.clacky.app,http://localhost:3000
   ```

4. **Deploy**
   - Click "Deploy" in Railway dashboard
   - Wait for build to complete
   - Note your Railway URL (e.g., `https://your-app.up.railway.app`)

### Step 1.2: Connect ClackyAI to Railway Backend

1. **Update ClackyAI Environment Variables**
   
   In Clacky, add these environment variables:
   ```
   # Railway Backend URL
   RAILWAY_BACKEND_URL=https://your-app.up.railway.app
   
   # (These are already configured in application.yml)
   CLACKY_ELEVENLABS_API_KEY=your_elevenlabs_api_key
   CLACKY_OPENAI_API_KEY=your_openai_api_key
   CLACKY_ATLAS_CLOUD_API_KEY=your_atlas_cloud_api_key
   ```

2. **Update API Configuration**
   
   Edit `app/javascript/config/api.js` to point to Railway:
   ```javascript
   export const API_CONFIG = {
     baseUrl: process.env.RAILWAY_BACKEND_URL || 'http://localhost:3000',
     // ... other config
   }
   ```

## Part 2: Service Integration Setup

### 2.1: ElevenLabs (Voice Generation)

**Purpose**: Convert text to natural-sounding voiceovers for videos

**Setup Steps**:
1. Go to [ElevenLabs](https://elevenlabs.io) and create account
2. Copy your API Key from Profile > API Key
3. Add to Railway variables:
   ```
   ELEVENLABS_API_KEY=xi_api_key_here
   ```
4. (Optional) Get a custom voice ID from Voice Library

**Testing**:
```bash
curl -X POST https://your-railway-app.up.railway.app/api/voices \
  -H "Content-Type: application/json"
```

---

### 2.2: OpenAI (AI Content Generation)

**Purpose**: Generate social media post content, captions, and campaign ideas

**Setup Steps**:
1. Go to [OpenAI Platform](https://platform.openai.com)
2. Create API key from API Keys section
3. Add to Railway variables:
   ```
   OPENAI_API_KEY=sk-your_openai_api_key_here
   ```

**Usage in your app**:
- The backend already has endpoints at `/api/ai/generate-content`
- Configure model in `railway-backend/server.js` if needed

---

### 2.3: Zapier (Automation)

**Purpose**: Connect to 5000+ apps for automation workflows

**Setup Steps**:
1. Go to [Zapier](https://zapier.com) and create account
2. Create a new Zap with "Webhooks by Zapier" as trigger
3. Copy the webhook URL
4. Add to Railway variables:
   ```
   ZAPIER_WEBHOOK_URL=https://hooks.zapier.com/hooks/catch/xxxxx/yyyyy/
   ```

**Usage in your app**:
The Rails backend already has Zapier integration at `app/services/zapier_integration_service.rb`. Configure the webhook URL there or in environment variables.

---

### 2.4: Atlas Cloud (Video Generation)

**Purpose**: Create AI-generated videos using Atlas Cloud.

**Setup Steps**:
1. Go to [Atlas Cloud](https://atlascloud.ai) and create account
2. Get your API Key from Dashboard > API
3. Add to Railway variables:
   ```
   ATLAS_CLOUD_API_KEY=your_atlas_cloud_api_key_here
   ```

**Testing**:
```bash
curl -X POST https://your-railway-app.up.railway.app/api/video/generate \
  -H "Content-Type: application/json" \
  -d '{"script": "Hello World!", "style": "social"}'
```

---

### 2.5: Make.ai (Social Media Automation)

**Purpose**: Automate posting to social media platforms

**Setup Steps**:
1. Go to [Make](https://make.com) (formerly Integromat)
2. Create account and get API Key from Profile > API Key
3. Create scenarios to handle posting
4. Add webhook URL to Railway:
   ```
   MAKEAI_API_KEY=your_make_api_key
   MAKEAI_WEBHOOK_URL=https://hook.make.com/your_webhook_id
   ```

## Part 3: Environment Variables Reference

### Railway Backend (.env)

| Variable | Required | Description |
|----------|----------|-------------|
| `ELEVENLABS_API_KEY` | Yes | ElevenLabs API key for text-to-speech |
| `OPENAI_API_KEY` | Yes | OpenAI API key for AI content generation |
| `ATLAS_CLOUD_API_KEY` | Yes | Atlas Cloud API key for video generation |
| `MAKEAI_API_KEY` | No | Make.com API key for automation |
| `ZAPIER_WEBHOOK_URL` | No | Zapier webhook URL for triggers |
| `PORT` | No | Server port (default: 3000) |
| `NODE_ENV` | No | Environment (production/development) |
| `ALLOWED_ORIGINS` | No | Comma-separated CORS origins |

### ClackyAI (.1024)

| Variable | Description |
|----------|-------------|
| `RAILWAY_BACKEND_URL` | URL of your Railway deployment |
| `CLACKY_ELEVENLABS_API_KEY` | (Optional) Override Railway config |
| `CLACKY_OPENAI_API_KEY` | (Optional) Override Railway config |
| `CLACKY_ATLAS_CLOUD_API_KEY` | (Optional) Override Railway config |

## Part 4: Testing Your Integrations

### Run All Tests

```bash
# Test in Clacky environment
cd /home/runner/app
bundle exec rspec spec/services/

# Test Railway backend locally
cd railway-backend
npm install
npm test
```

### Manual Endpoint Testing

```bash
# Test voice generation
curl -X POST http://localhost:3000/api/voice/generate \
  -H "Content-Type: application/json" \
  -d '{"text": "Hello!", "voice": "pNInz6obpgDQGcFmaJgB"}'

# Test AI content generation
curl -X POST http://localhost:3000/api/ai/generate-content \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Write a tweet about coffee", "platform": "twitter"}'

# Test video generation
curl -X POST http://localhost:3000/api/video/generate \
  -H "Content-Type: application/json" \
  -d '{"script": "Amazing product!", "style": "social"}'
```

## Part 5: Troubleshooting

### LLM Provider Errors

**Error**: "Clacky AI encountered an error when communicating with LLM provider"

**Solutions**:
1. Verify `CLACKY_LLM_API_KEY` is set in environment
2. Check your LLM provider's status page
3. Ensure your account has sufficient credits/quota

### ElevenLabs Issues

- **401 Error**: Invalid API key - check your key in ElevenLabs dashboard
- **429 Error**: Rate limit - wait and retry, or upgrade plan

### OpenAI Issues

- **401 Error**: Invalid or expired API key
- **429 Error**: Rate limit - implement backoff or upgrade tier

### Atlas Cloud Issues

- **Stage vs Production**: Use `stage` environment for testing
- Render time: Video generation takes 1-2 minutes

## Part 6: Production Checklist

Before going live:

- [ ] All API keys configured in Railway
- [ ] CORS origins updated with production domains
- [ ] Environment variables tested in Railway dashboard
- [ ] All integration endpoints tested manually
- [ ] Webhooks configured for Zapier/Make
- [ ] Backup/restore tested
- [ ] Monitoring alerts set up

## Support

- **ClackyAI Issues**: contact@clacky.ai
- **Railway Support**: Railway Discord or Help Center
- **API Provider Issues**: Check respective service status pages
