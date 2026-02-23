# 🔧 Fix GoDaddy DNS to Point to Clacky (Not Railway)

## ⚠️ PROBLEM IDENTIFIED

Your domain `www.ultimatesocialmedia01.com` is currently pointing to **Railway**, but your application is actually deployed on **Clacky**.

**Current App URL (Clacky):** `https://3000-ec0aeaf8246a-web.clackypaas.com`  
**Your Domain:** `www.ultimatesocialmedia01.com`  
**Status:** DNS pointing to wrong platform ❌

---

## 🎯 SOLUTION: Update GoDaddy DNS Records

### Step 1: Login to GoDaddy

1. Go to https://www.godaddy.com/
2. Sign in to your account
3. Navigate to **My Products** → **Domains**
4. Find `ultimatesocialmedia01.com`
5. Click **DNS** button (or **Manage DNS**)

---

### Step 2: Update WWW Subdomain

**Find the CNAME record for `www`:**

```
BEFORE (Wrong):
Type: CNAME
Name: www
Value: [Some Railway URL like *.railway.app]
TTL: 600
```

**Change to (Correct):**

```
Type: CNAME
Name: www
Value: 3000-ec0aeaf8246a-web.clackypaas.com
TTL: 600
```

**How to do it:**
1. Find the row with Name = `www`
2. Click the **Edit** icon (pencil)
3. Change **Points to** field to: `3000-ec0aeaf8246a-web.clackypaas.com`
4. Keep TTL as `600` or `1 Hour`
5. Click **Save**

---

### Step 3: Update Root Domain (@ record)

**Find the root domain record (@):**

```
BEFORE (Wrong):
Type: A or CNAME
Name: @
Value: [Railway IP or URL]
```

**Change to (Correct):**

```
Type: CNAME
Name: @
Value: 3000-ec0aeaf8246a-web.clackypaas.com
TTL: 600
```

**How to do it:**
1. Find the row with Name = `@` (root domain)
2. If it's an **A record**, delete it and create a new CNAME
3. Click **Add** → Select **CNAME**
4. Name: `@`
5. Value: `3000-ec0aeaf8246a-web.clackypaas.com`
6. TTL: `600`
7. Click **Save**

⚠️ **Note:** Some DNS providers don't allow CNAME for root (@). If GoDaddy rejects this, use the following alternative:

**Alternative for Root Domain:**
```
Type: CNAME
Name: @ or leave blank
Value: www.ultimatesocialmedia01.com
```
This makes the root redirect to www, which already points to Clacky.

---

### Step 4: Remove Any Railway-Related Records

**Check for these and DELETE them:**
- Any CNAME pointing to `*.railway.app`
- Any A records with Railway IPs
- Any subdomain records (api, backend) pointing to Railway

**Keep only:**
- CNAME for `www` → `3000-ec0aeaf8246a-web.clackypaas.com`
- CNAME for `@` → `3000-ec0aeaf8246a-web.clackypaas.com` (or www redirect)

---

## ⏱️ Wait for DNS Propagation

**Timeline:**
- Local cache: Immediate
- ISP DNS: 5-15 minutes
- Global propagation: Up to 24-48 hours (rarely needed)
- **Typical wait time: 10-30 minutes**

**Check DNS Status:**

```bash
# On Mac/Linux terminal
nslookup www.ultimatesocialmedia01.com

# Should return something like:
# www.ultimatesocialmedia01.com canonical name = 3000-ec0aeaf8246a-web.clackypaas.com
```

**Online DNS Checker:**
- https://www.whatsmydns.net/
- Enter: `www.ultimatesocialmedia01.com`
- Type: `CNAME`
- Click **Search**
- Look for: `3000-ec0aeaf8246a-web.clackypaas.com`

---

## ✅ Verification Steps

### 1. Check DNS Resolution

```bash
nslookup www.ultimatesocialmedia01.com
```

**Expected result:**
```
Server:         8.8.8.8
Address:        8.8.8.8#53

Non-authoritative answer:
www.ultimatesocialmedia01.com canonical name = 3000-ec0aeaf8246a-web.clackypaas.com
```

### 2. Test HTTPS Connection

```bash
curl -I https://www.ultimatesocialmedia01.com
```

**Expected result:**
```
HTTP/2 200 
date: Sun, 23 Feb 2026 ...
content-type: text/html; charset=utf-8
...
```

### 3. Visit in Browser

1. Open browser
2. Go to: https://www.ultimatesocialmedia01.com
3. You should see your Ultimate Social Media platform homepage
4. Open Developer Console (F12)
5. Check for errors - should be none related to domain/CORS

---

## 🔧 If Still Not Working After 30 Minutes

### Check 1: Clear Your DNS Cache

**Mac:**
```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

**Windows:**
```bash
ipconfig /flushdns
```

**Linux:**
```bash
sudo systemd-resolve --flush-caches
```

### Check 2: Try Incognito/Private Browsing

Sometimes browser cache holds old DNS records.

### Check 3: Use Different Network

Try mobile data or different WiFi to bypass local DNS cache.

### Check 4: Verify GoDaddy Changes Were Saved

1. Go back to GoDaddy DNS management
2. Verify the records show:
   - `www` CNAME → `3000-ec0aeaf8246a-web.clackypaas.com`
   - `@` CNAME → `3000-ec0aeaf8246a-web.clackypaas.com`

---

## 📋 Final DNS Configuration (After Fix)

Your GoDaddy DNS should look like this:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| CNAME | www | 3000-ec0aeaf8246a-web.clackypaas.com | 600 |
| CNAME | @ | 3000-ec0aeaf8246a-web.clackypaas.com | 600 |

**No Railway URLs should appear anywhere!**

---

## ❓ Why Did This Happen?

You likely deployed to Railway first, configured your domain there, then switched to Clacky but didn't update the DNS records. This is a common migration issue.

**Railway** and **Clacky** are different hosting platforms, so DNS must be updated when switching between them.

---

## 🚀 What Happens After DNS Update

1. **Domain resolution:** `www.ultimatesocialmedia01.com` → resolves to Clacky IP
2. **HTTPS traffic:** Goes to Clacky servers (not Railway)
3. **Your app:** Served from Clacky deployment
4. **Old Railway deployment:** Still exists but no traffic (can be deleted)

---

## 📞 Support

**If DNS issues persist after 1 hour:**
1. Take a screenshot of your GoDaddy DNS settings
2. Run `nslookup www.ultimatesocialmedia01.com` and save output
3. Contact GoDaddy support with:
   - "My domain should point to 3000-ec0aeaf8246a-web.clackypaas.com"
   - "CNAME record not propagating after 1 hour"

**Expected resolution time:** 15-30 minutes in most cases

---

## ✨ Success Indicators

You'll know it's working when:
- ✅ `nslookup` shows `3000-ec0aeaf8246a-web.clackypaas.com`
- ✅ Browser shows your app at `https://www.ultimatesocialmedia01.com`
- ✅ No CORS errors in console
- ✅ All features work as expected

---

**Last Updated:** February 23, 2026  
**Status:** 🟡 Waiting for user to update GoDaddy DNS
