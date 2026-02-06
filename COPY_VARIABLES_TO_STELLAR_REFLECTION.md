in thde# Copy Variables from New_Clacky_clean to stellar-reflection

## Variables to Add to stellar-reflection

Based on the New_Clacky_clean backend variables, add these to **stellar-reflection**:

### Critical Variables (Add These Now)

1. **ALLOWED_ORIGINS**
   ```
   https://www.ultimatesocialmedia01.com,https://ultimatesocialmedia01.com
   ```

2. **APP_NAME**
   ```
   Ultimate Social Media
   ```

3. **DATABASE_URL** ✅ Already added
   ```
   ${{Postgres.DATABASE_URL}}
   ```
   **⚠️ IMPORTANT:** The New_Clacky_clean shows a different DATABASE_URL:
   ```
   postgresql://postgres.BmppamJkGpqkRsQhtaPfqBmtZjxxwQGVH@postgres.railway.internal:5432/railway
   ```
   This is from a DIFFERENT Postgres service (New-Postgres project).
   
   **You need to UPDATE this in stellar-reflection to use the Postgres in Main-Rails-App!**

4. **NODE_ENV**
   ```
   production
   ```

5. **OPENAI_API_KEY**
   ```
   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
   ```

6. **PORT3000**
   ```
   <empty string>
   ```
   (This appears to be empty - you can skip this one)

7. **RAILS_ENV** (shown as hidden *******)
   ```
   production
   ```

8. **RAILWAY_API_URL** (shown as hidden *******)
   ```
   https://backend-api-production-00f5.up.railway.app
   ```

9. **SECRET_KEY_BASE** ✅ Already added
   ```
   6f8864add0e3fe0b76eaf62f4ce0284ed04c243c4620c34c8d1c7b552efeadb7e9a56d15l1eaa1230b9a4c86125e98ef32406df8d2b9e44ba596980b3b52d34Gb
   ```
   **⚠️ NOTE:** This is different from the one we generated! You should use THIS one from New_Clacky_clean.

10. **VERSION**
    ```
    1.0.0
    ```

### Railway System Variables (Auto-Added)

These are automatically added by Railway, but the backend references them:
- `RAILWAY_PUBLIC_DOMAIN` (auto-set)
- `RAILWAY_PRIVATE_DOMAIN` (auto-set)
- `RAILWAY_PROJECT_NAME` (auto-set)
- `RAILWAY_ENVIRONMENT_NAME` (auto-set)
- `RAILWAY_SERVICE_NAME` (auto-set)
- `RAILWAY_PROJECT_ID` (auto-set)
- `RAILWAY_ENVIRONMENT_ID` (auto-set)
- `RAILWAY_SERVICE_ID` (auto-set)

You don't need to manually add these - Railway adds them automatically.

## Critical Fix Required: DATABASE_URL

**IMPORTANT:** The DATABASE_URL in New_Clacky_clean points to a Postgres in the New-Postgres project:
```
postgresql://postgres.BmppamJkGpqkRsQhtaPfqBmtZjxxwQGVH@postgres.railway.internal:5432/railway
```

But stellar-reflection should use the Postgres in **Main-Rails-App** project:
```
${{Postgres.DATABASE_URL}}
```

**Verify in stellar-reflection:**
1. Go to **stellar-reflection** → **Variables**
2. Check DATABASE_URL value
3. It should be: `${{Postgres.DATABASE_URL}}` (service reference)
4. NOT the postgresql:// connection string from New_Clacky_clean

## Step-by-Step: Add Variables to stellar-reflection

### Method 1: Add One by One

1. Go to **Main-Rails-App** project
2. Click **stellar-reflection** service
3. Click **Variables** tab
4. For each variable above, click **"+ New Variable"**
5. Enter name and value
6. Click **Add**

### Method 2: Raw Editor (Faster)

1. Go to **stellar-reflection** → **Variables**
2. Click **"Raw Editor"** button
3. Add these lines (keeping existing DATABASE_URL and SECRET_KEY_BASE):

```
DATABASE_URL=${{Postgres.DATABASE_URL}}
SECRET_KEY_BASE=6f8864add0e3fe0b76eaf62f4ce0284ed04c243c4620c34c8d1c7b552efeadb7e9a56d15l1eaa1230b9a4c86125e98ef32406df8d2b9e44ba596980b3b52d34Gb
ALLOWED_ORIGINS=https://www.ultimatesocialmedia01.com,https://ultimatesocialmedia01.com
APP_NAME=Ultimate Social Media
NODE_ENV=production
OPENAI_API_KEY=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
RAILS_ENV=production
RAILWAY_API_URL=https://backend-api-production-00f5.up.railway.app
VERSION=1.0.0
```

4. Click **Save** or **Update Variables**
5. Railway will automatically redeploy

## After Adding Variables

Once all variables are added:
1. Railway will redeploy stellar-reflection automatically
2. Watch the deployment logs
3. With all variables present, the deployment should succeed
4. Health check should pass

## Then Delete New_Clacky_clean Project

Once stellar-reflection is online and working:
1. All variables are copied ✅
2. Backend is working in Main-Rails-App ✅
3. Go to **New_Clacky_clean** project
4. Settings → Delete Project

## Summary of Critical Changes

**stellar-reflection needs:**
- ✅ DATABASE_URL = `${{Postgres.DATABASE_URL}}` (already added, verify correct)
- ✅ SECRET_KEY_BASE = Use the one from New_Clacky_clean (longer, more secure)
- ➕ ALLOWED_ORIGINS = For CORS configuration
- ➕ APP_NAME = Application name
- ➕ OPENAI_API_KEY = For AI features
- ➕ RAILS_ENV = production
- ➕ NODE_ENV = production
- ➕ RAILWAY_API_URL = Backend URL
- ➕ VERSION = 1.0.0

---

**Next Step:** Add all these variables to stellar-reflection, then redeploy. The health check should finally pass with all configuration in place!
