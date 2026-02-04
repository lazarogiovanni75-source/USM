# Postforme API Connection Status & Guide

## ✅ Current Status: CONFIGURED

Postforme is **already configured** in your application with a default API key!

**API Key in config:** `pfm_live_4NJHWqt7cUTpmVkXAqxCRa`

---

## What is Postforme?

**Postforme** is your social media posting and scheduling platform that:
- ✅ Posts content to multiple social media platforms
- ✅ Schedules posts for optimal times
- ✅ Tracks analytics (engagement, clicks, impressions)
- ✅ Manages social profiles
- ✅ Replaces Buffer integration

**Supported Platforms:**
- Instagram
- TikTok
- Twitter/X
- Facebook
- LinkedIn

---

## Current Configuration

### 1. Rails App Configuration
**File:** `config/application.yml`
```yaml
POSTFORME_API_KEY: '<%= ENV.fetch("CLACKY_POSTFORME_API_KEY", "pfm_live_4NJHWqt7cUTpmVkXAqxCRa") %>'
```

**Environment Variable:**
- **Name:** `CLACKY_POSTFORME_API_KEY`
- **Default:** `pfm_live_4NJHWqt7cUTpmVkXAqxCRa` (fallback)

### 2. Service Implementation
**File:** `app/services/postforme_service.rb`

**Features:**
- ✅ Post creation and scheduling
- ✅ Profile management
- ✅ Analytics retrieval
- ✅ Post deletion
- ✅ Share now functionality
- ✅ Error handling with detailed logging

### 3. Analytics Sync Service
**File:** `app/services/postforme_analytics_sync_service.rb`

**Features:**
- ✅ Automatic analytics syncing
- ✅ Bulk sync for all posts
- ✅ Individual post sync
- ✅ Scheduled job integration

### 4. Database Models

**PostformeAnalytic Model:**
```ruby
# Stores analytics for posted content
- postforme_post_id
- scheduled_post_id
- impressions
- clicks
- engagement_rate
- reach
- shares
- comments
- likes
```

**SocialAccount Fields:**
```ruby
# Postforme integration fields
- postforme_api_key (per-account API key)
- postforme_profile_id (linked profile ID)
```

**ScheduledPost Fields:**
```ruby
# Postforme post tracking
- postforme_post_id (ID of post in Postforme)
```

---

## How Postforme is Used in Your App

### 1. Posting Content
**Controller:** `app/controllers/scheduled_posts_controller.rb`

**Flow:**
```
User creates post → ScheduledPost created → PostformeService.create_post() → 
Post sent to social media → postforme_post_id saved
```

### 2. Scheduling Posts
**Service:** `PostformeService#schedule_post`

```ruby
PostformeService.new.schedule_post(
  profile_id: "instagram_12345",
  text: "Check out our new product!",
  scheduled_at: 1.hour.from_now,
  media: ["https://example.com/image.jpg"]
)
```

### 3. Analytics Tracking
**Service:** `PostformeAnalyticsSyncService`

**Automatic sync:**
```ruby
# Sync single post
PostformeAnalyticsSyncService.new.sync_scheduled_post(scheduled_post)

# Sync all posts
PostformeAnalyticsSyncService.new.sync_all_scheduled_posts
```

### 4. Webhooks
**Endpoint:** `POST /postforme_webhooks`
**Controller:** `app/controllers/postforme_webhooks_controller.rb`

Receives notifications when:
- Post is published
- Post fails
- Analytics updated

---

## API Key Configuration

### Option 1: Use Default Key (Current)
The default API key `pfm_live_4NJHWqt7cUTpmVkXAqxCRa` is already configured.

**Status:** ✅ Ready to use

### Option 2: Use Custom API Key
To use your own Postforme API key:

#### On Railway:
1. Go to Railway dashboard
2. Select **Main-Rails-App**
3. Variables tab
4. Add/Update:
   - **Name:** `CLACKY_POSTFORME_API_KEY`
   - **Value:** `your-postforme-api-key`

#### Locally:
```bash
export CLACKY_POSTFORME_API_KEY=your-postforme-api-key
```

### Option 3: Per-Account API Keys
Each social account can have its own Postforme API key:

```ruby
social_account = SocialAccount.find(params[:id])
social_account.update(
  postforme_api_key: "pfm_live_xyz123",
  postforme_profile_id: "instagram_abc456"
)
```

---

## Testing Postforme Connection

### Method 1: Check Configuration
```ruby
rails runner "puts PostformeService.new.configured? ? 'Connected' : 'Not Connected'"
```

### Method 2: Test API Call
```ruby
rails runner "
service = PostformeService.new
profiles = service.profiles
puts profiles.inspect
"
```

### Method 3: Rails Console
```ruby
rails console

# Test service initialization
service = PostformeService.new
service.configured?  # Should return true

# Get profiles
profiles = service.profiles
puts profiles

# Test post creation (replace with real profile_id)
result = service.create_post(
  'your_profile_id',
  'Test post from Rails console',
  { now: true }
)
puts result
```

### Method 4: Check from UI
1. Log in to your app
2. Go to Social Accounts
3. Try connecting a social profile
4. Create a test post
5. Check if it appears in Postforme dashboard

---

## Postforme API Endpoints

### Base URL
```
https://postforme.com/api/v1
```

### Available Methods

**Profiles:**
- `GET /profiles` - List all profiles
- `GET /profiles/:id` - Get profile details

**Posts:**
- `POST /posts` - Create immediate post
- `POST /posts/schedule` - Schedule post
- `GET /posts/:id` - Get post details
- `DELETE /posts/:id` - Delete scheduled post
- `POST /posts/:id/share` - Share post now

**Analytics:**
- `GET /posts/:id/analytics` - Post analytics
- `GET /profiles/:id/analytics` - Profile analytics

**Lists:**
- `GET /profiles/:id/posts/pending` - Pending posts
- `GET /profiles/:id/posts/sent` - Sent posts

---

## Integration Points in Your App

### Controllers Using Postforme:
1. **ScheduledPostsController** - Post creation/scheduling
2. **SocialAccountsController** - Profile management
3. **PostformeWebhooksController** - Webhook handling

### Services:
1. **PostformeService** - Main API client
2. **PostformeAnalyticsSyncService** - Analytics sync
3. **SchedulerService** - May use Postforme for scheduling

### Models:
1. **ScheduledPost** - Stores `postforme_post_id`
2. **SocialAccount** - Stores `postforme_api_key`, `postforme_profile_id`
3. **PostformeAnalytic** - Stores analytics data

---

## Common Operations

### 1. Create Immediate Post
```ruby
service = PostformeService.new
response = service.create_post(
  profile_id,
  "Post content here",
  { now: true }
)
```

### 2. Schedule Post for Later
```ruby
service = PostformeService.new
response = service.schedule_post(
  profile_id,
  "Scheduled content",
  3.hours.from_now,
  { media: ["https://example.com/image.jpg"] }
)
```

### 3. Get Post Analytics
```ruby
service = PostformeService.new
analytics = service.post_analytics(postforme_post_id)

puts "Impressions: #{analytics['impressions']}"
puts "Clicks: #{analytics['clicks']}"
puts "Engagement: #{analytics['engagement_rate']}"
```

### 4. Delete Scheduled Post
```ruby
service = PostformeService.new
service.delete_post(postforme_post_id)
```

### 5. Share Post Immediately
```ruby
service = PostformeService.new
service.share_now(postforme_post_id)
```

---

## Error Handling

The service includes comprehensive error handling:

```ruby
begin
  result = PostformeService.new.create_post(profile_id, text)
rescue PostformeService::PostformeError => e
  case e.message
  when /Invalid API key/
    # Handle invalid API key
  when /Rate limit exceeded/
    # Handle rate limiting
  when /Validation failed/
    # Handle validation errors
  else
    # Handle other errors
  end
end
```

---

## Troubleshooting

### Issue: "API key not configured"
**Solution:**
1. Check `config/application.yml` has `POSTFORME_API_KEY`
2. Verify Railway variable `CLACKY_POSTFORME_API_KEY` is set
3. Restart Rails server

### Issue: "Invalid API key"
**Solution:**
1. Verify API key is correct in Postforme dashboard
2. Check if key has expired
3. Generate new API key if needed

### Issue: "Connection timeout"
**Solution:**
1. Check internet connectivity
2. Verify Postforme service is up: https://status.postforme.com
3. Increase timeout in service (currently 30s)

### Issue: "Profile not found"
**Solution:**
1. Verify `postforme_profile_id` is correct
2. Re-authenticate social account in Postforme
3. Update profile ID in your database

### Issue: Posts not appearing
**Solution:**
1. Check `scheduled_posts` table for `postforme_post_id`
2. Verify post status in Postforme dashboard
3. Check Rails logs for API errors
4. Test webhook endpoint is accessible

---

## Monitoring & Logs

### Check Postforme Activity
**Rails logs:**
```bash
tail -f log/development.log | grep "PostformeService"
```

**Look for:**
- `[PostformeService] POST https://postforme.com/api/v1/posts`
- `[PostformeService] Response: 200 OK`
- `[PostformeAnalyticsSync] Synced analytics for post`

### Database Queries
```ruby
# Check posts sent via Postforme
ScheduledPost.where.not(postforme_post_id: nil).count

# Check analytics data
PostformeAnalytic.count

# Recent posts with analytics
PostformeAnalytic.includes(:scheduled_post).order(created_at: :desc).limit(10)
```

---

## Migration from Buffer

Your app has commented out Buffer integration:
```yaml
# Buffer API for social media posting/scheduling (deprecated - using Postforme)
# BUFFER_ACCESS_TOKEN: '<%= ENV.fetch("CLACKY_BUFFER_ACCESS_TOKEN", "") %>'
```

**Postforme replaces Buffer for:**
- ✅ Social media posting
- ✅ Scheduling
- ✅ Analytics
- ✅ Profile management

---

## Next Steps

### ✅ Already Done:
1. Postforme service implemented
2. Analytics sync configured
3. Database models created
4. Webhook endpoint ready
5. Default API key configured

### 🔧 Optional Enhancements:
1. **Get Your Own API Key**
   - Sign up at https://postforme.com
   - Generate API key
   - Add to Railway variables

2. **Connect Social Profiles**
   - Link Instagram, TikTok, Twitter, etc.
   - Save profile IDs to social_accounts

3. **Test Posting**
   - Create test post via UI
   - Verify it appears on social media
   - Check analytics sync

4. **Set Up Webhooks**
   - Configure webhook URL in Postforme: `https://www.ultimatesocialmedia01.com/postforme_webhooks`
   - Test webhook delivery

5. **Enable Analytics Sync**
   - Set up cron job or background worker
   - Run `PostformeAnalyticsSyncService.new.sync_all_scheduled_posts`

---

## Summary

**Status:** ✅ **FULLY CONFIGURED AND READY**

**API Key:** ✅ Default key configured  
**Service:** ✅ Implemented  
**Analytics:** ✅ Sync service ready  
**Database:** ✅ Models created  
**Webhooks:** ✅ Endpoint ready  

**Postforme is ready to use! Just connect your social media profiles and start posting! 🚀**

---

**Documentation:**
- Postforme API Docs: https://postforme.com/api/docs
- Service Code: `app/services/postforme_service.rb`
- Analytics Sync: `app/services/postforme_analytics_sync_service.rb`

**Last Updated:** February 3, 2026
