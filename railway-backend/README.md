# Ultimate Social Media API - Railway Backend

Node.js backend service that handles third-party API integrations for the Ultimate Social Media Platform.

## 🚀 Quick Deploy to Railway

### Method 1: One-Click Deploy (Recommended)

1. Click the button below to deploy to Railway:
   
   [![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/new)

2. Select **"Deploy from GitHub repo"**
3. Choose your repository
4. **Set root directory**: `railway-backend`
5. Add environment variables (see below)
6. Click **Deploy**

### Method 2: Manual Deploy

1. Go to [Railway.app](https://railway.app)
2. Sign in with GitHub
3. Click **"New Project"** → **"Deploy from GitHub repo"**
4. Select your repository
5. **Important**: Click "Settings" → Set **Root Directory** to `railway-backend`
6. Go to **"Variables"** tab and add required environment variables
7. Railway will auto-deploy

## 🔑 Required Environment Variables

Add these in Railway dashboard → Variables tab:

```bash
# Required API Keys
ELEVENLABS_API_KEY=your_elevenlabs_key
OPENAI_API_KEY=your_openai_key
SHOTSTACK_API_KEY=your_shotstack_key
DEFAPI_API_KEY=your_defapi_key

# Service Configuration
PORT=3000
NODE_ENV=production

# CORS - Update with your ClackyAI domain
ALLOWED_ORIGINS=https://your-thread.clacky.app,http://localhost:3000
```

### Optional Variables

```bash
MAKEAI_API_KEY=your_makeai_key
ZAPIER_WEBHOOK_URL=https://hooks.zapier.com/...
ELEVENLABS_VOICE_ID=pNInz6obpgDQGcFmaJgB
OPENAI_MODEL=gpt-4o-mini
SHOTSTACK_ENVIRONMENT=stage
```

## 📋 Getting API Keys

### ElevenLabs (Voice Generation)
1. Visit: https://elevenlabs.io
2. Profile → API Key
3. Copy your `xi-api-key`

### OpenAI (AI Content)
1. Visit: https://platform.openai.com
2. API Keys → Create new secret key
3. Copy the `sk-...` key

### Shotstack (Video Generation)
1. Visit: https://shotstack.io
2. Dashboard → API
3. Copy your API key
4. Use `stage` environment for testing

### DefAPI (AI Video Generation)
1. Visit: https://defapi.org
2. Create account or sign in
3. Go to API Settings → Copy your API key
4. Use model: `openai/sora-2` for video generation
5. Endpoints: `POST /video/start`, `GET /video/status/:jobId`

### Make.ai (Optional)
1. Visit: https://make.com
2. Profile → API Key
3. Copy your API key

## 🧪 Testing Your Deployment

After deployment, your Railway URL will be something like:
`https://your-app-name.up.railway.app`

### Test Health Endpoint

```bash
curl https://your-app-name.up.railway.app/health
```

Expected response:
```json
{
  "status": "ok",
  "service": "ultimate-social-media-api",
  "timestamp": "2025-01-27T...",
  "version": "1.0.0"
}
```

### Test Voice API

```bash
curl https://your-app-name.up.railway.app/api/voices
```

### Test AI Content Generation

```bash
curl -X POST https://your-app-name.up.railway.app/api/ai/generate-content \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Write a tweet about coffee", "platform": "twitter"}'
```

## 📁 API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/api/voices` | GET | Get available ElevenLabs voices |
| `/api/voice/generate` | POST | Generate voice from text |
| `/api/ai/generate-content` | POST | Generate AI content |
| `/api/video/generate` | POST | Generate video (Shotstack) |
| `/video/start` | POST | Start video generation (DefAPI) |
| `/video/status/:jobId` | GET | Check DefAPI job status |
| `/api/social/post` | POST | Post to social media |
| `/api/analytics/performance` | GET | Get analytics data |

## 🔗 Connect to ClackyAI

After deployment:

1. Copy your Railway URL (e.g., `https://your-app.up.railway.app`)
2. In ClackyAI environment, set:
   ```bash
   CLACKY_RAILWAY_BACKEND_URL=https://your-app.up.railway.app
   ```
3. ClackyAI will automatically use this URL for all third-party API calls

## 🛠️ Local Development

```bash
# Install dependencies
npm install

# Copy environment example
cp .env.example .env

# Edit .env with your API keys
nano .env

# Start development server
npm run dev

# Test locally
curl http://localhost:3000/health
```

## 📦 Dependencies

- **express**: Web framework
- **cors**: Cross-origin resource sharing
- **helmet**: Security headers
- **axios**: HTTP client for API calls
- **express-rate-limit**: Rate limiting
- **compression**: Response compression
- **morgan**: HTTP logging

## 🔒 Security Features

- ✅ Helmet security headers
- ✅ CORS configured
- ✅ Rate limiting (100 req/15min per IP)
- ✅ Request size limits (10MB)
- ✅ Environment variable validation
- ✅ HTTPS only in production

## 🐛 Troubleshooting

### 404 Error
- **Cause**: App not deployed or wrong URL
- **Fix**: Verify deployment in Railway dashboard

### CORS Error
- **Cause**: Frontend domain not in ALLOWED_ORIGINS
- **Fix**: Add your ClackyAI domain to ALLOWED_ORIGINS

### 401 API Error
- **Cause**: Invalid or missing API key
- **Fix**: Check API keys in Railway Variables tab

### Service Timeout
- **Cause**: Railway free tier sleeps after inactivity
- **Fix**: Upgrade plan or wait for wake-up (~30s)

## 📚 Documentation

- [Railway Docs](https://docs.railway.app)
- [ElevenLabs API](https://docs.elevenlabs.io)
- [OpenAI API](https://platform.openai.com/docs)
- [Shotstack API](https://shotstack.io/docs)

## 🤝 Support

For issues with:
- **Railway deployment**: Check Railway logs in dashboard
- **API integrations**: Check respective service status pages
- **ClackyAI connection**: Verify CORS and backend URL

---

**Version**: 1.0.0  
**Node**: >=18.0.0  
**Last Updated**: 2025-01-27
