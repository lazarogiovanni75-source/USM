# Railway Environment Variables Setup

This document lists all required environment variables for Railway deployment.

## Critical Environment Variables

### 1. ANTHROPIC_API_KEY (REQUIRED for AI Content Generation)
- **Purpose**: Authenticates with Anthropic Claude API for content generation
- **How to get**: Visit https://console.anthropic.com/ and create an API key
- **Error if missing**: `401 Unauthorized` when generating content
- **Variable name in Railway**: `ANTHROPIC_API_KEY`

### 2. REDIS_URL (REQUIRED for Background Jobs)
- **Purpose**: Enables Sidekiq background job processing (social media agent, analytics refresh)
- **How to get**: Add Redis plugin in Railway dashboard
- **Error if missing**: Container stops after ~1 minute (silent Sidekiq crash)
- **Variable name in Railway**: `REDIS_URL`

### 3. DATABASE_URL (Auto-configured by Railway)
- **Purpose**: PostgreSQL database connection
- **How to get**: Automatically set when you add PostgreSQL plugin
- **Variable name in Railway**: `DATABASE_URL`

### 4. SECRET_KEY_BASE (Auto-generated recommended)
- **Purpose**: Rails session encryption
- **How to get**: Run `rails secret` or let Railway generate one
- **Variable name in Railway**: `SECRET_KEY_BASE`

### 5. PORT (Auto-configured by Railway)
- **Purpose**: Web server port binding
- **How to get**: Automatically set by Railway
- **Note**: App already configured to use ENV['PORT'] in config/puma.rb

## How to Add Environment Variables in Railway

1. Go to your Railway project dashboard
2. Click on your service
3. Go to "Variables" tab
4. Click "New Variable"
5. Add the variable name and value
6. Deploy the changes

## Verification

After setting environment variables:
1. Railway will auto-deploy
2. Check logs for successful startup (no "Stopping Container" message)
3. Test content generation feature in the app
4. Verify background jobs are running (if REDIS_URL is set)

## Common Issues

### Issue: "Failed to generate content: 401"
**Solution**: Set `ANTHROPIC_API_KEY` in Railway environment variables

### Issue: Container stops after 1 minute
**Solution**: Either set `REDIS_URL` (enables Sidekiq) or ensure Sidekiq initializer skips loading when Redis is absent (already fixed in commit d52e268)

### Issue: "wrong number of arguments"
**Solution**: Already fixed in commit 0a171df - API call corrected to `client.messages.create`

## Model Configuration

Default model: `claude-sonnet-4-7`
To change: Set `ANTHROPIC_MODEL` environment variable in Railway

## API Endpoint

Default: `https://api.anthropic.com`
To change: Set `ANTHROPIC_BASE_URL` environment variable in Railway
