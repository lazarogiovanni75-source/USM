# OpenAI Connection Status & Guide

## ⚠️ SECURITY ALERT: API KEY EXPOSED

**CRITICAL:** Your OpenAI API key is currently hardcoded in `config/application.yml` and may be exposed in your repository!

**Immediate Action Required:**
1. Revoke the exposed API key at https://platform.openai.com/api-keys
2. Generate a new API key
3. Add it to Railway environment variables only (never commit to code)

---

## ✅ Current Status: CONFIGURED (BUT EXPOSED)

OpenAI is **configured** for ChatGPT-4o-mini, but the API key needs to be secured.

**Current Model:** `gpt-4o-mini` (Cost-effective, fast responses)  
**Configuration:** Rails App + Railway Backend  
**Default API Key:** Exposed in config (NEEDS REPLACEMENT)

---

## What is OpenAI Used For?

Your app uses **OpenAI ChatGPT-4o-mini** for:

### 1. AI Content Generation
- Generate social media posts
- Create captions and descriptions
- Content optimization
- Creative suggestions

### 2. AI Chat Assistant
- Interactive AI conversations
- Social media strategy advice
- Content recommendations
- User assistance

### 3. Voice Command Processing
- Parse voice commands
- Generate responses
- Smart automation

---

## Current Configuration

### Rails App (`config/application.yml`)
```yaml
# OpenAI API for AI Autopilot content generation
OPENAI_API_KEY: '<%= ENV.fetch("CLACKY_OPENAI_API_KEY", "sk-proj-...") %>'
OPENAI_MODEL: '<%= ENV.fetch("CLACKY_OPENAI_MODEL", "gpt-4o-mini") %>'
OPENAI_ORG_ID: '<%= ENV.fetch("CLACKY_OPENAI_ORG_ID", "") %>'
```

**Environment Variables:**
- `CLACKY_OPENAI_API_KEY` - Your OpenAI API key
- `CLACKY_OPENAI_MODEL` - Model to use (default: gpt-4o-mini)
- `CLACKY_OPENAI_ORG_ID` - Optional organization ID

### Railway Backend (`railway-backend/server.js`)
```javascript
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

// Uses OpenAI for:
// - POST /api/ai/generate-content (content generation)
// - POST /api/chat (AI chat responses)
```

**Environment Variable:**
- `OPENAI_API_KEY` - OpenAI API key for backend

---

## How OpenAI is Used in Your App

### 1. Backend API (railway-backend)

#### Content Generation Endpoint
**Endpoint:** `POST https://api.ultimatesocialmedia01.com/api/ai/generate-content`

**Request:**
```json
{
  "prompt": "Create an engaging Instagram post about morning coffee",
  "userId": "123",
  "userName": "John Doe",
  "userEmail": "john@example.com"
}
```

**Response:**
```json
{
  "success": true,
  "content": "☕ Good morning, coffee lovers! Start your day right...",
  "draftId": "456",
  "status": "pending",
  "userId": "123"
}
```

**Features:**
- Uses `gpt-3.5-turbo` model (note: backend uses 3.5, not 4o-mini)
- 500 token limit
- Saves draft to database automatically
- 30-second timeout

#### Chat Endpoint
**Endpoint:** `POST https://api.ultimatesocialmedia01.com/api/chat`

**Request:**
```json
{
  "message": "How can I improve my Instagram engagement?",
  "userId": "default-user"
}
```

**Response:**
```json
{
  "success": true,
  "response": "To improve Instagram engagement, focus on...",
  "userId": "default-user"
}
```

**Features:**
- Uses `gpt-3.5-turbo` model
- 300 token limit
- Helpful AI assistant persona

### 2. Rails Services

#### AiAutopilotService
**File:** `app/services/ai_autopilot_service.rb`

**Usage:**
```ruby
# Process voice commands
service = AiAutopilotService.new(command: voice_command)
result = service.call

# Generate content
service = AiAutopilotService.new(
  action: 'generate_content',
  campaign: campaign,
  content_type: 'post',
  platform: 'instagram'
)
content = service.call
```

**Note:** Currently uses placeholder logic, could be enhanced with direct OpenAI calls

---

## Securing Your OpenAI API Key

### Step 1: Revoke Exposed Key
1. Go to https://platform.openai.com/api-keys
2. Find the exposed key (starts with `sk-proj-k94aSF70...`)
3. Click "Revoke" to invalidate it
4. Confirm revocation

### Step 2: Generate New API Key
1. Click "Create new secret key"
2. Name it: "UltimateSocialMedia-Production"
3. Copy the key immediately (shown only once!)
4. Save it securely (password manager recommended)

### Step 3: Add to Railway (Rails App)
1. Go to Railway dashboard
2. Select **Main-Rails-App** service
3. Variables tab
4. Add/Update:
   - **Name:** `CLACKY_OPENAI_API_KEY`
   - **Value:** `sk-proj-your-new-key-here`

### Step 4: Add to Railway (Backend API)
1. Select **Railway Backend** service
2. Variables tab
3. Add/Update:
   - **Name:** `OPENAI_API_KEY`
   - **Value:** `sk-proj-your-new-key-here`

### Step 5: Remove from Code (Important!)
Remove the hardcoded default from `config/application.yml`:

**Change this:**
```yaml
OPENAI_API_KEY: '<%= ENV.fetch("CLACKY_OPENAI_API_KEY", "sk-proj-k94aSF70...") %>'
```

**To this:**
```yaml
OPENAI_API_KEY: '<%= ENV.fetch("CLACKY_OPENAI_API_KEY", "") %>'
```

This ensures the key comes from environment variables only.

---

## Testing OpenAI Connection

### Method 1: Backend Health Check
```bash
curl https://api.ultimatesocialmedia01.com/ready
```

**Look for:**
```json
{
  "checks": {
    "openai": "configured"  ← Should show this
  }
}
```

### Method 2: Test Content Generation
```bash
curl -X POST https://api.ultimatesocialmedia01.com/api/ai/generate-content \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Write a test social media post about productivity",
    "userId": "test-123"
  }'
```

### Method 3: Test Chat Endpoint
```bash
curl -X POST https://api.ultimatesocialmedia01.com/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Hello, how can you help me?",
    "userId": "test-user"
  }'
```

### Method 4: Rails Console
```ruby
rails console

# Check if API key is loaded
ENV['OPENAI_API_KEY']  # Should show your key

# Test via backend API (using Rails HTTParty or similar)
# Or implement direct OpenAI gem integration
```

---

## OpenAI Model Configuration

### Current Model: gpt-4o-mini

**Benefits:**
- ✅ Cost-effective ($0.15 per 1M input tokens)
- ✅ Fast response times
- ✅ Good quality for social media content
- ✅ Suitable for high-volume applications

**Alternatives:**

1. **gpt-3.5-turbo** (Currently used by backend)
   - Even cheaper ($0.50 per 1M input tokens)
   - Faster than 4o-mini
   - Good for simple tasks

2. **gpt-4o**
   - Higher quality responses
   - Better at complex tasks
   - More expensive ($5 per 1M input tokens)
   - Slower

3. **gpt-4-turbo**
   - Best quality
   - Latest knowledge cutoff
   - Most expensive ($10 per 1M input tokens)

### Changing the Model

**In Railway (Rails App):**
- Variable: `CLACKY_OPENAI_MODEL`
- Value: `gpt-4o-mini` (or other model name)

**In Backend Code:**
Edit `railway-backend/server.js` lines 90 and 171:
```javascript
model: 'gpt-4o-mini',  // Change this
```

---

## Usage Monitoring & Costs

### Check Your Usage
1. Go to https://platform.openai.com/usage
2. View daily/monthly API usage
3. Monitor costs per model
4. Set spending limits

### Typical Costs (gpt-4o-mini)
- **Content Generation:** ~500 tokens = $0.00008 per post
- **Chat Response:** ~300 tokens = $0.000045 per message
- **Monthly estimate:** 10,000 posts = $0.80

### Rate Limits
- **Free Tier:** 3 requests/minute, 200 requests/day
- **Tier 1:** ($5+ spent) 60 requests/minute
- **Tier 2:** ($50+ spent) 3,500 requests/minute

Your backend handles rate limiting with specific error messages.

---

## Error Handling

### Common Errors

**1. "OpenAI API key not configured"**
- **Cause:** Missing or empty OPENAI_API_KEY
- **Solution:** Add API key to Railway variables

**2. "OpenAI rate limit exceeded" (429)**
- **Cause:** Too many requests
- **Solution:** Wait a moment, or upgrade OpenAI tier

**3. "OpenAI request timeout" (504)**
- **Cause:** API took >30 seconds
- **Solution:** Retry request, check OpenAI status

**4. "Invalid API key" (401)**
- **Cause:** Wrong or revoked API key
- **Solution:** Generate new key, update Railway

**5. "Insufficient credits" (429)**
- **Cause:** OpenAI account out of credits
- **Solution:** Add payment method at https://platform.openai.com/account/billing

---

## Integration Points

### Controllers Using OpenAI:
1. **ContentCreationController** - AI content generation
2. **AiChatController** - Chat interface
3. **VoiceCommandsController** - Voice processing

### Services:
1. **AiAutopilotService** - Main AI automation service
2. **Backend API** - External AI processing
3. **ConversationMemoryService** - Chat history (could use OpenAI)

### Frontend:
- `app/javascript/services/aiService.js` - AI API client
- Calls backend endpoints for OpenAI features

---

## Best Practices

### 1. Security
- ✅ Never commit API keys to code
- ✅ Use environment variables only
- ✅ Rotate keys regularly (every 90 days)
- ✅ Monitor for unusual usage

### 2. Cost Management
- ✅ Use gpt-4o-mini for most tasks
- ✅ Set max_tokens limits
- ✅ Implement caching for repeated queries
- ✅ Monitor usage dashboard

### 3. Performance
- ✅ Set reasonable timeouts (30s)
- ✅ Handle rate limits gracefully
- ✅ Cache AI-generated content
- ✅ Use streaming for long responses (optional)

### 4. Quality
- ✅ Write clear system prompts
- ✅ Test prompts thoroughly
- ✅ Provide user feedback mechanism
- ✅ Log failed generations

---

## Troubleshooting

### OpenAI API Not Responding
1. Check https://status.openai.com
2. Verify API key is valid
3. Check Railway logs for errors
4. Test with curl commands

### Poor Content Quality
1. Improve system prompts
2. Increase max_tokens
3. Upgrade to better model (gpt-4o)
4. Provide more context in prompts

### Rate Limiting Issues
1. Check current tier at OpenAI
2. Implement request queuing
3. Add exponential backoff
4. Upgrade OpenAI tier if needed

---

## Model Update: Backend vs Config Mismatch

**Issue:** Your backend uses `gpt-3.5-turbo` but config specifies `gpt-4o-mini`

**To Fix (Optional):**

Update `railway-backend/server.js`:
```javascript
// Line 90 and 171
model: 'gpt-4o-mini',  // Changed from gpt-3.5-turbo
```

Or keep 3.5-turbo for cost savings (it's cheaper!).

---

## Summary

**Status:** ⚠️ **CONFIGURED BUT API KEY EXPOSED**

**Immediate Actions:**
1. 🔴 **URGENT:** Revoke exposed API key
2. 🔴 **URGENT:** Generate new API key
3. 🔴 **URGENT:** Add to Railway variables
4. 🟡 Remove hardcoded key from config

**Once Secured:**
- ✅ OpenAI fully functional
- ✅ Content generation ready
- ✅ AI chat operational
- ✅ Voice commands supported

**OpenAI is ready - just needs secure API key setup! 🚀**

---

**Resources:**
- OpenAI Platform: https://platform.openai.com
- API Keys: https://platform.openai.com/api-keys
- Usage Dashboard: https://platform.openai.com/usage
- API Docs: https://platform.openai.com/docs
- Status Page: https://status.openai.com

**Last Updated:** February 3, 2026
