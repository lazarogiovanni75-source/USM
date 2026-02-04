# 🌐 Connect Your Domain to Railway Backend

## Quick Overview

You have **TWO Railway deployments** that need domain configuration:

1. **Rails Frontend** (Main App) - Already documented in `docs/domain-setup.md`
2. **Node.js Backend API** - **THIS GUIDE** ⬅️ You are here

Your Railway backend URL: `https://clacky-clean-production-c2a4.up.railway.app`

---

## 🎯 What Domain Do You Want?

Choose one of these patterns:

### Option A: Subdomain (Recommended)
**Example:** `api.yourdomain.com`

✅ **Pros:**
- Clean separation between frontend and backend
- Easy to manage
- Professional structure
- Simple CORS configuration

❌ **Cons:**
- One extra DNS record

**Best for:** Most production apps

---

### Option B: Path-based (Same Domain)
**Example:** `yourdomain.com/api`

✅ **Pros:**
- Single domain
- No CORS issues

❌ **Cons:**
- Requires reverse proxy setup
- More complex configuration
- Not supported directly by Railway

**Best for:** Advanced setups with custom infrastructure

---

## 📋 Step-by-Step: Connect Subdomain (Recommended)

### Step 1: Choose Your Subdomain

**Examples:**
- `api.yourdomain.com` ← Recommended
- `backend.yourdomain.com`
- `services.yourdomain.com`

For this guide, we'll use `api.yourdomain.com`

---

### Step 2: Add Domain in Railway (Backend Project)

1. Go to [Railway Dashboard](https://railway.app/dashboard)
2. **Select your BACKEND project** (Node.js Express API)
   - Current URL: `clacky-clean-production-c2a4.up.railway.app`
3. Click on **Settings** tab
4. Scroll to **Networking** section
5. Click **+ Add Domain** (or **Custom Domain**)
6. Enter your subdomain: `api.yourdomain.com`
7. Click **Add**

**Railway will show you DNS records to add:**
```
Type: CNAME
Name: api
Value: clacky-clean-production-c2a4.up.railway.app
TTL: 600
```

---

### Step 3: Add DNS Record in GoDaddy

1. Log into [GoDaddy](https://www.godaddy.com/)
2. Go to **My Products** → **Domains**
3. Click **DNS** next to your domain
4. Click **Add New Record**

**Add CNAME Record:**
- **Type**: `CNAME`
- **Name**: `api` (this creates api.yourdomain.com)
- **Value**: `clacky-clean-production-c2a4.up.railway.app`
- **TTL**: `600 seconds` (or 1 hour)
- Click **Save**

**⚠️ Remove Conflicts:**
If you see an existing CNAME or A record for `api`, delete it first.

---

### Step 4: Update Backend CORS Configuration

Your backend needs to allow requests from your frontend domain.

**Update `railway-backend/.env` on Railway:**

1. In Railway backend project, go to **Variables** tab
2. Update or add these variables:

```bash
# Your custom frontend domain
ALLOWED_ORIGINS=https://yourdomain.com,https://www.yourdomain.com

# Backend URL (will be your custom domain)
BACKEND_URL=https://api.yourdomain.com

# Other existing variables
OPENAI_API_KEY=sk-xxxxx
DEFAPI_API_KEY=xxxxx
NODE_ENV=production
```

**OR** if using comma-separated multiple origins:
```bash
ALLOWED_ORIGINS=https://yourdomain.com,https://www.yourdomain.com,https://api.yourdomain.com
```

---

### Step 5: Update Frontend Configuration (Rails)

Your Rails app needs to point to the new backend URL.

**Update `config/application.yml`:**

```yaml
# Before
RAILWAY_BACKEND_URL: 'https://clacky-clean-production-c2a4.up.railway.app'

# After
RAILWAY_BACKEND_URL: 'https://api.yourdomain.com'
```

**Then update Railway environment for Rails app:**

1. Go to Railway Dashboard → **Rails Frontend Project**
2. Go to **Variables** tab
3. Update `RAILWAY_BACKEND_URL` = `https://api.yourdomain.com`
4. Redeploy if needed

---

### Step 6: Wait for DNS Propagation

**Timeline:**
- Initial: 5-10 minutes
- Full: Up to 1-2 hours (rarely needed)

**Check DNS status:**

```bash
# Check CNAME record
nslookup api.yourdomain.com

# Should return:
# api.yourdomain.com canonical name = clacky-clean-production-c2a4.up.railway.app
```

**Online tools:**
- https://www.whatsmydns.net/
- https://dnschecker.org/

---

### Step 7: Verify SSL Certificate

Railway automatically provisions SSL certificates:

1. Wait 5-10 minutes after DNS propagates
2. In Railway backend project, go to **Settings** → **Networking**
3. Your custom domain should show **SSL: Active**
4. This happens automatically - no action needed

---

### Step 8: Test Your Backend Domain

Once DNS propagates and SSL is active:

```bash
# Test health endpoint
curl https://api.yourdomain.com/health

# Expected response:
{
  "status": "ok",
  "service": "ultimate-social-media-api",
  "timestamp": "2024-02-04T...",
  "version": "1.0.0"
}

# Test metrics
curl https://api.yourdomain.com/metrics

# Test AI endpoint
curl -X POST https://api.yourdomain.com/api/ai/generate-content \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Write an inspiring tweet"}'
```

---

## 🔧 Configuration Summary

### GoDaddy DNS Records

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | @ | [Railway IP from frontend] | 600 |
| CNAME | www | yourdomain.com | 600 |
| CNAME | api | clacky-clean-production-c2a4.up.railway.app | 600 |

### Railway Backend Environment Variables

```bash
ALLOWED_ORIGINS=https://yourdomain.com,https://www.yourdomain.com
BACKEND_URL=https://api.yourdomain.com
NODE_ENV=production
OPENAI_API_KEY=sk-xxxxx
DEFAPI_API_KEY=xxxxx
```

### Railway Frontend (Rails) Environment Variables

```bash
RAILWAY_BACKEND_URL=https://api.yourdomain.com
CLACKY_PUBLIC_HOST=yourdomain.com
```

---

## 🚨 Troubleshooting

### "This site can't be reached"

**Cause:** DNS hasn't propagated yet

**Solution:**
1. Wait 10-30 minutes
2. Clear browser cache or use incognito
3. Check DNS with `nslookup api.yourdomain.com`
4. Verify CNAME record in GoDaddy

---

### SSL Certificate Not Provisioning

**Cause:** DNS not fully propagated or incorrect CNAME

**Solution:**
1. Wait 15-20 minutes after DNS propagates
2. Verify CNAME points to exact Railway domain
3. Check Railway dashboard for SSL status
4. Contact Railway support if stuck

---

### CORS Errors in Browser Console

**Error:** `Access-Control-Allow-Origin` header missing

**Solution:**
1. Verify `ALLOWED_ORIGINS` in Railway backend includes your frontend domain
2. Should be: `https://yourdomain.com` (no trailing slash)
3. Redeploy backend after updating environment variables
4. Clear browser cache

---

### API Returns 502 or 503

**Cause:** Backend not running or incorrect domain configuration

**Solution:**
1. Check Railway backend deployment logs
2. Verify backend is running: `curl https://api.yourdomain.com/health`
3. Check Railway metrics for errors
4. Verify environment variables are set correctly

---

### Frontend Can't Connect to Backend

**Cause:** `RAILWAY_BACKEND_URL` not updated in Rails app

**Solution:**
1. Update `config/application.yml` in Rails project
2. Update `RAILWAY_BACKEND_URL` in Railway frontend variables
3. Redeploy frontend
4. Test connection: Check browser network tab for API calls

---

## ✅ Verification Checklist

Before considering domain connection complete:

- [ ] DNS CNAME record added in GoDaddy for `api`
- [ ] DNS propagated (check with `nslookup`)
- [ ] Railway shows SSL: Active for custom domain
- [ ] `curl https://api.yourdomain.com/health` returns 200 OK
- [ ] Backend `ALLOWED_ORIGINS` includes frontend domain
- [ ] Frontend `RAILWAY_BACKEND_URL` updated to `https://api.yourdomain.com`
- [ ] No CORS errors in browser console
- [ ] Frontend can make API calls to backend successfully

---

## 🎊 Success!

Once all checks pass, your architecture looks like this:

```
Frontend: https://yourdomain.com
          ↓
Backend:  https://api.yourdomain.com
          ↓
Services: OpenAI, DefAPI, PostgreSQL
```

**Professional, scalable, production-ready!** 🚀

---

## 📞 Need Help?

**Railway Issues:**
- Check Railway docs: https://docs.railway.app/
- Railway Discord: https://discord.gg/railway

**GoDaddy DNS Issues:**
- GoDaddy support: https://www.godaddy.com/help

**This Project:**
- Check deployment logs in Railway dashboard
- Review `railway-backend/README.md` for API documentation
- Test endpoints with `curl` commands above
