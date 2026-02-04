require('dotenv').config();
const express = require('express');
const cors = require('cors');
const axios = require('axios');
const path = require('path');
const db = require('./database');

const app = express();
const PORT = process.env.PORT || 3000;

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

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// OpenAI API configuration
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const DEFAPI_API_KEY = process.env.DEFAPI_API_KEY;
const DEFAPI_BASE_URL = 'https://api.deeinf.com/v1';

// Health check - works even without database
app.get('/health', async (req, res) => {
  let dbStatus = 'disconnected';
  try {
    await db.query('SELECT 1');
    dbStatus = 'connected';
  } catch (e) {
    dbStatus = 'disconnected';
  }
  
  res.json({ 
    status: 'ok', 
    service: 'ultimate-social-media-api',
    timestamp: new Date().toISOString(),
    database: dbStatus,
    version: '1.0.0'
  });
});

// AI Content Generation with Draft Saving
app.post('/api/ai/generate-content', async (req, res) => {
  const { prompt, userId, userName, userEmail } = req.body;
  
  if (!OPENAI_API_KEY) {
    return res.status(500).json({ 
      success: false, 
      error: 'OpenAI API key not configured' 
    });
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
        }
      }
    );

    const generatedContent = openaiResponse.data.choices[0].message.content;
    
    // Save draft to database
    let user;
    if (userId) {
      user = await db.users.findById(userId);
      if (!user) { user = await db.users.create(userName || 'Unknown', userEmail || 'unknown@example.com'); }
    } else {
      user = await db.users.findOrCreate(userName || 'Anonymous', userEmail || 'anonymous@example.com');
    }
    
    const draft = await db.drafts.create(user.id, generatedContent, 'pending');
    
    res.json({ 
      success: true, 
      content: generatedContent, 
      draftId: draft.id, 
      status: draft.status,
      userId: user.id
    });
  } catch (error) {
    console.error('OpenAI API Error:', error.response?.data || error.message);
    res.status(500).json({ 
      success: false, 
      error: 'Failed to generate content',
      details: error.response?.data?.error?.message || error.message
    });
  }
});

// Chat endpoint
app.post('/api/chat', async (req, res) => {
  const { message, userId = 'default-user' } = req.body;
  
  if (!OPENAI_API_KEY) {
    return res.status(500).json({ 
      success: false, 
      response: 'AI chat is not configured. Please set OPENAI_API_KEY.' 
    });
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
        }
      }
    );

    const aiResponse = response.data.choices[0].message.content;
    res.json({ success: true, response: aiResponse, userId });
  } catch (error) {
    console.error('Chat API Error:', error.response?.data || error.message);
    res.json({ 
      success: false, 
      response: 'Sorry, I encountered an error processing your message.' 
    });
  }
});

// Approval Workflow
app.get('/approval', async (req, res) => {
  try {
    const drafts = await db.drafts.findByStatus('pending');
    res.json({ success: true, drafts });
  } catch (error) {
    console.error('Database Error:', error);
    res.status(500).json({ success: false, error: 'Failed to fetch drafts' });
  }
});

app.get('/approval/approved', async (req, res) => {
  try {
    const drafts = await db.drafts.findByStatus('approved');
    res.json({ success: true, drafts });
  } catch (error) {
    console.error('Database Error:', error);
    res.status(500).json({ success: false, error: 'Failed to fetch approved drafts' });
  }
});

app.get('/approval/rejected', async (req, res) => {
  try {
    const drafts = await db.drafts.findByStatus('rejected');
    res.json({ success: true, drafts });
  } catch (error) {
    console.error('Database Error:', error);
    res.status(500).json({ success: false, error: 'Failed to fetch rejected drafts' });
  }
});

app.post('/approval/approve/:draftId', async (req, res) => {
  const { draftId } = req.params;
  try {
    const updatedDraft = await db.drafts.updateStatus(draftId, 'approved');
    if (!updatedDraft) {
      return res.status(404).json({ success: false, error: 'Draft not found' });
    }
    res.json({ success: true, message: 'Draft approved successfully', draft: updatedDraft });
  } catch (error) {
    console.error('Database Error:', error);
    res.status(500).json({ success: false, error: 'Failed to approve draft' });
  }
});

app.post('/approval/reject/:draftId', async (req, res) => {
  const { draftId } = req.params;
  try {
    const updatedDraft = await db.drafts.updateStatus(draftId, 'rejected');
    if (!updatedDraft) {
      return res.status(404).json({ success: false, error: 'Draft not found' });
    }
    res.json({ success: true, message: 'Draft rejected successfully', draft: updatedDraft });
  } catch (error) {
    console.error('Database Error:', error);
    res.status(500).json({ success: false, error: 'Failed to reject draft' });
  }
});

// Video Job endpoints
app.post('/video/start', async (req, res) => {
  const { prompt, userName = 'Anonymous', userEmail = 'anonymous@example.com' } = req.body;
  
  if (!DEFAPI_API_KEY) {
    return res.status(500).json({ 
      success: false, 
      error: 'DefAPI API key not configured' 
    });
  }

  try {
    const response = await axios.post(
      `${DEFAPI_BASE_URL}/video/generate`,
      { prompt },
      {
        headers: {
          'Authorization': `Bearer ${DEFAPI_API_KEY}`,
          'Content-Type': 'application/json'
        }
      }
    );

    const jobId = response.data.job_id || response.data.id;
    
    // Save job to database
    const user = await db.users.findOrCreate(userName, userEmail);
    await db.videoJobs.create(jobId, user.id, prompt, 'pending');
    
    res.json({ jobId, status: 'pending' });
  } catch (error) {
    console.error('DefAPI Error:', error.response?.data || error.message);
    res.status(500).json({ 
      success: false, 
      error: 'Failed to start video generation',
      details: error.response?.data?.message || error.message
    });
  }
});

app.get('/video/status/:jobId', async (req, res) => {
  const { jobId } = req.params;
  
  // First check our database
  let dbJob = await db.videoJobs.findByJobId(jobId);
  
  if (!DEFAPI_API_KEY) {
    return res.json({ 
      jobId, 
      status: dbJob?.status || 'pending', 
      videoUrl: dbJob?.video_url || null,
      message: 'DefAPI not configured - using database status only'
    });
  }

  try {
    const response = await axios.get(
      `${DEFAPI_BASE_URL}/video/status/${jobId}`,
      {
        headers: {
          'Authorization': `Bearer ${DEFAPI_API_KEY}`,
          'Content-Type': 'application/json'
        }
      }
    );

    const externalStatus = response.data.status || 'pending';
    const videoUrl = response.data.video_url || response.data.url || null;
    
    // Update our database with the latest status
    if (dbJob) {
      await db.videoJobs.updateStatus(jobId, externalStatus, videoUrl);
    }
    
    res.json({ jobId, status: externalStatus, videoUrl });
  } catch (error) {
    console.error('DefAPI Status Error:', error.response?.data || error.message);
    
    // Return database status on error
    res.json({ 
      jobId, 
      status: dbJob?.status || 'unknown', 
      videoUrl: dbJob?.video_url || null,
      message: 'Using cached status due to API error'
    });
  }
});

// Database verification endpoint
app.get('/api/db-check', async (req, res) => {
  try {
    await db.query('SELECT 1');
    res.json({ success: true, message: 'Connected to PostgreSQL database' });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Start server
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(async () => {
    await db.close();
    console.log('Server closed');
    process.exit(0);
  });
});

module.exports = app;
