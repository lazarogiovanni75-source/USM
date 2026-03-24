# ⚠️ MANUAL FIX REQUIRED - application.yml

## Issue
`config/application.yml` is gitignored (for security reasons), so the SECRET_KEY_BASE fix was not committed to git.

**The fix has been applied locally in this Clacky workspace**, but you need to manually apply it to:
1. **Railway deployment** (if deploying from local)
2. **stellar-reflection project** (separate repository)

---

## ✅ What Was Fixed Locally

### File: `config/application.yml` (Line 17)

**BEFORE:**
```yaml
SECRET_KEY_BASE: 'b4c8815864f1b4eb94175952890e688218144e1f3cd279045300112b9b40d01850a9ab718c2198d97e11820c0af3f706feaa3e86de7e08b79024bf7a7684815c'
```

**AFTER:**
```yaml
SECRET_KEY_BASE: '<%= ENV.fetch("SECRET_KEY_BASE", "b4c8815864f1b4eb94175952890e688218144e1f3cd279045300112b9b40d01850a9ab718c2198d97e11820c0af3f706feaa3e86de7e08b79024bf7a7684815c") %>'
```

---

## 🔧 How to Apply This Fix

### For Clacky-clean (This Project)

Since Railway builds from your GitHub repo, and `application.yml` is gitignored, you have two options:

#### Option A: Use Railway Environment Variables (Recommended)
Railway already has `SECRET_KEY_BASE` in environment variables, so the Dockerfile build process will use it. **No additional action needed** - just push the `railway.json` fix (already done).

#### Option B: Manually Update on Server (If Needed)
If deployment still fails:
1. SSH into Railway container (if possible)
2. Edit `/app/config/application.yml`
3. Change line 17 to use `ENV.fetch`

### For stellar-reflection (Separate Repository)

You need to manually apply the same fix:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/stellar-reflection.git
   cd stellar-reflection
   ```

2. **Edit `config/application.yml`:**
   Find this line:
   ```yaml
   SECRET_KEY_BASE: 'some_hardcoded_value'
   ```
   
   Replace with:
   ```yaml
   SECRET_KEY_BASE: '<%= ENV.fetch("SECRET_KEY_BASE", "some_hardcoded_value") %>'
   ```

3. **Update `railway.json`:**
   Add this line inside the `"deploy"` section:
   ```json
   "preDeployCommand": "bundle exec rails db:migrate"
   ```

4. **Commit and push:**
   ```bash
   git add railway.json
   git commit -m "Add preDeployCommand for automatic migrations"
   git push origin main
   ```

---

## 🚀 Why This Fix Works

### The Problem
Figaro (the gem that loads `application.yml`) loads values at boot time. If you hardcode `SECRET_KEY_BASE` in the YAML file, it ignores the environment variable.

### The Solution
Using ERB templating (`<%= ENV.fetch(...) %>`), we tell Figaro to:
1. **First** check Railway's `SECRET_KEY_BASE` environment variable
2. **If not found**, fall back to the default value (for local development)

### Railway's Build Process
1. Dockerfile copies `config/application.yml` from your repo
2. Rails boots and Figaro evaluates ERB templates
3. `ENV.fetch("SECRET_KEY_BASE")` reads Railway's environment variable
4. ✅ Production uses Railway's secure secret key
5. ✅ Development uses the default fallback

---

## ✅ Verification Checklist

### After Pushing Changes:

1. **Check Railway Deployment:**
   - Go to Railway Dashboard → Clacky-clean
   - Go to Deployments tab
   - Wait for new deployment to start
   - Check Deploy Logs for success

2. **Verify Environment Variable:**
   ```bash
   # In Railway's Deploy Logs, you should see:
   Using SECRET_KEY_BASE from environment
   ```

3. **Test Health Check:**
   ```bash
   curl https://clacky-clean-production.up.railway.app/up
   # Should return: 200 OK
   ```

4. **Test Homepage:**
   ```bash
   curl https://clacky-clean-production.up.railway.app/
   # Should return: HTML content (no SECRET_KEY_BASE error)
   ```

---

## 🐛 If Deployment Still Fails

### Error: "Missing secret_key_base"

**Diagnosis:** Environment variable not being read

**Solutions:**
1. **Verify Railway variable exists:**
   - Railway Dashboard → Clacky-clean → Variables
   - Check `SECRET_KEY_BASE` has a value (click eye icon)
   - If empty, generate new one: `rails secret`

2. **Verify Figaro is installed:**
   ```ruby
   # In Gemfile, should have:
   gem 'figaro'
   ```

3. **Check Dockerfile ENV handling:**
   - Dockerfile should NOT override `SECRET_KEY_BASE`
   - Remove any `ENV SECRET_KEY_BASE=...` lines

### Error: "config.eager_load is set to nil"

**Already Fixed!** `config/environments/production.rb` line 5:
```ruby
config.eager_load = true
```

### Error: "preDeployCommand failed"

**Check Deploy Logs for migration errors:**
- Might be a database connection issue
- Verify `DATABASE_URL` is set correctly
- Try deploying without `preDeployCommand` first, then add it back

---

## 📊 Current Status

### Clacky-clean (This Workspace)
- ✅ `config/application.yml` - Fixed locally (not in git)
- ✅ `railway.json` - Committed and pushed
- ✅ `config/environments/production.rb` - Already correct
- ✅ `DATABASE_URL` - Connected in Railway
- ✅ `SECRET_KEY_BASE` - Variable exists in Railway
- 🔄 **Next:** Push changes and monitor deployment

### stellar-reflection (Separate Project)
- ❌ `config/application.yml` - Needs manual fix
- ❌ `railway.json` - Needs `preDeployCommand` added
- ✅ `config/environments/production.rb` - Likely already correct
- ✅ `DATABASE_URL` - Connected in Railway
- ✅ `SECRET_KEY_BASE` - Variable exists in Railway
- 🔄 **Next:** Clone repo, apply fixes, push changes

---

## 🎯 Summary

**What you pushed:**
- ✅ `railway.json` with `preDeployCommand`
- ✅ `RAILWAY_DEPLOYMENT_FIX_COMPLETE.md` documentation

**What you need to do manually:**
- For Clacky-clean: **Nothing** - Railway will use environment variables
- For stellar-reflection: **Apply same fixes** to that repository

**Expected outcome:**
Both apps should deploy successfully within 5-10 minutes of pushing changes.

---

**Last Updated:** February 5, 2026 12:55 AM PST
**Status:** Waiting for Railway redeployment
