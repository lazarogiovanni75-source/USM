# Railway Deployment Fix - Complete Guide

## ✅ Fixes Applied (February 5, 2026)

### Problem Identified
Both **stellar-reflection** and **Clacky-clean** projects were failing deployment with:
```
ArgumentError: Missing `secret_key_base` for 'production' environment
config.eager_load is set to nil
```

### Root Cause
1. `SECRET_KEY_BASE` was hardcoded in `config/application.yml` instead of reading from environment variables
2. Railway's `SECRET_KEY_BASE` environment variable wasn't being used
3. Missing `preDeployCommand` for database migrations

### Changes Made

#### 1. Fixed `config/application.yml` (Line 14-17)
**Before:**
```yaml
SECRET_KEY_BASE: 'b4c8815864f1b4eb94175952890e688218144e1f3cd279045300112b9b40d01850a9ab718c2198d97e11820c0af3f706feaa3e86de7e08b79024bf7a7684815c'
```

**After:**
```yaml
# Railway will provide SECRET_KEY_BASE via environment variables
SECRET_KEY_BASE: '<%= ENV.fetch("SECRET_KEY_BASE", "b4c8815864f1b4eb94175952890e688218144e1f3cd279045300112b9b40d01850a9ab718c2198d97e11820c0af3f706feaa3e86de7e08b79024bf7a7684815c") %>'
```

**Why:** Now Railway's `SECRET_KEY_BASE` environment variable will be used in production, with fallback to default for development.

#### 2. Updated `railway.json` (Line 12)
**Before:**
```json
{
  "deploy": {
    "startCommand": "bundle exec puma -C config/puma.rb",
    "healthcheckPath": "/up",
    "healthcheckTimeout": 300,
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10
  }
}
```

**After:**
```json
{
  "deploy": {
    "startCommand": "bundle exec puma -C config/puma.rb",
    "healthcheckPath": "/up",
    "healthcheckTimeout": 300,
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10,
    "preDeployCommand": "bundle exec rails db:migrate"
  }
}
```

**Why:** Ensures database migrations run before deployment starts.

---

## 🚀 Next Steps for Railway Deployment

### For Clacky-clean (This Project)

**Current Status:**
- ✅ Configuration fixed
- ✅ `config.eager_load = true` already set
- ✅ PostgreSQL DATABASE_URL already connected
- ✅ SECRET_KEY_BASE environment variable exists
- 🔄 Ready to deploy

**Action Required:**
1. **Commit and push these changes:**
   ```bash
   git add config/application.yml railway.json
   git commit -m "Fix Railway SECRET_KEY_BASE and add preDeployCommand"
   git push origin main
   ```

2. **Railway will automatically redeploy** when you push to GitHub

3. **Monitor deployment:**
   - Go to Railway dashboard → Clacky-clean → Deployments
   - Watch the Deploy Logs tab
   - Should see successful migration and server start

### For stellar-reflection (Separate Project)

**You need to apply the same fixes:**

1. **Clone stellar-reflection repository:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/stellar-reflection.git
   cd stellar-reflection
   ```

2. **Update `config/application.yml`:**
   ```yaml
   SECRET_KEY_BASE: '<%= ENV.fetch("SECRET_KEY_BASE", "YOUR_DEFAULT_KEY_HERE") %>'
   ```

3. **Update `railway.json`:**
   ```json
   {
     "deploy": {
       "preDeployCommand": "bundle exec rails db:migrate"
     }
   }
   ```

4. **Commit and push:**
   ```bash
   git add config/application.yml railway.json
   git commit -m "Fix Railway SECRET_KEY_BASE configuration"
   git push origin main
   ```

---

## ✅ Railway Environment Variables Checklist

### Both Projects Need:

#### Required Variables (Must Have Values)
- ✅ `DATABASE_URL` - PostgreSQL connection string (from Postgres service)
- ✅ `SECRET_KEY_BASE` - Rails encryption key (already exists)
- ✅ `RAILS_ENV` - Should be `production`

#### Optional but Recommended
- `NODE_ENV` - Should be `production`
- `RAILS_LOG_LEVEL` - Recommend `info`
- `RAILS_SERVE_STATIC_FILES` - Set to `true` for Railway

### Clacky-clean Specific Variables
Your variables look good:
- ✅ `CLACKY_ATLAS_CLOUD_API_KEY`
- ✅ `CLACKY_OPENAI_API_KEY`
- ✅ `CLACKY_POSTFORME_API_KEY`
- ✅ `CLACKY_PUBLIC_HOST`
- ✅ `RAILWAY_BACKEND_URL`
- ✅ `PUBLIC_HOST`
- ✅ `EAGER_LOAD` (not needed - we set in config)

### stellar-reflection Specific Variables
Your variables look good:
- ✅ `ALLOWED_ORIGINS`
- ✅ `APP_NAME`
- ✅ `OPENAI_API_KEY`
- ✅ `VERSION`
- ✅ `RAILWAY_API_URL` (custom variable)

---

## 🔍 How to Verify Deployment Success

### 1. Check Deployment Logs
```
Railway Dashboard → Your Project → Deployments → Deploy Logs
```

Look for:
```
✅ "Puma starting in single mode..."
✅ "* Listening on http://0.0.0.0:PORT"
✅ "Use Ctrl-C to stop"
```

### 2. Check Health Endpoint
```bash
curl https://your-app.railway.app/up
```

Should return: `200 OK`

### 3. Test Database Connection
```bash
curl https://your-app.railway.app/
```

Should load your homepage without database errors.

---

## 🐛 Troubleshooting

### If Deployment Still Fails

#### Error: "Missing secret_key_base"
**Solution:** Verify SECRET_KEY_BASE exists in Railway variables:
1. Go to Railway → Your Service → Variables
2. Click eye icon next to `SECRET_KEY_BASE`
3. Make sure it's not empty
4. If empty, generate new one:
   ```bash
   rails secret
   ```
5. Copy and paste into Railway variable

#### Error: "could not connect to server"
**Solution:** DATABASE_URL not connected properly:
1. Go to Railway → Postgres service → Variables
2. Copy `DATABASE_URL` value
3. Go to your Rails service → Variables
4. Update `DATABASE_URL` with the copied value

#### Error: "preDeployCommand failed"
**Solution:** Database migration errors:
1. Check Deploy Logs for specific migration error
2. May need to run migrations manually first
3. Or temporarily remove `preDeployCommand`, deploy, then add it back

---

## 📝 Summary

**What was wrong:**
- SECRET_KEY_BASE wasn't reading from Railway environment variables
- Missing database migration command before deployment

**What we fixed:**
- Changed `config/application.yml` to use `ENV.fetch("SECRET_KEY_BASE")`
- Added `preDeployCommand` to `railway.json`

**What you need to do:**
1. Commit and push changes (Clacky-clean)
2. Apply same fixes to stellar-reflection
3. Monitor deployments in Railway dashboard

**Expected result:**
Both apps should deploy successfully and be accessible at their Railway URLs.

---

## 🎉 Success Indicators

When deployment is successful, you'll see:

1. ✅ Green checkmark in Railway Deployments tab
2. ✅ "Online" status badge on service card
3. ✅ Working URL (click the service to see the URL)
4. ✅ No errors in Deploy Logs
5. ✅ `/up` health check returns 200 OK

---

**Last Updated:** February 5, 2026 12:45 AM PST
**Project:** Clacky-clean (Ultimate Social Media)
**Railway Database:** PostgreSQL connected
