require('dotenv').config();
const express = require('express');
const cors = require('cors');
const axios = require('axios');
const path = require('path');
const db = require('./database');

// Import middleware
const logger = require('./middleware/logger');
const { errorHandler, asyncHandler, notFoundHandler, AppError } = require('./middleware/errorHandler');
const { validateRequired, validateTypes, sanitizeInput } = require('./middleware/validator');
const { apiLimiter, aiLimiter, videoLimiter, helmetConfig } = require('./middleware/security');
const { healthCheck, readinessCheck, livenessCheck, metricsCheck, trackRequest, trackError } = require('./monitoring');

const app = express();
const PORT = process.env.PORT || 3000;

// Security headers
app.use(helmetConfig);

// CORS configuration
const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'];
app.use(cors({
  origin: function(origin, callback) {
    if (!origin) return callback(null, true);
    if (allowedOrigins.indexOf(origin) !== -1) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true
}));

// Body parsing and static files
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(express.static(path.join(__dirname, 'public')));

// Request logging and tracking
app.use(logger);
app.use((req, res, next) => {
  trackRequest();
  next();
});

// Input sanitization
app.use(sanitizeInput);

// API configuration
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const ATLAS_CLOUD_API_KEY = process.env.ATLASCLOUD_API_KEY || process.env.ATLAS_CLOUD_API_KEY;
const ATLAS_CLOUD_BASE_URL = 'https://api.atlascloud.ai';

// =====================
// MONITORING ENDPOINTS
// =====================

// Basic health check - used by Railway for health monitoring
app.get('/health', healthCheck);

// Detailed readiness check - shows status of all dependencies
app.get('/ready', readinessCheck);

// Liveness probe - for container orchestration
app.get('/live', livenessCheck);

// Metrics endpoint - comprehensive system metrics
app.get('/metrics', metricsCheck);

// =====================
// API ENDPOINTS (v1)
// =====================

// AI Content Generation with Draft Saving
app.post('/api/ai/generate-content', 
  aiLimiter,
  validateRequired(['prompt']),
  asyncHandler(async (req, res) => {
    const { prompt, userId, userName, userEmail } = req.body;
    
    if (!OPENAI_API_KEY) {
      throw new AppError('OpenAI API key not configured', 503, 'SERVICE_UNAVAILABLE');
    }

    try {
      const openaiResponse = await axios.post(
        'https://api.openai.com/v1/chat/completions',
        {
          model: 'gpt-3.5-turbo',
          messages: [
            {
              role: 'system',
              content: 'You are a social media content creator. Generate engaging content based on the user prompt.'
            },
            { role: 'user', content: prompt }
          ],
          max_tokens: 500
        },
        {
          headers: {
            'Authorization': `Bearer ${OPENAI_API_KEY}`,
            'Content-Type': 'application/json'
          },
          timeout: 30000 // 30 second timeout
        }
      );

      const generatedContent = openaiResponse.data.choices[0].message.content;
      
      // Save draft to database (if connected)
      let draftId = null;
      let userIdResult = userId;
      
      try {
        let user;
        if (userId) {
          user = await db.users.findById(userId);
          if (!user) { 
            user = await db.users.create(userName || 'Unknown', userEmail || 'unknown@example.com'); 
          }
        } else {
          user = await db.users.findOrCreate(userName || 'Anonymous', userEmail || 'anonymous@example.com');
        }
        
        const draft = await db.drafts.create(user.id, generatedContent, 'pending');
        draftId = draft.id;
        userIdResult = user.id;
      } catch (dbError) {
        console.warn('[WARNING] Database unavailable, skipping draft save:', dbError.message);
      }
      
      res.json({ 
        success: true, 
        content: generatedContent, 
        draftId, 
        status: draftId ? 'pending' : 'generated',
        userId: userIdResult
      });
    } catch (error) {
      if (error.response?.status === 429) {
        throw new AppError('OpenAI rate limit exceeded', 429, 'OPENAI_RATE_LIMIT');
      }
      if (error.code === 'ECONNABORTED') {
        throw new AppError('OpenAI request timeout', 504, 'GATEWAY_TIMEOUT');
      }
      throw new AppError(
        'Failed to generate content: ' + (error.response?.data?.error?.message || error.message),
        500,
        'OPENAI_ERROR'
      );
    }
  })
);

// Chat endpoint
app.post('/api/chat', 
  aiLimiter,
  validateRequired(['message']),
  asyncHandler(async (req, res) => {
    const { message, userId = 'default-user' } = req.body;
    
    if (!OPENAI_API_KEY) {
      throw new AppError('AI chat is not configured', 503, 'SERVICE_UNAVAILABLE');
    }

    try {
      const response = await axios.post(
        'https://api.openai.com/v1/chat/completions',
        {
          model: 'gpt-3.5-turbo',
          messages: [
            {
              role: 'system',
              content: 'You are a helpful AI assistant. Provide clear and concise responses.'
            },
            { role: 'user', content: message }
          ],
          max_tokens: 300
        },
        {
          headers: {
            'Authorization': `Bearer ${OPENAI_API_KEY}`,
            'Content-Type': 'application/json'
          },
          timeout: 30000
        }
      );

      const aiResponse = response.data.choices[0].message.content;
      res.json({ success: true, response: aiResponse, userId });
    } catch (error) {
      if (error.response?.status === 429) {
        throw new AppError('OpenAI rate limit exceeded', 429, 'OPENAI_RATE_LIMIT');
      }
      throw new AppError(
        'Chat error: ' + (error.response?.data?.error?.message || error.message),
        500,
        'CHAT_ERROR'
      );
    }
  })
);

// =====================
// APPROVAL WORKFLOW
// =====================

app.get('/approval', 
  apiLimiter,
  asyncHandler(async (req, res) => {
    const drafts = await db.drafts.findByStatus('pending');
    res.json({ success: true, drafts });
  })
);

app.get('/approval/approved', 
  apiLimiter,
  asyncHandler(async (req, res) => {
    const drafts = await db.drafts.findByStatus('approved');
    res.json({ success: true, drafts });
  })
);

app.get('/approval/rejected', 
  apiLimiter,
  asyncHandler(async (req, res) => {
    const drafts = await db.drafts.findByStatus('rejected');
    res.json({ success: true, drafts });
  })
);

app.post('/approval/approve/:draftId', 
  apiLimiter,
  asyncHandler(async (req, res) => {
    const { draftId } = req.params;
    const updatedDraft = await db.drafts.updateStatus(draftId, 'approved');
    
    if (!updatedDraft) {
      throw new AppError('Draft not found', 404, 'NOT_FOUND');
    }
    
    res.json({ success: true, message: 'Draft approved successfully', draft: updatedDraft });
  })
);

app.post('/approval/reject/:draftId', 
  apiLimiter,
  asyncHandler(async (req, res) => {
    const { draftId } = req.params;
    const updatedDraft = await db.drafts.updateStatus(draftId, 'rejected');
    
    if (!updatedDraft) {
      throw new AppError('Draft not found', 404, 'NOT_FOUND');
    }
    
    res.json({ success: true, message: 'Draft rejected successfully', draft: updatedDraft });
  })
);

// =====================
// VIDEO GENERATION
// =====================

app.post('/video/start', 
  videoLimiter,
  validateRequired(['prompt']),
  asyncHandler(async (req, res) => {
    const { prompt, userName = 'Anonymous', userEmail = 'anonymous@example.com' } = req.body;
    
    if (!ATLAS_CLOUD_API_KEY) {
      throw new AppError('Atlas Cloud API key not configured', 503, 'SERVICE_UNAVAILABLE');
    }

    try {
      const response = await axios.post(
        `${ATLAS_CLOUD_BASE_URL}/api/v1/model/generateVideo`,
        {
          model: 'google/veo3.1-lite/text-to-video',
          prompt: prompt,
          duration: 5,
          aspect_ratio: '16:9',
          resolution: '720p'
        },
        {
          headers: {
            'Authorization': `Bearer ${ATLAS_CLOUD_API_KEY}`,
            'Content-Type': 'application/json'
          },
          timeout: 30000
        }
      );

      const jobId = response.data.data.task_id;
      
      // Save job to database (if connected)
      try {
        const user = await db.users.findOrCreate(userName, userEmail);
        await db.videoJobs.create(jobId, user.id, prompt, 'pending');
      } catch (dbError) {
        console.warn('[WARNING] Database unavailable, skipping video job save:', dbError.message);
      }
      
      res.json({ 
        success: true,
        jobId, 
        status: 'pending',
        message: 'Video generation started'
      });
    } catch (error) {
      throw new AppError(
        'Video generation failed: ' + (error.response?.data?.error?.message || error.message),
        500,
        'VIDEO_GENERATION_ERROR'
      );
    }
  })
);

app.get('/video/status/:jobId', 
  apiLimiter,
  asyncHandler(async (req, res) => {
    const { jobId } = req.params;
    
    if (!ATLAS_CLOUD_API_KEY) {
      throw new AppError('Atlas Cloud API key not configured', 503, 'SERVICE_UNAVAILABLE');
    }

    try {
      const response = await axios.get(
        `${ATLAS_CLOUD_BASE_URL}/api/v1/model/prediction/${jobId}`,
        {
          headers: {
            'Authorization': `Bearer ${ATLAS_CLOUD_API_KEY}`
          },
          timeout: 10000
        }
      );

      const taskData = response.data.data;
      const status = taskData.status === 'finished' ? 'completed' : taskData.status;
      const video_url = taskData.result?.video_url || null;
      
      // Update database if video is complete
      if (status === 'completed' && video_url) {
        try {
          await db.videoJobs.updateStatus(jobId, 'completed', video_url);
        } catch (dbError) {
          console.warn('[WARNING] Database unavailable, skipping status update:', dbError.message);
        }
      }
      
      res.json({ 
        success: true,
        jobId, 
        status, 
        videoUrl: video_url || null 
      });
    } catch (error) {
      throw new AppError(
        'Failed to check video status: ' + (error.response?.data?.error?.message || error.message),
        500,
        'VIDEO_STATUS_ERROR'
      );
    }
  })
);

// =====================
// ERROR HANDLING
// =====================

// 404 handler - must be after all routes
app.use(notFoundHandler);

// Global error handler - must be last
app.use((err, req, res, next) => {
  trackError();
  errorHandler(err, req, res, next);
});

// =====================
// SERVER STARTUP & GRACEFUL SHUTDOWN
// =====================

let server;

async function startServer() {
  try {
    // Connect to database
    await db.dbManager.connect();
    
    // Start HTTP server
    server = app.listen(PORT, '0.0.0.0', () => {
      console.log(`
╔════════════════════════════════════════════════════════╗
║  🚀 Ultimate Social Media API Server                  ║
║  📡 Port: ${PORT}                                       ║
║  🌍 Environment: ${process.env.NODE_ENV || 'development'}                     ║
║  ✅ Status: Running                                    ║
╚════════════════════════════════════════════════════════╝
      `);
    });
  } catch (error) {
    console.error('[FATAL] Failed to start server:', error);
    process.exit(1);
  }
}

// Graceful shutdown handler
async function shutdown(signal) {
  console.log(`\n[${signal}] Graceful shutdown initiated...`);
  
  // Stop accepting new connections
  if (server) {
    server.close(() => {
      console.log('[SHUTDOWN] HTTP server closed');
    });
  }
  
  // Close database connections
  try {
    await db.close();
  } catch (error) {
    console.error('[SHUTDOWN] Database close error:', error);
  }
  
  console.log('[SHUTDOWN] Cleanup complete. Exiting...');
  process.exit(0);
}

// Handle shutdown signals
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

// Handle uncaught errors
process.on('uncaughtException', (error) => {
  console.error('[FATAL] Uncaught Exception:', error);
  shutdown('UNCAUGHT_EXCEPTION');
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('[FATAL] Unhandled Rejection at:', promise, 'reason:', reason);
  shutdown('UNHANDLED_REJECTION');
});

// Start the server
startServer();

module.exports = app;
