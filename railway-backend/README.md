# Ultimate Social Media API - Railway Backend

**Production-Grade Node.js/Express API for Third-Party Service Integration**

---

## 🚀 Quick Start

### Environment Variables

Required environment variables for Railway deployment:

```bash
# Server Configuration
PORT=3000
NODE_ENV=production

# CORS Configuration
ALLOWED_ORIGINS=https://ultimatesocialmedia01.com,https://your-clacky-thread.clacky.app

# API Keys
OPENAI_API_KEY=sk-xxxxx
ATLAS_CLOUD_API_KEY=your-atlas-cloud-key

# Database (Optional - runs in degraded mode without DB)
DATABASE_URL=postgresql://user:pass@host:5432/dbname
```

### Deployment on Railway

1. **Connect GitHub Repository**
2. **Set Environment Variables** (see above)
3. **Configure Service Settings:**
   - Root Directory: `railway-backend`
   - Start Command: `npm start` (auto-detected)
4. **Deploy** - Railway will automatically build and deploy

---

## 📡 API Endpoints

### Monitoring & Health Checks

#### `GET /health`
Basic health check for Railway monitoring.

**Response:**
```json
{
  "status": "ok",
  "service": "ultimate-social-media-api",
  "timestamp": "2024-02-04T10:30:00.000Z",
  "version": "1.0.0"
}
```

#### `GET /ready`
Readiness check showing status of all dependencies.

**Response:**
```json
{
  "status": "ready",
  "checks": {
    "server": "ok",
    "database": "ok",
    "openai": "configured",
    "atlas_cloud": "configured"
  },
  "timestamp": "2024-02-04T10:30:00.000Z"
}
```

#### `GET /live`
Liveness probe for container orchestration.

**Response:**
```json
{
  "status": "alive",
  "uptime": 3600,
  "timestamp": "2024-02-04T10:30:00.000Z"
}
```

#### `GET /metrics`
Comprehensive system metrics and statistics.

**Response:**
```json
{
  "service": "ultimate-social-media-api",
  "uptime_seconds": 3600,
  "requests": {
    "total": 1250,
    "errors": 3,
    "success_rate": "99.76%"
  },
  "database": {
    "connected": true,
    "connection_attempts": 0
  },
  "system": {
    "memory": { "total": "512MB", "free": "256MB", "used": "256MB", "usage": "50%" },
    "cpu": { "cores": 2, "model": "Intel Xeon" }
  }
}
```

---

### AI Content Generation

#### `POST /api/ai/generate-content`
Generate social media content using OpenAI.

**Rate Limit:** 50 requests/hour per IP

**Request Body:**
```json
{
  "prompt": "Create a tweet about climate change",
  "userId": "optional-user-id",
  "userName": "John Doe",
  "userEmail": "john@example.com"
}
```

**Response (Success):**
```json
{
  "success": true,
  "content": "🌍 Climate change is real...",
  "draftId": 123,
  "status": "pending",
  "userId": "user-id"
}
```

**Response (Error):**
```json
{
  "success": false,
  "error": {
    "code": "OPENAI_RATE_LIMIT",
    "message": "OpenAI rate limit exceeded"
  }
}
```

---

#### `POST /api/chat`
Chat with AI assistant.

**Rate Limit:** 50 requests/hour per IP

**Request Body:**
```json
{
  "message": "What's the best time to post on Instagram?",
  "userId": "optional-user-id"
}
```

**Response:**
```json
{
  "success": true,
  "response": "The best times to post on Instagram are typically...",
  "userId": "user-id"
}
```

---

### Approval Workflow

#### `GET /approval`
Get all pending drafts awaiting approval.

**Rate Limit:** 100 requests/15min per IP

**Response:**
```json
{
  "success": true,
  "drafts": [
    {
      "id": 1,
      "user_id": 123,
      "text": "Draft content here...",
      "status": "pending",
      "created_at": "2024-02-04T10:00:00.000Z"
    }
  ]
}
```

#### `GET /approval/approved`
Get all approved drafts.

#### `GET /approval/rejected`
Get all rejected drafts.

#### `POST /approval/approve/:draftId`
Approve a draft by ID.

**Response:**
```json
{
  "success": true,
  "message": "Draft approved successfully",
  "draft": { "id": 1, "status": "approved" }
}
```

#### `POST /approval/reject/:draftId`
Reject a draft by ID.

---

### Video Generation

#### `POST /video/start`
Start video generation job.

**Rate Limit:** 10 requests/hour per IP

**Request Body:**
```json
{
  "prompt": "Create a video about ocean conservation",
  "userName": "Jane Doe",
  "userEmail": "jane@example.com"
}
```

**Response:**
```json
{
  "success": true,
  "jobId": "job-abc123",
  "status": "pending",
  "message": "Video generation started"
}
```

#### `GET /video/status/:jobId`
Check video generation status.

**Rate Limit:** 100 requests/15min per IP

**Response (In Progress):**
```json
{
  "success": true,
  "jobId": "job-abc123",
  "status": "processing",
  "videoUrl": null
}
```

**Response (Completed):**
```json
{
  "success": true,
  "jobId": "job-abc123",
  "status": "completed",
  "videoUrl": "https://cdn.example.com/video.mp4"
}
```

---

## 🔒 Security Features

### Rate Limiting
- **General API:** 100 requests/15min per IP
- **AI Endpoints:** 50 requests/hour per IP
- **Video Generation:** 10 requests/hour per IP

### Security Headers
- Helmet.js for comprehensive security headers
- Content Security Policy (CSP)
- HSTS (HTTP Strict Transport Security)
- X-Frame-Options, X-Content-Type-Options, etc.

### Input Validation
- Required field validation
- Type checking
- XSS prevention (script tag removal)
- Request size limits (10MB)

### CORS
- Configurable allowed origins via `ALLOWED_ORIGINS` env variable
- Credentials support for authenticated requests

---

## 🗄️ Database

The API supports PostgreSQL for persistent storage but **runs in degraded mode** if database is unavailable.

**Features:**
- Connection pooling (max 20 connections)
- Auto-retry on connection failure (5 attempts)
- Graceful degradation (API continues without DB)

**Database Operations:**
- User management
- Draft content storage
- Video job tracking

---

## 🛠️ Error Handling

All errors return consistent JSON format:

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message"
  }
}
```

**Common Error Codes:**
- `VALIDATION_ERROR` - Missing or invalid request data
- `RATE_LIMIT_EXCEEDED` - Too many requests
- `OPENAI_RATE_LIMIT` - OpenAI API rate limit
- `SERVICE_UNAVAILABLE` - External service unavailable
- `NOT_FOUND` - Resource not found
- `INTERNAL_ERROR` - Server error

---

## 📊 Monitoring

### Railway Dashboard
Monitor your deployment:
- Health status via `/health` endpoint
- Request logs and errors
- Memory and CPU usage
- Deployment history

### Custom Metrics
Access `/metrics` endpoint for detailed statistics:
- Request count and success rate
- Uptime and performance
- Database connection status
- System resource usage

---

## 🚦 Deployment Checklist

- [ ] Set all required environment variables
- [ ] Configure `ALLOWED_ORIGINS` with production domains
- [ ] Add OpenAI API key (`OPENAI_API_KEY`)
- [ ] Add Atlas Cloud key if using video generation (`ATLAS_CLOUD_API_KEY`)
- [ ] Optional: Connect PostgreSQL database (`DATABASE_URL`)
- [ ] Verify `/health` endpoint returns 200 OK
- [ ] Test CORS from your frontend domain
- [ ] Check `/metrics` for system status

---

## 🔄 Zero-Downtime Deployments

The server implements graceful shutdown:
- Stops accepting new connections on SIGTERM/SIGINT
- Completes in-flight requests
- Closes database connections cleanly
- Exits with proper status code

Railway automatically handles:
- Rolling deployments
- Health check monitoring
- Automatic restart on failure

---

## 📞 Support

**Production URL:** `https://clacky-clean-production-c2a4.up.railway.app`

**Common Issues:**

1. **502 Bad Gateway**
   - Check Railway logs for startup errors
   - Verify all required env variables are set
   - Ensure `PORT` is set to 3000

2. **CORS Errors**
   - Add your domain to `ALLOWED_ORIGINS`
   - Format: `https://domain1.com,https://domain2.com`

3. **OpenAI Errors**
   - Verify `OPENAI_API_KEY` is valid
   - Check OpenAI account has credits
   - Review rate limits

4. **Database Errors**
   - API runs without database (degraded mode)
   - Draft/job saving will be skipped
   - Check `DATABASE_URL` format if using DB

---

## 📄 License

Part of Ultimate Social Media platform.

**Last Updated:** February 2024  
**Version:** 1.0.0
