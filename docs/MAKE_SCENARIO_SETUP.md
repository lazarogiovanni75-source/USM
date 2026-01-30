# Make Scenario Setup Guide for Buffer Integration

## Overview

This guide walks you through creating a Make scenario that receives webhooks from your app and posts content to Buffer for social media scheduling.

## Your Webhook URL

```
https://hook.us2.make.com/r43411atxiyelti8m69dorrcwwlwmc8g
```

**Important**: Copy this URL exactly. You'll need to paste it into Make.

## What Your App Sends

When a user creates a scheduled post, your app sends this JSON payload:

```json
{
  "user_id": 1,
  "text": "Your post caption here",
  "image_url": "https://example.com/image.jpg",
  "platform": "twitter",
  "schedule_time": "2026-01-31T10:00:00Z"
}
```

## Step-by-Step Make Scenario Setup

### Step 1: Create New Scenario

1. **Log in to Make** at https://make.com
2. Click **"Create a new scenario"** (blue button, top right)
3. Click the **"+"** button to add your first module
4. Search for **"Webhooks"** and select it
5. Choose **"Custom Webhook"** as the trigger
6. Click **"Add"** to create a new webhook

### Step 2: Configure Webhook

1. In the webhook configuration panel, you'll see a field for the webhook URL
2. **Paste your webhook URL**:
   ```
   https://hook.us2.make.com/r43411atxiyelti8m69dorrcwwlwmc8g
   ```
3. Click **"Copy"** button next to the URL to copy it
4. Click **"Save"** to store the webhook

### Step 3: Test the Webhook Connection

1. Click **"Run once"** button (bottom left, gray button with play icon)
2. The scenario will start listening for webhook data
3. Now create a test post in your app to trigger the webhook
4. You should see data appear in Make showing the webhook payload

**Alternative for testing without your app:**
- Click the webhook in Make to expand details
- Look for **"Add"** or **"Send test data"** button
- Use the sample payload above to test

### Step 4: Add Buffer Module

1. Click the **"+"** button to add another module after the webhook
2. Search for **"Buffer"** and select it
3. Choose the action **"Create a New Update"** (this posts content to Buffer)

### Step 5: Connect Your Buffer Account

1. Click **"Add"** or **"Create a Connection"** in the Buffer module
2. Enter your Buffer credentials:
   - **Access Token**: Get from https://buffer.com/developers/apps (create an app or use your account)
   - **Profile ID**: The social media profile ID you want to post to
3. Click **"Save"** to authorize Make to access your Buffer account

### Step 6: Map Webhook Data to Buffer Fields

Configure the Buffer module with the data from your webhook:

| Buffer Field | Webhook Data (map to) |
|--------------|----------------------|
| **Profile ID** | Select from dropdown (will load your Buffer profiles) |
| **Text** | `{{text}}` from webhook payload |
| **Media/Photo** | `{{image_url}}` from webhook payload |
| **Scheduled At** | `{{schedule_time}}` from webhook payload (if you want to schedule) |
| **Now** | Check this if you want to post immediately instead of scheduling |

### Step 7: Handle Different Platforms

Since your app sends different platforms (twitter, facebook, instagram, etc.), you need to route to the correct Buffer profile:

1. Add a **"Router"** module after the webhook
2. Create filters for each platform:
   - **Filter 1**: `{{platform}}` = "twitter" → Buffer profile for Twitter
   - **Filter 2**: `{{platform}}` = "facebook" → Buffer profile for Facebook
   - **Filter 3**: `{{platform}}` = "instagram" → Buffer profile for Instagram
   - **Filter 4**: `{{platform}}` = "linkedin" → Buffer profile for LinkedIn

### Step 8: Activate the Scenario

1. Click **"ON"** switch in the bottom left corner
2. The scenario will now:
   - Listen for webhooks from your app
   - Receive post data when users create scheduled posts
   - Forward content to Buffer for publishing

## Complete Scenario Structure

```
┌─────────────────────────────────┐
│  Webhook (Custom Webhook)       │
│  URL: https://hook.us2...       │
└───────────────┬─────────────────┘
                │
                ▼
┌─────────────────────────────────┐
│  Router (Platform Filter)       │
│  ├─ Twitter → Buffer Profile    │
│  ├─ Facebook → Buffer Profile   │
│  ├─ Instagram → Buffer Profile  │
│  └─ LinkedIn → Buffer Profile   │
└─────────────────────────────────┘
```

## Testing Your Setup

### Test with Make's Built-in Tools

1. In Make, click on your webhook module to expand it
2. Look for **"Add"** or **"Test webhook"** 
3. Send this test data:

```json
{
  "user_id": 1,
  "text": "Test post from Make integration!",
  "image_url": "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=800",
  "platform": "twitter",
  "schedule_time": null
}
```

4. Check that the data flows through to Buffer

### Verify in Your App

1. Create a new scheduled post in your app
2. Check the post's webhook status in the database:
   - `webhook_status` should be "success"
   - `webhook_attempts` should be 1
3. Check GoodJob queue for webhook jobs

## Troubleshooting

### "Scenario run" Not Working

**Problem**: You see "scenario run" but don't know what to do

**Solution**: 
- Click "scenario run" button (play icon) to start the scenario
- The scenario must be actively running to receive webhooks
- Toggle it ON to keep it listening

### Webhook Not Receiving Data

**Problem**: Make doesn't receive webhook data from your app

**Solutions**:
1. Verify webhook URL is correct in `config/application.yml`
2. Restart your Rails server after URL changes
3. Check server logs for webhook job execution
4. Verify the post is being created in your app

### Buffer Connection Failed

**Problem**: Buffer module shows connection error

**Solutions**:
1. Get a fresh Access Token from https://buffer.com/developers/apps
2. Ensure the Buffer profile ID is correct
3. Check that the profile is active in Buffer

### Posts Not Appearing in Buffer

**Problem**: Webhook received but Buffer doesn't show posts

**Solutions**:
1. Check Make execution history for errors
2. Verify the text field mapping is correct
3. Ensure the profile ID exists and is accessible
4. Check Buffer dashboard directly for posted content

## Buffer API Reference

If you need to customize the Buffer integration:

- **Buffer API Docs**: https://buffer.com/developers/api
- **Create Update Endpoint**: `POST /updates/create`
- **Required Fields**: `profile_ids[]`, `text`
- **Optional Fields**: `media[photo]`, `scheduled_at`, `now`

## Security Notes

- Your webhook URL is unique to your Make account
- Don't share it publicly
- If compromised, create a new webhook in Make and update `config/application.yml`
