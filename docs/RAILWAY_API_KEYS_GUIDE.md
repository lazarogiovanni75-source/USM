# Railway Backend API Keys Setup Guide

## Overview

Your Railway backend at `https://clacky-backend-clean-production.up.railway.app` needs the following API keys to connect with third-party services:

1. **OpenAI** - AI content generation
2. **ElevenLabs** - Text-to-speech voice generation
3. **Atlas Cloud** - Video generation
4. **Make.com or Zapier** - Automation workflows

---

## Required Environment Variables

Add these in your Railway project's **Variables** section:

```bash
ELEVENLABS_API_KEY=your_elevenlabs_key_here
OPENAI_API_KEY=your_openai_key_here
ATLASCLOUD_API_KEY=your_atlas_cloud_api_key
MAKEAI_API_KEY=your_makeai_key_here
ZAPIER_WEBHOOK_URL=https://hooks.zapier.com/hooks/catch/xxxxx/yyyyy/
```

---

## 1. OpenAI API Key

**What it's for:** AI-powered content generation for social media posts, captions, and scripts.

### Steps to Get API Key:

1. Go to **https://platform.openai.com**
2. Sign in or create an account
3. Click on your profile icon (top right) → **View API Keys**
4. Click **+ Create new secret key**
5. Give it a name (e.g., "Railway Backend")
6. **IMPORTANT:** Copy the key immediately (starts with `sk-proj-...`)
   - You won't be able to see it again!
7. Store it securely

### Pricing:
- Pay-as-you-go model
- GPT-4o-mini: ~$0.15 per 1M input tokens, $0.60 per 1M output tokens
- GPT-4: ~$30 per 1M tokens (more expensive but higher quality)
- Free trial: $5 credit for new users

### Railway Setup:
```
Variable: OPENAI_API_KEY
Value: sk-proj-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**Optional:**
```
Variable: OPENAI_MODEL
Value: gpt-4o-mini  (default, or use "gpt-4" for better quality)
```

---

## 2. ElevenLabs API Key

**What it's for:** Converting text to realistic human voice for video content.

### Steps to Get API Key:

1. Go to **https://elevenlabs.io**
2. Sign up or sign in
3. Click your profile icon → **Profile + API Key**
4. Click **Copy** next to your API key
5. The key looks like: `a1b2c3d4e5f6g7h8i9j0...`

### Pricing:
- **Free Tier:** 10,000 characters/month (~5 minutes of audio)
- **Starter:** $5/month - 30,000 characters
- **Creator:** $22/month - 100,000 characters
- **Pro:** $99/month - 500,000 characters

### Railway Setup:
```
Variable: ELEVENLABS_API_KEY
Value: a1b2c3d4e5f6g7h8i9j0...
```

**Optional (custom voice):**
```
Variable: ELEVENLABS_VOICE_ID
Value: pNInz6obpgDQGcFmaJgB  (default: Adam voice)
```

### Finding Voice IDs:
1. Go to https://elevenlabs.io/voice-library
2. Click on any voice
3. Copy the Voice ID from the URL or voice details

---

## 3. Atlas Cloud API Key (Video Generation)

**What it's for:** AI video generation using Atlas Cloud.

### Steps to Get API Key:

1. Go to **https://atlascloud.ai**
2. Sign up for an account
3. Go to **Dashboard** → **API Keys**
4. Copy your API key

### Railway Setup:
```
Variable: ATLAS_CLOUD_API_KEY
Value: your_atlas_cloud_api_key_here
```

---

## 4. Make.com / Zapier (Automation)

**What it's for:** Automating social media posting workflows and connecting to platforms.

### Option A: Make.com (Recommended)

#### Steps to Get API Key:

1. Go to **https://make.com**
2. Sign up or sign in
3. Click your profile → **Organizations**
4. Go to **API** tab
5. Click **+ Generate token**
6. Copy your API token

#### Pricing:
- **Free:** 1,000 operations/month
- **Core:** $9/month - 10,000 operations
- **Pro:** $16/month - 10,000 operations + premium apps
- **Teams:** $29/month - 10,000 operations + team features

#### Railway Setup:
```
Variable: MAKEAI_API_KEY
Value: your_make_api_token_here
```

**Webhook URL (for scenarios):**
```
Variable: MAKEAI_WEBHOOK_URL
Value: https://hook.make.com/your_scenario_webhook_id
```

### Option B: Zapier

#### Steps to Get Webhook URL:

1. Go to **https://zapier.com**
2. Sign up or sign in
3. Click **Create Zap**
4. Choose **Webhooks by Zapier** as trigger
5. Select **Catch Hook**
6. Copy the webhook URL provided
7. Test it by sending a sample request

#### Pricing:
- **Free:** 100 tasks/month
- **Starter:** $19.99/month - 750 tasks
- **Professional:** $49/month - 2,000 tasks

#### Railway Setup:
```
Variable: ZAPIER_WEBHOOK_URL
Value: https://hooks.zapier.com/hooks/catch/xxxxx/yyyyy/
```

---

## 5. CORS Configuration (Important!)

Add your ClackyAI frontend URL to allowed origins:

```
Variable: ALLOWED_ORIGINS
Value: https://your-thread.clacky.app,https://clacky-backend-clean-production.up.railway.app
```

Replace `your-thread.clacky.app` with your actual ClackyAI domain.

---

## How to Add Variables to Railway

### Method 1: Railway Dashboard (Recommended)

1. Go to **https://railway.app/dashboard**
2. Select your project: `clacky-backend-clean-production`
3. Click on your service (usually named "backend" or "server")
4. Go to **Variables** tab
5. Click **+ New Variable**
6. Enter variable name (e.g., `OPENAI_API_KEY`)
7. Paste the value
8. Click **Add**
9. Repeat for all other variables
10. **Important:** Railway auto-redeploys after adding variables

### Method 2: Railway CLI

```bash
# Install Railway CLI
npm i -g @railway/cli

# Login
railway login

# Link to your project
railway link

# Add variables
railway variables set OPENAI_API_KEY=sk-proj-...
railway variables set ELEVENLABS_API_KEY=a1b2c3...
railway variables set ATLAS_CLOUD_API_KEY=your_key...
railway variables set MAKEAI_API_KEY=your_key...

# View all variables
railway variables
```

---

## Testing Your Setup

### 1. Check Health Endpoint

```bash
curl https://clacky-backend-clean-production.up.railway.app/health
```

**Expected Response:**
```json
{
  "status": "ok",
  "service": "ultimate-social-media-api",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "version": "1.0.0"
}
```

### 2. Test OpenAI Integration

```bash
curl -X POST https://clacky-backend-clean-production.up.railway.app/api/ai/generate-content \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Write a short Instagram caption about coffee",
    "platform": "instagram",
    "contentType": "caption"
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "content": "☕ Start your day right...",
  "contentType": "caption",
  "platform": "instagram"
}
```

### 3. Test ElevenLabs Voice Generation

```bash
curl -X POST https://clacky-backend-clean-production.up.railway.app/api/voice/generate \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Hello, this is a test of voice generation",
    "voice": "pNInz6obpgDQGcFmaJgB"
  }' \
  --output test-voice.mp3
```

**Expected:** Downloads an MP3 file with generated speech.

### 4. Get Available Voices

```bash
curl https://clacky-backend-clean-production.up.railway.app/api/voices
```

**Expected:** JSON array of available ElevenLabs voices.

### 5. Test Atlas Cloud Video Generation

```bash
curl -X POST https://clacky-backend-clean-production.up.railway.app/api/video/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Test video"}'
```

**Expected Response:**
```json
{
  "success": true,
  "jobId": "abc-123-def",
  "status": "pending",
  "message": "Video generation started"
}
```

---

## Common Errors & Solutions

### Error: "API key not configured"

**Cause:** Environment variable not set in Railway.

**Solution:**
1. Go to Railway Dashboard → Variables
2. Add the missing API key variable
3. Wait for automatic redeploy (~30 seconds)

### Error: "Invalid API key" (401)

**Cause:** Wrong API key or expired key.

**Solution:**
1. Verify the API key in the service dashboard
2. Generate a new key if needed
3. Update the Railway variable

### Error: "Rate limit exceeded" (429)

**Cause:** Too many requests to third-party API.

**Solution:**
1. Check your API usage in the service dashboard
2. Upgrade your plan if needed
3. Implement request queuing in your app

### Error: CORS blocked

**Cause:** Frontend origin not in ALLOWED_ORIGINS.

**Solution:**
```bash
# Add your ClackyAI domain
railway variables set ALLOWED_ORIGINS=https://your-thread.clacky.app
```

---

## Security Best Practices

1. **Never commit API keys to Git**
   - Always use environment variables
   - Add `.env` to `.gitignore`

2. **Use different keys for staging/production**
   - Keep production keys separate
   - Use API key rotation for production

3. **Monitor API usage**
   - Set up billing alerts
   - Track usage in service dashboards

4. **Restrict CORS origins**
   - Only allow your actual frontend domains
   - Don't use `*` in production

5. **Set up Railway alerts**
   - Get notified of deployment failures
   - Monitor service health

---

## Quick Reference

| Service | Dashboard | Documentation |
|---------|-----------|---------------|
| OpenAI | https://platform.openai.com | https://platform.openai.com/docs |
| ElevenLabs | https://elevenlabs.io/app | https://elevenlabs.io/docs |
| Atlas Cloud | https://atlascloud.ai | https://atlascloud.ai/docs |
| Make.com | https://make.com | https://www.make.com/en/help |
| Zapier | https://zapier.com/app/dashboard | https://zapier.com/help |
| Railway | https://railway.app/dashboard | https://docs.railway.app |

---

## Need Help?

- **Railway Logs:** Railway Dashboard → Deployments → View Logs
- **Test Endpoint:** `curl https://clacky-backend-clean-production.up.railway.app/health`
- **Check Variables:** Railway Dashboard → Variables tab

---

**Last Updated:** 2024-01-15
**Railway Backend URL:** https://clacky-backend-clean-production.up.railway.app
