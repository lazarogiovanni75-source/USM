# Railway Setup Fix Checklist

## CRITICAL: Add Missing Environment Variables

Your Railway deployment is missing required environment variables. Add these in Railway **Variables** tab:

### 1. Click on "Variables" tab in Railway

### 2. Add these variables (click "+ New Variable" for each):

```
Variable Name: CLACKY_PUBLIC_HOST
Value: www.ultimatesocialmedia01.com
```

```
Variable Name: SECRET_KEY_BASE
Value: b4c8815864f1b4eb94175952890e688218144e1f3cd279045300112b9b40d01850a9ab718c2198d97e11820c0af3f706feaa3e86de7e08b79024bf7a7684815c
```

```
Variable Name: RAILS_ENV
Value: production
```

### 3. After adding variables, Railway will auto-redeploy

---

## DNS Issue Fix

Your domain shows "Waiting for DNS update" because Railway can't verify the DNS yet.

### Option A: Wait for DNS Propagation (Recommended)
- DNS can take 5-30 minutes to propagate
- Check status at: https://www.whatsmydns.net/#CNAME/www.ultimatesocialmedia01.com
- Once propagated globally, Railway will automatically detect it

### Option B: Force DNS Check
1. Remove the domain from Railway (click the trash icon next to `ultimatesocialmedia01.com`)
2. Wait 1 minute
3. Click **+ Custom Domain** again
4. Re-add: `www.ultimatesocialmedia01.com`
5. Railway will re-check DNS

---

## GoDaddy DNS Verification

Make sure your GoDaddy DNS record is exactly:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| **CNAME** | **www** | **eupmvah7.up.railway.app** | **600** |

**Important**: 
- Remove any conflicting A or CNAME records for `www`
- Make sure there's a trailing dot if GoDaddy requires it: `eupmvah7.up.railway.app.`

---

## Expected Timeline

1. **Add environment variables** → Railway redeploys (2-3 minutes)
2. **DNS propagates** → 5-30 minutes 
3. **Railway detects DNS** → Provisions SSL (5-10 minutes)
4. **Domain goes live** → `https://www.ultimatesocialmedia01.com` works!

---

## Quick Test

After adding environment variables and waiting for DNS, test with:

```bash
curl -I https://www.ultimatesocialmedia01.com
```

If you see `HTTP/2 200` or `301/302 redirect`, it's working!

---

## Still Not Working?

If after 30 minutes the domain still shows "Waiting for DNS update":

1. Verify DNS propagation at https://www.whatsmydns.net/
2. Make sure the CNAME points to `eupmvah7.up.railway.app` (with or without trailing dot)
3. Try removing and re-adding the domain in Railway
4. Contact Railway support if DNS is propagated but Railway won't detect it
