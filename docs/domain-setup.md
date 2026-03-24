# Connecting GoDaddy Domain to Railway

This guide will help you connect your GoDaddy domain to your Railway-hosted Ultimate Social Media app.

## Prerequisites

- GoDaddy domain purchased and active
- Railway project deployed
- Access to both GoDaddy and Railway dashboards

## Step 1: Get Your Railway App URL

1. Go to your [Railway Dashboard](https://railway.app/dashboard)
2. Select your Ultimate Social Media project
3. Click on your service (Rails app)
4. Go to **Settings** tab
5. Scroll to **Networking** section
6. Copy your Railway domain (e.g., `your-app-name.up.railway.app`)

## Step 2: Add Custom Domain in Railway

1. In Railway, go to **Settings** → **Networking**
2. Click **+ Add Domain**
3. Enter your GoDaddy domain (e.g., `yourdomain.com`)
4. Railway will show you DNS records to add:
   - **A Record**: Points to Railway's IP
   - **CNAME Record**: For `www` subdomain (optional)

**Example DNS records Railway provides:**
```
Type: A
Name: @
Value: 104.21.x.x (Railway's IP - use the actual IP they provide)

Type: CNAME
Name: www
Value: your-app-name.up.railway.app
```

## Step 3: Configure DNS in GoDaddy

1. Log into [GoDaddy](https://www.godaddy.com/)
2. Go to **My Products** → **Domains**
3. Click **DNS** next to your domain
4. Click **Add** to add new records

### Add A Record (for root domain)

1. Click **Add**
2. Select **Type**: `A`
3. **Name**: `@` (this represents root domain)
4. **Value**: Paste the IP address Railway provided
5. **TTL**: `600 seconds` (or default)
6. Click **Save**

### Add CNAME Record (for www subdomain - optional)

1. Click **Add**
2. Select **Type**: `CNAME`
3. **Name**: `www`
4. **Value**: Paste your Railway domain (e.g., `your-app-name.up.railway.app`)
5. **TTL**: `600 seconds` (or default)
6. Click **Save**

### Remove Conflicting Records

If you see existing A or CNAME records for `@` or `www`, **delete them first** before adding the new ones.

## Step 4: Update Rails Configuration

Update your `config/application.yml` with your custom domain:

```yaml
PUBLIC_HOST: 'yourdomain.com'
```

Then add this to your Railway environment variables:

1. In Railway, go to **Variables** tab
2. Add/Update: `CLACKY_PUBLIC_HOST` = `yourdomain.com`
3. Redeploy if needed

## Step 5: Wait for DNS Propagation

- **Initial propagation**: 5-30 minutes
- **Full propagation**: Up to 48 hours (usually much faster)

### Check DNS Status

You can check if DNS has propagated using these tools:

1. **Command line**:
   ```bash
   # Check A record
   nslookup yourdomain.com
   
   # Check CNAME
   nslookup www.yourdomain.com
   ```

2. **Online tools**:
   - https://www.whatsmydns.net/
   - https://dnschecker.org/

## Step 6: Enable HTTPS (SSL)

Railway automatically provisions SSL certificates once DNS is configured:

1. In Railway, go to **Settings** → **Networking**
2. Your custom domain should show **SSL: Active** once DNS propagates
3. This happens automatically - no action needed

## Step 7: Test Your Domain

Once DNS propagates, test your domain:

1. Visit `http://yourdomain.com` (should redirect to HTTPS)
2. Visit `https://yourdomain.com` (should load your app)
3. Visit `https://www.yourdomain.com` (if you added CNAME)

## Troubleshooting

### Domain shows "Application Error"

- Check Railway deployment logs
- Verify `CLACKY_PUBLIC_HOST` environment variable is set
- Ensure all required environment variables are configured

### SSL Certificate Not Provisioning

- Wait 10-15 minutes after DNS propagates
- Verify A record points to correct Railway IP
- Check Railway dashboard for SSL status

### "This site can't be reached"

- DNS hasn't propagated yet - wait longer
- Verify DNS records are correct in GoDaddy
- Try clearing your browser cache or use incognito mode

### 404 or Routing Errors

- Check `config/environments/production.rb` for `config.hosts`
- Add your domain to allowed hosts if needed

## Common GoDaddy DNS Settings

**Before (default parking):**
```
Type: A,     Name: @,   Value: 160.153.x.x (GoDaddy parking)
Type: CNAME, Name: www, Value: @
```

**After (Railway):**
```
Type: A,     Name: @,   Value: 104.21.x.x (Railway IP)
Type: CNAME, Name: www, Value: your-app.up.railway.app
```

## Additional Configuration

### Force HTTPS Redirect

This is already configured in `config/environments/production.rb`:
```ruby
config.force_ssl = true
```

### Multiple Domains (optional)

To support multiple domains (e.g., yourdomain.com and yourdomain.net):

1. Add each domain in Railway
2. Configure DNS for each in GoDaddy
3. Railway will handle SSL for all

## Questions?

If you encounter issues:
1. Check Railway deployment logs
2. Verify all DNS records in GoDaddy
3. Use DNS checker tools to confirm propagation
4. Wait at least 30 minutes for initial propagation

---

**Quick Reference:**

1. ✅ Get Railway domain and IP
2. ✅ Add custom domain in Railway
3. ✅ Add A and CNAME records in GoDaddy
4. ✅ Update `CLACKY_PUBLIC_HOST` in Railway
5. ⏱️ Wait for DNS propagation (5-30 min)
6. ✅ Test domain with HTTPS
