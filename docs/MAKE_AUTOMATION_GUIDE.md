# Make.com Automation Setup Guide

This guide covers migrating from Zapier to Make.com and setting up all automations one-for-one.

## Overview

Your app now uses **Make.com** for all automation needs. The following automations can be configured:

---

## Your Primary Webhook (Already continue 
Active)

```
Webhook URL: https://hook.us2.make.com/r43411atxiyelti8m69dorrcwwlwmc8g
Trigger: POST from your app when posts are created/scheduled
Purpose: Main posting automation → Buffer → Social Media Platforms
```

---

## 1. New Content Created → Slack Notification

**Replaces Zapier:** Webhook → Slack

**Make.com Setup:**
```
1. Create NEW scenario in Make.com
2. Add: Webhooks → Custom Webhook
   - Name: "Content Created"
   - Click "Copy" to get your webhook URL
3. Add: Router (for branching to multiple destinations)
4. Add: Slack → Send Message
   - Connect your Slack workspace
   - Channel: #social-media-updates (or your preferred channel)
   - Message text:
     ```
     🆕 New Content Created!
     
     Title: {{text}}
     Platform: {{platform}}
     Scheduled: {{schedule_time}}
     ```
```

**Your App Payload:**
```json
{
  "user_id": 1,
  "content_id": 123,
  "text": "Your post caption here",
  "platform": "twitter",
  "schedule_time": "2026-02-01T10:00:00Z"
}
```

---

## 2. Post Published → Google Sheets Export

**Replaces Zapier:** Webhook → Google Sheets

**Make.com Setup:**
```
1. Create NEW scenario in Make.com
2. Add: Webhooks → Custom Webhook
   - Name: "Post Published"
   - Copy webhook URL
3. Add: Google Sheets → Add a Row
   - Connect Google account
   - Spreadsheet: Social Media Analytics
   - Worksheet: Published Posts
   - Map columns:
     • A (Post ID): {{post_id}}
     • B (Platform): {{platform}}
     • C (Text): {{text}}
     • D (Scheduled At): {{schedule_time}}
     • E (Created At): {{created_at}}
     • F (Status): {{status}}
```

---

## 3. High Engagement Alert → Email

**Replaces Zapier:** Webhook → Email by Zapier

**Make.com Setup:**
```
1. Create NEW scenario in Make.com
2. Add: Webhooks → Custom Webhook
   - Name: "High Engagement"
   - Copy webhook URL
3. Add: Router
4. Branch 1: Filter (engagement_count > 100)
5. Add: Email → Send Email
   - To: your-email@example.com
   - Subject: 🚀 High Engagement Alert: {{post_id}}
   - Body:
     ```
     Your post is performing great!
     
     Post ID: {{post_id}}
     Platform: {{platform}}
     Engagement Count: {{engagement_count}}
     
     View details in your dashboard.
     ```
```

---

## 4. Scheduled Post → Google Calendar

**Replaces Zapier:** Webhook → Google Calendar

**Make.com Setup:**
```
1. Create NEW scenario in Make.com
2. Add: Webhooks → Custom Webhook
   - Name: "Scheduled Post"
   - Copy webhook URL
3. Add: Google Calendar → Create a Quick Event
   - Connect Google account
   - Calendar: Content Calendar
   - Title: {{platform}}: {{text | truncate(50)}}
   - Description: {{text}}
   - Start time: {{schedule_time}}
   - End time: {{schedule_time}} + 30 minutes
```

---

## 5. Weekly Summary Report → Email

**Replaces Zapier:** Schedule → Email by Zapier

**Make.com Setup:**
```
1. Create NEW scenario in Make.com (NOT webhook-based)
2. Add: Schedule → Schedule
   - Run: Weekly (e.g., every Monday at 9:00 AM)
3. Add: HTTP → Make a request
   - Method: GET
   - URL: https://your-app.com/api/v1/analytics/weekly
   - Headers: (add authorization if needed)
4. Add: Email → Send Email
   - To: your-email@example.com
   - Subject: 📊 Weekly Performance Summary
   - Body:
     ```
     Here's your weekly performance summary:
     
     Total Posts: {{total_posts}}
     Total Engagements: {{total_engagements}}
     Top Platform: {{top_platform}}
     
     View full report in your dashboard.
     ```
```

---

## 6. Daily Digest → Slack

**Replaces Zapier:** Schedule → Slack

**Make.com Setup:**
```
1. Create NEW scenario in Make.com
2. Add: Schedule → Schedule
   - Run: Daily (e.g., every day at 8:00 AM)
3. Add: HTTP → Make a request
   - Method: GET
   - URL: https://your-app.com/api/v1/dashboard/metrics
4. Add: Slack → Send Message
   - Channel: #daily-digest
   - Message:
     ```
     📅 Daily Social Media Digest
     
     Yesterday's posts: {{posts_yesterday}}
     Today's scheduled: {{posts_scheduled}}
     Pending approvals: {{pending_approvals}}
     ```
```

---

## 7. AI Content Analysis (Optional)

**Replaces Zapier:** Webhook → OpenAI

**Make.com Setup:**
```
1. Create NEW scenario in Make.com
2. Add: Webhooks → Custom Webhook
   - Name: "AI Content Analysis"
   - Copy webhook URL
3. Add: OpenAI → ChatGPT (or use Google Gemini)
   - Connection: Your OpenAI API key
   - Model: gpt-4
   - System message: "You are a social media expert..."
   - User message: "Analyze this post: {{text}}"
4. Add: HTTP → Make a request (POST back to app)
   - Method: POST
   - URL: https://your-app.com/api/v1/content/analyze
   - Body:
     ```
     {
       "content_id": {{content_id}},
       "analysis": "{{analysis_result}}",
       "sentiment": "{{sentiment}}",
       "suggestions": "{{suggestions}}"
     }
     ```
```

---

## 8. Competitor Alerts (Optional)

**Replaces Zapier:** Custom trigger → Notification

**Make.com Setup:**
```
1. Create NEW scenario in Make.com
2. Add: Webhooks → Custom Webhook
   - Name: "Competitor Detected"
   - Copy webhook URL
3. Add: Router
4. Branch 1: Email → Send Email
5. Branch 2: Slack → Send Message
   - Channel: #competitor-watching
   - Message: ⚠️ Competitor content detected: {{competitor_name}}
```

---

## Summary: Your Make.com Webhooks

| Automation | Make.com Webhook URL | Trigger Type |
|------------|---------------------|--------------|
| **Main Post Webhook** | `https://hook.us2.make.com/r43411atxiyelti8m69dorrcwwlwmc8g` | Webhook |
| Content Created | `https://hook.us2.make.com/XXXXXXX` (create new) | Webhook |
| Post Published | `https://hook.us2.make.com/XXXXXXX` (create new) | Webhook |
| High Engagement | `https://hook.us2.make.com/XXXXXXX` (create new) | Webhook |
| Scheduled Post | `https://hook.us2.make.com/XXXXXXX` (create new) | Webhook |
| Weekly Summary | N/A (use Schedule trigger) | Schedule |
| Daily Digest | N/A (use Schedule trigger) | Schedule |
| AI Analysis | `https://hook.us2.make.com/XXXXXXX` (create new) | Webhook |

---

## How to Create a New Webhook in Make.com

```
1. Log in to https://make.com
2. Click "Create a new scenario"
3. Click "+" to add first module
4. Search "Webhooks" → select "Custom Webhook"
5. Click "Add" to create new webhook
6. Give it a name (e.g., "Content Created")
7. Copy the webhook URL
8. Click "Save"
9. Click "Run once" to start listening
10. Add your action modules (Slack, Sheets, Email, etc.)
11. Toggle the scenario ON to activate
```

---

## App Configuration

Once you create each Make.com webhook, you'll need to update your app to send events to the correct URLs. Currently, the app sends:

| Event | Endpoint | Status |
|-------|----------|--------|
| Post created/scheduled | Main webhook | ✅ Configured |
| Content created | `/api/v1/zapier/webhooks/content_created` | ❌ Removed (migrate to Make) |
| Post published | `/api/v1/zapier/webhooks/post_published` | ❌ Removed (migrate to Make) |
| Engagement received | `/api/v1/zapier/webhooks/engagement_received` | ❌ Removed (migrate to Make) |

**Note:** The Zapier webhook endpoints have been removed. To send to Make.com, update your app's webhook configuration or create a new webhook service that points to your Make.com URLs.

---

## Troubleshooting

### Scenario not receiving webhooks?
- Make sure the scenario is ON (toggle at bottom left)
- Click "Run once" to start listening
- Check the webhook URL is copied correctly

### Data not appearing in Google Sheets?
- Verify Google account is connected
- Check column mapping matches your spreadsheet
- Ensure the worksheet name is exact

### Email not sending?
- Check SMTP settings in your email provider
- Verify recipient email address
- Check spam folder

---

## Support Resources

- **Make.com Help Center**: https://www.make.com/en/help
- **Make.com Community**: https://community.make.com/
