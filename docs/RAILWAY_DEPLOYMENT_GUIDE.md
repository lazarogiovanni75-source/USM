# Railway Backend Deployment Guide

## Current Status

**⚠️ Railway Backend Not Deployed**: The URL `https://backend-api-production-00f5.up.railway.app` returns 404 (Application not found).

## Architecture

Your application uses a **dual-backend architecture**:

1. **ClackyAI (Rails)** - Frontend + UI + Main application logic
   - Running at: `https://your-thread.clacky.app`
   - Handles: User authentication, database, UI, main business logic

2. **Railway Backend (Node.js)** - Third-party API gateway
   - Should run at: `https://backend-api-production-00f5.up.railway.app` (currently NOT deployed)
   - Handles: ElevenLabs, OpenAI, Shotstack, Make.ai API calls
   - Located in: `railway-backend/` directory

## Why This Architecture?

- **Security**: API keys for third-party services stay on Railway backend, not exposed in frontend
- **Separation**: ClackyAI doesn't call third-party APIs directly - everything goes through Railway
- **Flexibility**: Can swap/update third-party integrations without changing Rails code

## Deployment Steps

### Step 1: Deploy Node.js Backend to Railway

1. **Go to Railway.app**
   - Visit: https://railway.app
   - Sign in with GitHub

2. **Create New Project**
   - Click "New Project"
   - Select "Deploy from GitHub repo"
   - Choose your repository
   - **IMPORTANT**: Set root directory to `railway-backend/`

3. **Configure Environment Variables**
   
   In Railway dashboard → Variables tab, add:

   ```bash
   # Required API Keys (get from respective service providers)
   ELEVENLABS_API_KEY=your_elevenlabs_api_key_here
   OPENAI_API_KEY=your_openai_api_key_here
   SHOTSTACK_API_KEY=your_shotstack_api_key_here
   MAKEAI_API_KEY=your_makeai_api_key_here
   
   # Service Configuration
   PORT=3000
   NODE_ENV=production
   
   # CORS - Update with your ClackyAI domain
   ALLOWED_ORIGINS=https://your-thread.clacky.app,http://localhost:3000
   ```

4. **Deploy**
   - Railway will auto-detect `package.json` and deploy
   - Wait for build to complete
   - Note your Railway URL (should be similar to `https://backend-api-production-00f5.up.railway.app`)

### Step 2: Update ClackyAI Environment Variable

In ClackyAI environment settings, add:

```bash
CLACKY_RAILWAY_BACKEND_URL=https://your-actual-railway-app.up.railway.app
```

**Note**: The code has been updated to use this environment variable. If not set, it defaults to `https://backend-api-production-00f5.up.railway.app`.

### Step 3: Get API Keys

#### ElevenLabs (Voice Generation)
1. Go to: https://elevenlabs.io
2. Create account
3. Navigate to Profile → API Key
4. Copy key and add to Railway variables

#### OpenAI (AI Content Generation)
1. Go to: https://platform.openai.com
2. Create API key from API Keys section
3. Copy key and add to Railway variables

#### Shotstack (Video Generation)
1. Go to: https://shotstack.io
2. Create account
3. Get API key from Dashboard → API
4. Copy key and add to Railway variables
5. Set `SHOTSTACK_ENVIRONMENT=stage` for testing, `prod` for production

#### Make.ai (Optional - Social Media Automation)
1. Go to: https://make.com
2. Create account
3. Get API key from Profile → API Key
4. Create scenarios for handling posts
5. Copy key and add to Railway variables

### Step 4: Verify Deployment

After deployment, test the connection:

```bash
# Test health endpoint
curl https://your-railway-app.up.railway.app/health

# Expected response:
# {
#   "status": "ok",
#   "service": "ultimate-social-media-api",
#   "timestamp": "2025-01-XX...",
#   "version": "1.0.0"
# }

# Test voice API
curl https://your-railway-app.up.railway.app/api/voices

# Test AI content generation
curl -X POST https://your-railway-app.up.railway.app/api/ai/generate-content \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Write a tweet about coffee", "platform": "twitter"}'
```

## What We've Fixed

✅ **API Configuration Updated**:
- `config/application.yml` - Added `RAILWAY_BACKEND_URL` configuration
- `app/javascript/config/api.js` - Now reads from meta tag instead of hardcoded URL
- `app/javascript/services/ultimateSocialMediaService.js` - Now reads from meta tag
- `app/views/layouts/application.html.erb` - Added meta tag with Railway backend URL

✅ **Environment Variable Support**:
- Uses `CLACKY_RAILWAY_BACKEND_URL` if set
- Falls back to default URL if not set
- JavaScript reads from Rails-generated meta tag

## Current Code Flow

1. **User action in ClackyAI UI** (e.g., "Generate voice-over")
2. **JavaScript service** reads Railway URL from meta tag
3. **Calls Railway backend**: `POST https://your-railway-app.up.railway.app/api/voice/generate`
4. **Railway backend** calls ElevenLabs API with server-side API key
5. **Railway returns** audio data to ClackyAI
6. **ClackyAI displays** result to user

## Troubleshooting

### Railway Backend Returns 404
- **Cause**: Application not deployed or wrong URL
- **Solution**: Deploy the `railway-backend/` directory to Railway following Step 1

### CORS Errors
- **Cause**: ALLOWED_ORIGINS not configured correctly
- **Solution**: Add your ClackyAI domain to ALLOWED_ORIGINS in Railway variables

### API Key Errors (401)
- **Cause**: Invalid or missing API keys
- **Solution**: Verify API keys in Railway variables and check service provider dashboards

### Connection Timeout
- **Cause**: Railway service sleeping (free tier) or network issues
- **Solution**: Upgrade Railway plan or wait for service to wake up

## Files Modified

- `config/application.yml` - Added RAILWAY_BACKEND_URL
- `app/javascript/config/api.js` - Use environment variable
- `app/javascript/services/ultimateSocialMediaService.js` - Use environment variable
- `app/views/layouts/application.html.erb` - Added meta tag

## Next Steps

1. **Deploy Railway backend** following Step 1 above
2. **Add API keys** to Railway environment variables
3. **Update `CLACKY_RAILWAY_BACKEND_URL`** in ClackyAI with actual Railway URL
4. **Test all integrations** using curl commands above
5. **Monitor logs** in Railway dashboard for any errors

## Support Resources

- **Railway Docs**: https://docs.railway.app
- **ElevenLabs Docs**: https://docs.elevenlabs.io
- **OpenAI Docs**: https://platform.openai.com/docs
- **Shotstack Docs**: https://shotstack.io/docs

---

**Last Updated**: 2025-01-27
**Status**: Configuration complete, awaiting Railway deployment
