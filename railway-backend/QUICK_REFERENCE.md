# 🚀 Railway Backend - Quick Reference

**Production URL:** `https://clacky-clean-production-c2a4.up.railway.app`

---

## Essential Endpoints

```bash
# Health check (Railway monitoring)
curl https://clacky-clean-production-c2a4.up.railway.app/health

# System metrics
curl https://clacky-clean-production-c2a4.up.railway.app/metrics

# Generate content
curl -X POST https://clacky-clean-production-c2a4.up.railway.app/api/ai/generate-content \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Write a tweet about AI"}'

# Chat with AI
curl -X POST https://clacky-clean-production-c2a4.up.railway.app/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello, how are you?"}'
```

---

## Rate Limits

| Endpoint Type | Limit | Window |
|--------------|-------|--------|
| General API | 100 requests | 15 minutes |
| AI Endpoints | 50 requests | 1 hour |
| Video Generation | 10 requests | 1 hour |

---

## Environment Variables

```bash
PORT=3000
NODE_ENV=production
ALLOWED_ORIGINS=https://ultimatesocialmedia01.com
OPENAI_API_KEY=sk-xxxxx
ATLAS_CLOUD_API_KEY=your-key
```

---

## Features

✅ Production-grade error handling  
✅ Rate limiting & security headers  
✅ Comprehensive monitoring  
✅ Database connection pooling  
✅ Graceful shutdown  
✅ Auto-retry on failures  
✅ Request/response logging  
✅ CORS configured  

---

## Documentation

- Full API docs: `railway-backend/README.md`
- Status report: `docs/RAILWAY_STATUS.md`
- GitHub: Commit `3ef6f82`

---

**Last Updated:** Feb 4, 2024  
**Status:** 🟢 PRODUCTION READY
