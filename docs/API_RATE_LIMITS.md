# API Rate Limits Reference

This document outlines the rate limits for all external APIs used by Ultimate Social Media.

---

## 1. Anthropic Claude API

**Rate Limits:**
- **Standard Tier:** 50 requests/minute, 100,000 tokens/minute
- **Pro Tier:** 200 requests/minute, 400,000 tokens/minute
- **Enterprise:** Custom limits

**Implementation:**
- API key: `ANTHROPIC_API_KEY` or `CLAUDE_API_KEY`
- Base URL: `https://api.anthropic.com/v1`
- Streaming endpoint: `https://api.anthropic.com/v1/messages`

**Best Practices:**
- Implement exponential backoff for 429 errors
- Cache repeated queries where applicable
- Use streaming for long responses

---

## 2. Atlas Cloud API (Image/Video Generation)

**Rate Limits:**
- **Standard Tier:** 100 requests/minute
- **Enterprise:** Varies by contract

**Implementation:**
- API Key: `ATLASCLOUD_API_KEY`
- Base URL: Configured in environment

**Image Generation:**
- Endpoint: POST `/v1/images/generate`
- Response: Async job ID (poll for completion)

**Video Generation:**
- Endpoint: POST `/v1/videos/generate`
- Response: Async job ID (poll for completion)
- Webhook: `ATLASCLOUD_WEBHOOK_URL` for completion notifications

**Best Practices:**
- Poll every 10 seconds for video completion
- Maximum poll attempts: 60 (10 minutes)
- Use webhooks when available

---

## 3. Postforme API

**Rate Limits:**
- **Standard Tier:** 100 requests/minute
- **Post Scheduling:** Real-time via webhook
- **Metrics:** 1 request per account per minute (cache aggressively)

**Implementation:**
- API Key: `POSTFORME_API_KEY` or `ULTIMATE_POSTFORME_API_KEY`
- Base URL: `https://api.postforme.io`

**Endpoints Used:**
- `GET /social-accounts` - List connected accounts
- `POST /social-account-feeds/{id}` - Post content
- `GET /social-account-feeds/{id}` - Get feed with metrics
- `GET /social-account-feeds/{id}?expand=metrics` - Include metrics

**Best Practices:**
- Cache account list for 5 minutes
- Cache feed data for 1 minute
- Use webhooks for real-time post status updates

---

## 4. Stripe API

**Rate Limits:**
- **Create Payment Intent:** 100 requests/second
- **Webhook Events:** No limit (outbound from Stripe)
- **API Operations:** 25-100 requests/second depending on endpoint

**Implementation:**
- Secret Key: `STRIPE_SECRET_KEY`
- Webhook Secret: `STRIPE_WEBHOOK_SECRET`
- Publishable Key: `STRIPE_PUBLISHABLE_KEY`

**Webhook Events Handled:**
- `payment_intent.succeeded`
- `payment_intent.payment_failed`
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `invoice.payment_failed`
- `invoice.payment_succeeded`

**Best Practices:**
- Always verify webhook signatures
- Idempotency keys for payment operations
- Handle duplicate events gracefully

---

## 5. Railway Database

**PostgreSQL:**
- Default connection limit: 100 concurrent connections
- No query rate limit
- **Backups:** Configured via Railway dashboard

**Configuration:**
- `DATABASE_URL` - PostgreSQL connection string
- Backup frequency: Daily (configured in Railway)

---

## 6. Rails GoodJob (Internal Job Queue)

**Configuration:**
- Max threads: 5 (configured in `config/application.rb`)
- Cron jobs run via GoodJob's built-in scheduler
- No external rate limits

**Cron Jobs:**
- `*/5 * * * *` - Publish scheduled posts
- `*/5 * * * *` - Agentic loop
- `*/15 * * * *` - Execute AI tasks
- `0 6 * * 0` - Weekly strategy analysis

---

## 7. Implementation Notes

### Rate Limit Headers

Always check for rate limit headers in responses:
- `X-RateLimit-Limit` - Maximum requests allowed
- `X-RateLimit-Remaining` - Requests remaining
- `X-RateLimit-Reset` - Unix timestamp when limit resets

### Error Handling

```ruby
# Standard rate limit error handling
case response.code
when 429
  # Rate limited - implement backoff
  retry_after = response.headers['retry-after'].to_i || 60
  sleep(retry_after)
when 500..599
  # Server error - retry with exponential backoff
  sleep(2 ** attempt)
end
```

### Caching Strategy

| Data Type | Cache Duration |
|-----------|----------------|
| User sessions | Session duration |
| Social accounts | 5 minutes |
| Feed data | 1 minute |
| Analytics metrics | 15 minutes |
| Campaign list | 5 minutes |

---

## 8. Testing Rate Limits

Use these methods to test rate limit handling:

```bash
# Test Claude API
curl -X POST https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01"

# Test Postforme API
curl -X GET https://api.postforme.io/social-accounts \
  -H "x-api-key: $POSTFORME_API_KEY"
```

---

*Last Updated: <%= Date.today.strftime("%B %d, %Y") %>*
