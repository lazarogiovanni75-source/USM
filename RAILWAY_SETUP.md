# Railway Environment Variables Setup

## Required Environment Variables for Production

Add these variables in your Railway dashboard under **Variables** tab:

### 1. Domain Configuration
```
CLACKY_PUBLIC_HOST=www.ultimatesocialmedia01.com
```

### 2. Secret Key (CRITICAL - Required for Rails)
```
SECRET_KEY_BASE=b4c8815864f1b4eb94175952890e688218144e1f3cd279045300112b9b40d01850a9ab718c2198d97e11820c0af3f706feaa3e86de7e08b79024bf7a7684815c
```

### 3. Database (Should already be set by Railway)
```
DATABASE_URL=<Railway will auto-populate this>
```

### 4. Rails Environment
```
RAILS_ENV=production
```

## GoDaddy DNS Configuration

Your DNS record in GoDaddy should be:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| CNAME | www | eupmvah7.up.railway.app | 600 |

## Verification Steps

1. **Add the environment variables in Railway** (especially `SECRET_KEY_BASE` and `CLACKY_PUBLIC_HOST`)
2. **Redeploy** (Railway should auto-redeploy after adding variables)
3. **Wait for DNS propagation** (5-30 minutes)
4. **Test your site**: Visit `https://www.ultimatesocialmedia01.com`

## Current Issues Fixed

✅ Generated `SECRET_KEY_BASE` - Rails now has proper encryption key
✅ Set `config.eager_load = true` - Production mode properly configured
✅ Added domain to `config.hosts` - Rails will accept requests from your domain
✅ DNS CNAME record configured - Points www to Railway

## Next Steps

1. In Railway Variables tab, add:
   - `CLACKY_PUBLIC_HOST` = `www.ultimatesocialmedia01.com`
   - `SECRET_KEY_BASE` = `b4c8815864f1b4eb94175952890e688218144e1f3cd279045300112b9b40d01850a9ab718c2198d97e11820c0af3f706feaa3e86de7e08b79024bf7a7684815c`

2. Commit and push changes to trigger redeploy:
   ```bash
   git add .
   git commit -m "Fix production configuration"
   git push
   ```

3. Monitor deployment logs in Railway to verify successful startup

4. Once deployed and DNS propagates, visit: `https://www.ultimatesocialmedia01.com`
