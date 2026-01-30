# Railway Backend - Quick Setup Checklist

## ⚡ 5-Minute Setup

Follow this checklist to connect your Railway backend to all third-party services.

---

## ✅ Step 1: Access Railway Dashboard

1. Go to **https://railway.app/dashboard**
2. Find project: `clacky-backend-clean-production`
3. Click on your backend service
4. Go to **Variables** tab

---

## ✅ Step 2: Add Required API Keys

Add these variables one by one:

### OpenAI (Required)
```
Variable: OPENAI_API_KEY
Value: sk-proj-[your-key-here]
```
- Get key: https://platform.openai.com/api-keys
- Click "Create new secret key"
- Copy immediately (can't view later)

### ElevenLabs (Required)
```
Variable: ELEVENLABS_API_KEY
Value: [your-key-here]
```
- Get key: https://elevenlabs.io → Profile → API Key
- Click "Copy" button

### Shotstack (Required)
```
Variable: SHOTSTACK_API_KEY
Value: [your-key-here]
```
```
Variable: SHOTSTACK_ENVIRONMENT
Value: stage
```
- Get key: https://dashboard.shotstack.io → API Keys
- Use "Stage" key for testing (free)

### Make.com or Zapier (Optional - pick one)

**Option A: Make.com**
```
Variable: MAKEAI_API_KEY
Value: [your-token-here]
```
- Get token: https://make.com → Profile → Organizations → API → Generate token

**Option B: Zapier**
```
Variable: ZAPIER_WEBHOOK_URL
Value: https://hooks.zapier.com/hooks/catch/xxxxx/yyyyy/
```
- Create Zap → Webhooks by Zapier trigger → Copy URL

---

## ✅ Step 3: Configure CORS

Add your ClackyAI frontend URL:

```
Variable: ALLOWED_ORIGINS
Value: https://your-thread.clacky.app
```

Replace `your-thread.clacky.app` with your actual ClackyAI domain.

---

## ✅ Step 4: Verify Deployment

Railway automatically redeploys after adding variables. Wait ~30 seconds, then test:

```bash
curl https://clacky-backend-clean-production.up.railway.app/health
```

**Expected response:**
```json
{"status":"ok","service":"ultimate-social-media-api"}
```

---

## ✅ Step 5: Test API Integrations

### Test OpenAI
```bash
curl -X POST https://clacky-backend-clean-production.up.railway.app/api/ai/generate-content \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Write a tweet about AI","platform":"twitter"}'
```

### Test ElevenLabs
```bash
curl -X POST https://clacky-backend-clean-production.up.railway.app/api/voice/generate \
  -H "Content-Type: application/json" \
  -d '{"text":"Hello world"}' \
  --output test.mp3
```

### Test Shotstack
```bash
curl -X POST https://clacky-backend-clean-production.up.railway.app/api/video/generate \
  -H "Content-Type: application/json" \
  -d '{"script":"Test video"}'
```

---

## 🎯 All Done!

Your Railway backend is now connected to:
- ✅ OpenAI (AI content generation)
- ✅ ElevenLabs (voice generation)
- ✅ Shotstack (video generation)
- ✅ Make.com/Zapier (automation)

ClackyAI → Railway → Third-Party APIs ✨

---

## 📚 Need More Help?

- **Full Guide:** See `docs/RAILWAY_API_KEYS_GUIDE.md`
- **Deployment Guide:** See `docs/RAILWAY_DEPLOYMENT_GUIDE.md`
- **Backend Code:** See `railway-backend/README.md`

---

## 🔍 Troubleshooting

**Problem:** Health check returns 404
- **Solution:** Service not deployed. Check Railway Deployments tab.

**Problem:** "API key not configured" error
- **Solution:** Variable not set. Check Railway Variables tab.

**Problem:** "Invalid API key" error
- **Solution:** Wrong key. Regenerate in service dashboard.

**Problem:** CORS error in browser
- **Solution:** Add frontend URL to ALLOWED_ORIGINS variable.

---

## 💰 Cost Estimates (Free Tiers)

- OpenAI: $5 free credit (new users)
- ElevenLabs: 10,000 chars/month free
- Shotstack: 20 videos/month free (stage environment)
- Make.com: 1,000 operations/month free
- Zapier: 100 tasks/month free
- Railway: $5/month credit included

**Total estimated cost for light usage:** ~$5-15/month

---

**Railway Backend URL:** https://clacky-backend-clean-production.up.railway.app
