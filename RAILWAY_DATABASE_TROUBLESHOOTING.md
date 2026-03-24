# Railway Database Connection Troubleshooting

## Current Situation

✅ **Build:** Successful (49.96 seconds)  
❌ **Health Check:** Failed - "service unavailable"  
✅ **PostgreSQL Service:** Present in project  
✅ **Environment Variables:** You confirmed "All of the variables are there"

## The Problem

Health check failing with repeated "Attempt #1-14 failed with service unavailable" means the Rails app cannot start because `db:prepare` is timing out or failing during the startup process.

## Critical Check: DATABASE_URL Connection

Even though DATABASE_URL exists, it might not be **properly referencing** the Postgres service.

### ⚠️ Verify DATABASE_URL Format

Railway provides TWO ways to connect to Postgres:

1. **Automatic Reference (RECOMMENDED):**
   ```
   ${{Postgres.DATABASE_URL}}
   ```
   This references the Postgres service variable directly

2. **Manual Connection String:**
   ```
   postgresql://postgres:password@postgres.railway.internal:5432/railway
   ```

### 🔍 How to Check

1. Go to **Clacky-clean** service (your Rails app)
2. Click **Variables** tab
3. Find **DATABASE_URL**
4. Check its value:
   - ✅ **Good:** `${{Postgres.DATABASE_URL}}` or `${{PostgreSQL.DATABASE_URL}}`
   - ❌ **Bad:** Empty, undefined, or incorrect connection string

### 🔧 Fix If Needed

**Option A: Use Service Reference (Recommended)**

1. In **Clacky-clean** Variables
2. If DATABASE_URL doesn't exist or is wrong, add/edit it:
   - **Name:** `DATABASE_URL`
   - **Value:** `${{Postgres.DATABASE_URL}}`
   
   Note: The name "Postgres" must match your actual Postgres service name in Railway. Check the exact service name!

**Option B: Manual Connection String**

If the Postgres service has a different name, get the connection details:

1. Click on **Postgres** service
2. Go to **Variables** or **Connect** tab
3. Copy the DATABASE_URL value
4. Add it to **Clacky-clean** service variables

## Common Issues & Solutions

### Issue 1: SERVICE_NAME Mismatch

**Symptom:** DATABASE_URL = `${{Postgres.DATABASE_URL}}` but reference doesn't resolve

**Solution:** Check actual Postgres service name
- Your Postgres service might be called "PostgreSQL", "postgres", "New_Clacky_clean_production", etc.
- Use: `${{ActualServiceName.DATABASE_URL}}`

### Issue 2: Private Networking Not Enabled

**Symptom:** Connection refused even with correct DATABASE_URL

**Solution:** Ensure services can communicate
1. Both services must be in the same project
2. Private networking should work automatically
3. Verify Postgres service is **deployed and active** (green status)

### Issue 3: Postgres Service Not Ready

**Symptom:** Rails app deploys but Postgres is still starting

**Solution:** Wait for Postgres to fully deploy
- Check Postgres service status
- Should show "Active" with green indicator
- Wait 1-2 minutes after Postgres deployment before deploying Rails app

### Issue 4: DATABASE_URL Syntax Error

**Symptom:** Variable exists but contains typo or wrong format

**Solution:** Double-check spelling and format
```
Correct: ${{Postgres.DATABASE_URL}}
Wrong:   ${Postgres.DATABASE_URL}       (single brace)
Wrong:   ${{Postgres.DATABASE URL}}     (space)
Wrong:   ${{postgres.DATABASE_URL}}     (case sensitive!)
```

## Step-by-Step Verification Process

### Step 1: Verify Postgres Service

1. Click on **Postgres** service in Railway
2. Check deployment status: Should show **"Active"** in green
3. Go to **Variables** tab
4. Confirm these exist:
   - `PGHOST`
   - `PGPORT`
   - `PGUSER`
   - `PGPASSWORD`
   - `PGDATABASE`
   - `DATABASE_URL` (automatically generated)

### Step 2: Verify Rails App Variables

1. Click on **Clacky-clean** service
2. Go to **Variables** tab
3. **Essential variables that MUST exist:**
   - `DATABASE_URL` → `${{Postgres.DATABASE_URL}}` (or service reference)
   - `SECRET_KEY_BASE` → (long random string)
   - `RAILS_ENV` → `production` (usually auto-set)
   - `PORT` → Auto-set by Railway (don't manually set)

### Step 3: Check Service Connection

1. In **Clacky-clean** service settings
2. Look for **"Service Variables"** or **"References"** section
3. Confirm Postgres is linked/referenced

### Step 4: Force Redeploy

After verifying/fixing variables:

1. Go to **Clacky-clean** deployments
2. Click **"Deploy"** → **"Redeploy"** on latest deployment
3. Watch logs in real-time
4. Look for these indicators:

**❌ Connection Failed:**
```
PG::ConnectionBad: could not connect to server
FATAL: password authentication failed
connection refused
```

**✅ Connection Success:**
```
Running docker entrypoint
If running the rails server then create or migrate existing database
Created database 'railway'
(or) Database 'railway' already exists
Starting Healthcheck
```

## Quick Fix Checklist

Run through this checklist:

- [ ] Postgres service status is **Active** (green)
- [ ] Postgres service has been deployed for at least 2 minutes
- [ ] DATABASE_URL variable exists in **Clacky-clean** service
- [ ] DATABASE_URL uses correct service reference format: `${{ServiceName.DATABASE_URL}}`
- [ ] ServiceName matches actual Postgres service name (check spelling/case)
- [ ] SECRET_KEY_BASE is set in Clacky-clean
- [ ] Both services are in the same Railway project
- [ ] Tried redeploying Clacky-clean after verifying variables
- [ ] Checked deployment logs for specific error messages

## Advanced Debugging

If basic fixes don't work, check Railway logs for specific errors:

### Check Build Logs

Look for:
- Bundle install errors (we just fixed this)
- Missing gems or dependencies
- Asset compilation failures

### Check Deploy Logs

Look for:
- Database connection errors
- Migration failures
- Port binding errors
- Environment variable issues

### Check Runtime Logs

Look for:
- Puma startup messages
- Database query errors
- Health check attempt logs

## Expected Success Indicators

When everything is working:

```
Feb 4 2026 15:47:06  →  auth  →  sharing credentials for production-europe-west4-dram3a.railway-registry.c
Feb 4 2026 15:47:08  →  auth  →  importing to docker
Feb 4 2026 15:47:22  →  Build time: 49.96 seconds
Feb 4 2026 15:47:38  →  Starting Healthcheck
                         =====================
Feb 4 2026 15:47:38  →  Path: /up
Feb 4 2026 15:47:38  →  Retry window: 300s
Feb 4 2026 15:47:42  →  ✓ Healthcheck passed
Feb 4 2026 15:47:42  →  Deployment complete
```

## What to Do Next

Based on your screenshot showing health check failures:

### Action Required:

1. **Verify DATABASE_URL reference**
   - Go to Clacky-clean → Variables
   - Check DATABASE_URL value
   - Screenshot it and confirm it matches your Postgres service name

2. **Check Postgres service name**
   - What is your Postgres service actually called?
   - Is it "Postgres", "PostgreSQL", "New_Clacky_clean_production"?
   - The ${{}} reference must use the EXACT name

3. **Verify Postgres is active**
   - Click on Postgres service
   - Confirm it shows "Active" status
   - Check that it's not in "Deploying" or "Failed" state

4. **Redeploy after verification**
   - Once DATABASE_URL is confirmed correct
   - Trigger a fresh deployment
   - Monitor logs closely

## Still Failing?

If health check still fails after all checks:

**Screenshot and share:**
1. Clacky-clean Variables tab (showing DATABASE_URL value)
2. Postgres service status/name
3. Latest deployment logs (full log, not just health check section)

This will help identify the specific issue preventing database connection.

---

**Next Step:** Please verify your DATABASE_URL variable in the Clacky-clean service is correctly referencing your Postgres service using the `${{ServiceName.DATABASE_URL}}` format.
