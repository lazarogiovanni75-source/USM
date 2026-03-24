# Railway Health Check Failure Fix

## Problem Identified

Your Railway deployment is failing with health check errors because the application cannot start properly.

**From the logs:**
```
Attempt #1-14 failed with service unavailable. Continuing to retry...
Healthcheck failed!
1/1 replicas never became healthy!
```

## Root Cause

The health check at `/up` is timing out because the application startup is failing. Based on the deployment logs, the issue is:

1. **Database Connection**: The `bin/docker-entrypoint` script runs `db:prepare` during startup
2. **Missing DATABASE_URL**: Railway needs a PostgreSQL database connected
3. **Startup Timeout**: Without database connection, the app never becomes "healthy"

## Solution: Add PostgreSQL Database to Railway

### Step 1: Add PostgreSQL Database Service

1. Go to your Railway project dashboard
2. Click **"+ New"** button
3. Select **"Database"** → **"Add PostgreSQL"**
4. Railway will create a PostgreSQL database service

### Step 2: Connect Database to Rails App

Railway automatically adds a `DATABASE_URL` variable when you add PostgreSQL to your project. Verify it:

1. Go to your **Main Rails App** service
2. Click **Variables** tab
3. You should see **`DATABASE_URL`** variable (automatically added by Railway)
4. Format should be: `postgresql://user:pass@host:port/database`

### Step 3: Verify Environment Variables Are Set

Make sure these critical variables are set in **Main Rails App**:

**Required Variables:**
- ✅ `DATABASE_URL` (auto-added by PostgreSQL service)
- ✅ `SECRET_KEY_BASE` (your Rails secret)
- ✅ `CLACKY_PUBLIC_HOST` (e.g., `ultimatesocialmedia01.com` or `www.ultimatesocialmedia01.com`)

**API Keys (from previous setup):**
- ✅ `CLACKY_OPENAI_API_KEY` (new OpenAI key you just created)
- ✅ `CLACKY_ATLAS_CLOUD_API_KEY` (Atlas Cloud API key for video generation)
- ✅ `CLACKY_POSTFORME_API_KEY` (Postforme API key - or use default)

### Step 4: Redeploy

After adding PostgreSQL:
1. Railway will automatically trigger a redeploy
2. Watch the deployment logs
3. Look for these success indicators:
   ```
   Running docker entrypoint
   Check if application.yml and database.yml are present
   If running the rails server then create or migrate existing database
   Build time: XX.XX seconds
   Starting Healthcheck
   Path: /up
   Retry window: 300s
   ```
4. Health check should succeed within 60 seconds

## Alternative: Check if Database Already Exists

If you already added PostgreSQL but it's not connecting:

### Check Database Service
1. Look for **PostgreSQL** service in your Railway project
2. Click on it → Go to **"Connect"** tab
3. Copy the **Public URL** (or use internal connection)

### Manually Add DATABASE_URL (if missing)
1. Go to **Main Rails App** → **Variables**
2. Add **`DATABASE_URL`**
3. Value: `postgresql://postgres:[password]@[host]:[port]/railway`
4. Get these values from PostgreSQL service "Connect" tab

## Common Issues & Fixes

### Issue 1: "PG::ConnectionBad: could not connect"
**Solution:** DATABASE_URL is incorrect or PostgreSQL service is not running
- Verify PostgreSQL service is deployed
- Check DATABASE_URL format
- Ensure Rails app and PostgreSQL are in same project

### Issue 2: "Healthcheck failed - connection refused"
**Solution:** App is not binding to correct port
- Verify `PORT` env var is set (Railway auto-sets this)
- Check `config/puma.rb` binds to `0.0.0.0:#{PORT}`

### Issue 3: "Secret key base is not set"
**Solution:** Add SECRET_KEY_BASE variable
```bash
# Generate a new secret:
# Run locally: bundle exec rails secret
# Then add to Railway variables
```

### Issue 4: Health check timeout (300s exceeded)
**Solution:** Database migrations taking too long
- Check if you have large seed data
- Consider running migrations separately first
- Increase healthcheck timeout in railway.toml

## Testing After Fix

### 1. Check Deployment Status
Watch Railway logs for:
```
✓ Starting Healthcheck
✓ Build time: XX.XX seconds
✓ [Healthcheck passed]
```

### 2. Test Health Endpoint
```bash
curl https://api.ultimatesocialmedia01.com/up
# Should return: OK
```

### 3. Test Main Site
```bash
curl https://www.ultimatesocialmedia01.com
# Should return HTML (not 502/503 error)
```

### 4. Check Database Connection
```bash
# In Railway shell (if available) or logs:
bin/rails runner "puts ActiveRecord::Base.connection.active?"
# Should output: true
```

## What Happens During Startup

1. **Docker container starts**
2. **Entrypoint runs** (`bin/docker-entrypoint`)
3. **Database check** - `db:prepare` connects to PostgreSQL
4. **Migrations run** - Updates database schema
5. **Puma starts** - Rails server binds to port
6. **Health check begins** - Railway pings `/up` endpoint
7. **Success** - If `/up` returns 200 OK, deployment succeeds

## Current Configuration

Your app is configured with:
- **Health check path:** `/up`
- **Health check timeout:** 300 seconds (5 minutes)
- **Restart policy:** ON_FAILURE
- **Max retries:** 10

The health check endpoint (`/up`) is simple and just returns "OK":
```ruby
# app/controllers/rails/health_controller.rb
def show
  render plain: "OK", status: :ok
end
```

## Quick Checklist

- [ ] PostgreSQL service added to Railway project
- [ ] DATABASE_URL variable exists in Main Rails App
- [ ] SECRET_KEY_BASE variable is set
- [ ] CLACKY_PUBLIC_HOST variable is set
- [ ] OpenAI API key added (CLACKY_OPENAI_API_KEY)
- [ ] App redeployed after adding variables
- [ ] Health check passes (check logs)
- [ ] Site accessible at your domain

## Need More Help?

If the issue persists after adding PostgreSQL:

1. **Check Railway logs** for specific error messages
2. **Verify all environment variables** are correctly set
3. **Test database connection** independently
4. **Check Railway status** - https://status.railway.app

---

**Expected Outcome:** After adding PostgreSQL database service, your deployment should succeed within 60-120 seconds and the health check will pass.

**Last Updated:** February 4, 2026
