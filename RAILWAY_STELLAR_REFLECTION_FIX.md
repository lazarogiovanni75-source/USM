# Fix stellar-reflection Backend Service - Health Check Failure

## Problem Identified

**Service:** stellar-reflection (Backend)  
**Status:** Build succeeded (60.85 seconds), Health check failing  
**Error:** "Attempt #1-13 failed with service unavailable"

## Root Cause

The backend service is a Rails application that runs `db:prepare` during startup (via `bin/docker-entrypoint`). Without `DATABASE_URL` configured, the database connection fails and the app never starts, causing health check timeouts.

## Solution: Add DATABASE_URL Variable

### Step 1: Go to stellar-reflection Variables

1. In Railway, click on **stellar-reflection** service
2. Click **Variables** tab
3. Click **"+ New Variable"**

### Step 2: Add DATABASE_URL Reference

**Variable Name:** `DATABASE_URL`  
**Variable Value:** `${{Postgres.DATABASE_URL}}`

This references the Postgres service in the same Main-Rails-App project.

### Step 3: Verify Other Required Variables

Make sure these are also set:

**Required:**
- ✅ `DATABASE_URL` = `${{Postgres.DATABASE_URL}}` (service reference)
- ✅ `SECRET_KEY_BASE` = (long random string - check if Railway auto-generated)
- ✅ `RAILS_ENV` = `production` (usually auto-set)

**Optional Backend-Specific:**
- `RAILWAY_BACKEND_URL` = Your backend domain (if needed)
- API keys for any services the backend uses

### Step 4: Redeploy

After adding DATABASE_URL:
1. Railway will automatically trigger a redeploy
2. Watch the deployment logs
3. Health check should pass within 60-120 seconds

## Expected Success Logs

After fixing DATABASE_URL, you should see:

```
Feb 4 2026 16:31:09  →  Build time: 60.85 seconds
Feb 4 2026 16:31:28  →  Starting Healthcheck
                         =====================
Feb 4 2026 16:31:28  →  Path: /up
Feb 4 2026 16:31:28  →  Retry window: 300s
Feb 4 2026 16:31:35  →  Running docker entrypoint
Feb 4 2026 16:31:35  →  If running the rails server then create or migrate existing database
Feb 4 2026 16:31:38  →  Database 'railway' created (or already exists)
Feb 4 2026 16:31:42  →  ✓ Healthcheck passed
Feb 4 2026 16:31:42  →  Deployment complete
```

## Why This Happens

Your backend uses the same Rails base template as your frontend:
- **Template:** `ghcr.io/clacky-ai/rails-base-template:latest`
- **Entrypoint:** Runs `./bin/rails db:prepare` before starting server
- **Requirement:** Needs `DATABASE_URL` to connect to PostgreSQL
- **Failure:** Without database connection, startup hangs and health check times out

## Current Main-Rails-App Architecture

After this fix, your structure will be:

```
Main-Rails-App Project
├── Postgres (Online) ✅
│   └── Provides: DATABASE_URL variable
├── Clacky-clean (Online) ✅ - Frontend Rails app
│   └── Uses: ${{Postgres.DATABASE_URL}}
└── stellar-reflection (Deploying) ⏳ - Backend Rails app
    └── Needs: ${{Postgres.DATABASE_URL}} (ADD THIS)
```

## Quick Checklist

- [ ] Go to stellar-reflection service in Railway
- [ ] Click Variables tab
- [ ] Add `DATABASE_URL` = `${{Postgres.DATABASE_URL}}`
- [ ] Save (Railway auto-redeploys)
- [ ] Watch logs for successful health check
- [ ] Verify service shows "Online" status

## After stellar-reflection is Online

Once all three services are running:
1. ✅ Postgres - Online
2. ✅ Clacky-clean - Online  
3. ✅ stellar-reflection - Online

You can then delete these old projects:
- **New_Clacky_clean** (backend now in Main-Rails-App)
- **New-Postgres** (unused, Postgres is in Main-Rails-App)
- **successful-strength** (empty)

This will clean up your Railway dashboard to just 1 project with 3 services.

---

**Next Step:** Add `DATABASE_URL` variable to stellar-reflection service pointing to `${{Postgres.DATABASE_URL}}`
