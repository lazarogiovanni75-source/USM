# Service Integration Setup Checklist

Use this checklist to connect all external services to your Ultimate Social Media platform.

---

## 🚂 Railway + ClackyAI Connection

### Railway Backend Deployment
- [ ] Push code to GitHub
- [ ] Create Railway project from GitHub repo
- [ ] Select `railway-backend` directory as root
- [ ] Add environment variables to Railway
- [ ] Deploy and verify URL (e.g., `https://your-app.up.railway.app`)
- [ ] Add `RAILWAY_BACKEND_URL` to Clacky environment variables

### ClackyAI Configuration
- [ ] Update `app/javascript/config/api.js` with Railway backend URL
- [ ] Test connection: `curl https://your-railway-app.up.railway.app/health`

---

## 🎵 ElevenLabs (Voice Generation)

**Website**: https://elevenlabs.io

### Setup Steps
1. [ ] Create ElevenLabs account or sign in
2. [ ] Go to Profile > API Key
3. [ ] Copy your API key (starts with `xi_`)
4. [ ] (Optional) Browse Voice Library and note voice IDs

### Environment Variables
```bash
# In Railway dashboard
ELEVENLABS_API_KEY=your_api_key_here
ELEVENLABS_VOICE_ID=pNInz6obpgDQGcFmaJgB  # Default voice (Adam)
```

### Verification
```bash
curl https://your-railway-app.up.railway.app/api/voices
# Should return list of available voices
```

---

## 🤖 OpenAI (AI Content Generation)

**Website**: https://platform.openai.com

### Setup Steps
1. [ ] Create OpenAI account or sign in
2. [ ] Go to API Keys > Create new secret key
3. [ ] Copy the key (starts with `sk-`)
4. [ ] Check Usage page for rate limits
5. [ ] (Optional) Add organization ID if using org account

### Environment Variables
```bash
# In Railway dashboard
OPENAI_API_KEY=your_api_key_here
OPENAI_MODEL=gpt-4o-mini  # Default model
# OPENAI_ORG_ID=org_xxx  # Optional
```

### Verification
```bash
curl -X POST https://your-railway-app.up.railway.app/api/ai/generate-content \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Write a tweet about technology"}'
# Should return AI-generated content
```

---

## 🎬 Atlas Cloud (Video Generation)

**Website**: https://atlascloud.ai

### Setup Steps
1. [ ] Create Atlas Cloud account or sign in
2. [ ] Go to Dashboard > API
3. [ ] Copy your API key

### Environment Variables
```bash
# In Railway dashboard
ATLASCLOUD_API_KEY=your_api_key_here
ATLASCLOUD_BASE_URL=https://api.atlascloud.ai  # default
```

### Verification
```bash
curl -X POST https://your-railway-app.up.railway.app/api/video/generate \
  -H "Content-Type: application/json" \
  -d '{"script": "Hello World!", "style": "social"}'
# Should return video render URL
```

---

## 🔗 Zapier (Automation)

**Website**: https://zapier.com

### Setup Steps
1. [ ] Create Zapier account or sign in
2. [ ] Click "Create Zap"
3. [ ] Search for "Webhooks by Zapier" as trigger
4. [ ] Select "Catch Hook" event
5. [ ] Test the trigger and copy webhook URL
6. [ ] Finish setting up your Zap (add actions for email, Slack, etc.)
7. [ ] Turn on the Zap

### Environment Variables
```bash
# In Railway dashboard (if using webhook triggers)
ZAPIER_WEBHOOK_URL=https://hooks.zapier.com/hooks/catch/xxxxx/yyyyy/
```

### Usage in Code
```ruby
# The Rails backend already has Zapier integration
# Configure webhook URL in environment variables
```

---

## ⚡ Make.com (Automation)

**Website**: https://make.com

### Setup Steps
1. [ ] Create Make account or sign in
2. [ ] Go to Profile > API Key
3. [ ] Copy your API key
4. [ ] Create a new scenario
5. [ ] Add webhook as first module
6. [ ] Copy webhook URL
7. [ ] Add actions (email, social media posting, etc.)
8. [ ] Turn on the scenario

### Environment Variables
```bash
# In Railway dashboard
MAKEAI_API_KEY=your_api_key_here
MAKEAI_WEBHOOK_URL=https://hook.make.com/your_scenario_id
```

---

## 📋 Complete Environment Variable List

### Railway Backend (.env)
```
ELEVENLABS_API_KEY=xi_xxxxxxxxxxxxxxxx
OPENAI_API_KEY=sk-xxxxxxxxxxxxxxxx
ATLASCLOUD_API_KEY=xxxxxxxxxxxxxxxx
MAKEAI_API_KEY=xxxxxxxxxxxxxxxx
ZAPIER_WEBHOOK_URL=https://hooks.zapier.com/hooks/catch/xxxxx/yyyyy/
MAKEAI_WEBHOOK_URL=https://hook.make.com/xxxxx
PORT=3000
NODE_ENV=production
ALLOWED_ORIGINS=https://your-thread.clacky.app,http://localhost:3000
ELEVENLABS_VOICE_ID=pNInz6obpgDQGcFmaJgB
OPENAI_MODEL=gpt-4o-mini
```

### ClackyAI Environment
```
RAILWAY_BACKEND_URL=https://your-app.up.railway.app
```

---

## 🧪 Testing Commands

### Health Check
```bash
curl https://your-railway-app.up.railway.app/health
```

### Test All Integrations
```bash
# ElevenLabs
curl -X POST https://your-railway-app.up.railway.app/api/voices

# OpenAI
curl -X POST https://your-railway-app.up.railway.app/api/ai/generate-content \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Write a LinkedIn post about productivity", "platform": "linkedin"}'

# Atlas Cloud
curl -X POST https://your-railway-app.up.railway.app/api/video/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Amazing product launch!"}'
```

---

## ❓ Troubleshooting

### LLM Provider Errors
| Error | Solution |
|-------|----------|
| "LLM provider error" | Check `CLACKY_LLM_API_KEY` is set |
| "Rate limit exceeded" | Wait and retry, or upgrade plan |
| "Invalid API key" | Verify key in provider dashboard |

### ElevenLabs Issues
| Error | Solution |
|-------|----------|
| 401 Unauthorized | Check API key validity |
| 429 Too Many Requests | Implement rate limiting |

### OpenAI Issues
| Error | Solution |
|-------|----------|
| 401 Invalid key | Regenerate API key |
| 429 Rate limit | Use gpt-4o-mini or wait |

### Atlas Cloud Issues
| Error | Solution |
|-------|----------|
| Video generation failed | Check API key and quota |
| Rate limit | Wait and retry |

---

## 📞 Support Links

- **ClackyAI**: contact@clacky.ai
- **ElevenLabs**: https://elevenlabs.io/support
- **OpenAI**: https://help.openai.com
- **Atlas Cloud**: https://atlascloud.ai/support
- **Zapier**: https://zapier.com/help
- **Make**: https://make.com/help
- **Railway**: https://discord.gg/railway
