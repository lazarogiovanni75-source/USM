# 🚀 Domain Connection - Quick Start

**Goal:** Connect your custom domain to both Railway deployments

---

## 📌 What You Need

1. **Your domain name:** (e.g., `yourdomain.com`)
2. **GoDaddy access:** Login credentials
3. **Railway access:** Dashboard access to both projects
4. **15 minutes:** For DNS propagation

---

## 🎯 Quick Setup (5 Steps)

### 1️⃣ Choose Your Domains

```
Frontend (Rails):  yourdomain.com
Backend API:       api.yourdomain.com
```

### 2️⃣ Add Domains in Railway

**Frontend Project:**
- Settings → Networking → Add Domain
- Enter: `yourdomain.com`
- Note the IP address shown

**Backend Project:**
- Settings → Networking → Add Domain  
- Enter: `api.yourdomain.com`
- CNAME will point to: `clacky-clean-production-c2a4.up.railway.app`

### 3️⃣ Configure GoDaddy DNS

Go to GoDaddy → My Products → Domains → DNS → Add Records:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | @ | [Railway IP from frontend] | 600 |
| CNAME | www | yourdomain.com | 600 |
| CNAME | api | clacky-clean-production-c2a4.up.railway.app | 600 |

### 4️⃣ Update Environment Variables

**Backend (Node.js) - Railway Variables:**
```bash
ALLOWED_ORIGINS=https://yourdomain.com,https://www.yourdomain.com
```

**Frontend (Rails) - Railway Variables:**
```bash
RAILWAY_BACKEND_URL=https://api.yourdomain.com
CLACKY_PUBLIC_HOST=yourdomain.com
```

**Local `config/application.yml`:**
```yaml
RAILWAY_BACKEND_URL: 'https://api.yourdomain.com'
PUBLIC_HOST: 'yourdomain.com'
```

### 5️⃣ Wait & Test

**Wait:** 5-30 minutes for DNS propagation

**Test:**
```bash
# Check DNS
nslookup yourdomain.com
nslookup api.yourdomain.com

# Test frontend
curl https://yourdomain.com

# Test backend
curl https://api.yourdomain.com/health
```

---

## ✅ Success Checklist

- [ ] DNS records added in GoDaddy
- [ ] Railway shows SSL: Active for both domains
- [ ] Frontend loads at `https://yourdomain.com`
- [ ] Backend responds at `https://api.yourdomain.com/health`
- [ ] No CORS errors in browser console
- [ ] Frontend can call backend APIs successfully

---

## 🆘 Common Issues

### "Site can't be reached"
→ Wait longer for DNS propagation (up to 30 min)  
→ Clear browser cache or use incognito mode

### SSL Certificate Not Active
→ Wait 10-15 minutes after DNS propagates  
→ Verify DNS records are correct in GoDaddy

### CORS Errors
→ Check `ALLOWED_ORIGINS` includes your frontend domain  
→ No trailing slashes in URLs  
→ Redeploy backend after updating variables

---

## 📚 Full Documentation

- **Detailed Guide:** `docs/DOMAIN_CONNECTION_GUIDE.md`
- **Backend API Docs:** `railway-backend/README.md`
- **Frontend Setup:** `docs/domain-setup.md`

---

**Need help?** Check the full guides above or Railway dashboard logs.
