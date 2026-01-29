/* eslint-env node */

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const compression = require('compression');
const morgan = require('morgan');
const axios = require('axios');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Security & Performance Middleware
app.use(helmet({
  crossOriginEmbedderPolicy: false
}));
app.use(compression());
app.use(morgan('combined'));

// CORS Configuration
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['*'],
  credentials: process.env.NODE_ENV === 'production'
}));

// Rate Limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.'
});
app.use('/api/', limiter);

// Body Parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Health Check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    service: 'ultimate-social-media-api',
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
});

// ================================
// VOICE GENERATION (ElevenLabs)
// ================================

app.post('/api/voice/generate', async (req, res) => {
  try {
    const { text, voice = 'pNInz6obpgDQGcFmaJgB', speed = 1.0 } = req.body;

    if (!text || text.trim() === '') {
      return res.status(400).json({ error: 'Text is required' });
    }

    if (!process.env.ELEVENLABS_API_KEY) {
      return res.status(500).json({ error: 'ElevenLabs API key not configured' });
    }

    const elevenLabsResponse = await axios.post(
      `https://api.elevenlabs.io/v1/text-to-speech/${voice}`,
      {
        text: text.trim(),
        model_id: 'eleven_monolingual_v1',
        voice_settings: {
          stability: 0.5,
          similarity_boost: 0.5,
          style: 0.0,
          use_speaker_boost: true,
          speed: speed
        }
      },
      {
        headers: {
          'xi-api-key': process.env.ELEVENLABS_API_KEY,
          'Content-Type': 'application/json',
          'Accept': 'audio/mpeg'
        },
        responseType: 'arraybuffer',
        timeout: 30000
      }
    );

    res.setHeader('Content-Type', 'audio/mpeg');
    res.setHeader('Content-Length', elevenLabsResponse.data.length);
    res.setHeader('Cache-Control', 'public, max-age=3600');
    res.setHeader('X-Request-ID', req.headers['x-request-id'] || 'unknown');

    res.send(Buffer.from(elevenLabsResponse.data));

  } catch (error) {
    console.error('ElevenLabs API Error:', error.response?.data || error.message);
    
    if (error.response?.status === 401) {
      res.status(401).json({ error: 'Invalid ElevenLabs API key' });
    } else if (error.response?.status === 413) {
      res.status(413).json({ error: 'Text too long' });
    } else if (error.response?.status === 422) {
      res.status(422).json({ error: 'Invalid voice ID or text format' });
    } else if (error.code === 'ECONNABORTED') {
      res.status(504).json({ error: 'Voice generation timeout' });
    } else {
      res.status(500).json({ 
        error: 'Voice generation failed',
        details: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
});

// Get available voices
app.get('/api/voices', async (req, res) => {
  try {
    if (!process.env.ELEVENLABS_API_KEY) {
      return res.status(500).json({ error: 'ElevenLabs API key not configured' });
    }

    const voicesResponse = await axios.get(
      'https://api.elevenlabs.io/v1/voices',
      {
        headers: {
          'xi-api-key': process.env.ELEVENLABS_API_KEY
        },
        timeout: 10000
      }
    );

    res.json(voicesResponse.data);

  } catch (error) {
    console.error('Get voices error:', error.response?.data || error.message);
    res.status(500).json({ error: 'Failed to fetch voices' });
  }
});

// ================================
// AI CONTENT GENERATION (OpenAI)
// ================================

app.post('/api/ai/generate-content', async (req, res) => {
  try {
    const { prompt, contentType = 'post', platform = 'general', campaign = null } = req.body;

    if (!prompt || prompt.trim() === '') {
      return res.status(400).json({ error: 'Prompt is required' });
    }

    if (!process.env.OPENAI_API_KEY) {
      return res.status(500).json({ error: 'OpenAI API key not configured' });
    }

    const systemPrompt = `You are a social media content creator. Generate engaging ${contentType} content for ${platform} platform. ${campaign ? `Campaign context: ${campaign}` : ''} Make it authentic, engaging, and platform-appropriate.`;

    const openaiResponse = await axios.post(
      'https://api.openai.com/v1/chat/completions',
      {
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: prompt }
        ],
        max_tokens: 500,
        temperature: 0.8
      },
      {
        headers: {
          'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
          'Content-Type': 'application/json'
        },
        timeout: 30000
      }
    );

    const generatedContent = openaiResponse.data.choices[0].message.content;

    res.json({
      success: true,
      content: generatedContent,
      contentType,
      platform,
      campaign,
      usage: openaiResponse.data.usage
    });

  } catch (error) {
    console.error('OpenAI API Error:', error.response?.data || error.message);
    
    if (error.response?.status === 401) {
      res.status(401).json({ error: 'Invalid OpenAI API key' });
    } else if (error.response?.status === 429) {
      res.status(429).json({ error: 'OpenAI rate limit exceeded' });
    } else {
      res.status(500).json({ error: 'Content generation failed' });
    }
  }
});

// ================================
// VIDEO GENERATION (DefAPI - Alternative)
// ================================

app.post('/video/start', async (req, res) => {
  const prompt = req.body.prompt || 'Vertical 9:16, 10s, abstract tech motion';

  if (!process.env.DEFAPI_API_KEY) {
    return res.status(500).json({ error: 'DefAPI API key not configured' });
  }

  try {
    const response = await axios.post(
      'https://api.defapi.org/v1/run',
      {
        model: 'openai/sora-2',
        input: {
          prompt,
          duration: 10,
          aspect_ratio: '9:16'
        }
      },
      {
        headers: {
          Authorization: `Bearer ${process.env.DEFAPI_API_KEY}`,
          'Content-Type': 'application/json'
        }
      }
    );

    res.json({ jobId: response.data.id });
  } catch (error) {
    console.error('DefAPI Error:', error.response?.data || error.message);
    res.status(500).json({ error: 'Video generation failed' });
  }
});

app.get('/video/status/:jobId', async (req, res) => {
  const { jobId } = req.params;

  if (!process.env.DEFAPI_API_KEY) {
    return res.status(500).json({ error: 'DefAPI API key not configured' });
  }

  try {
    const response = await axios.get(
      `https://api.defapi.org/v1/status/${jobId}`,
      {
        headers: { Authorization: `Bearer ${process.env.DEFAPI_API_KEY}` }
      }
    );

    res.json(response.data);
  } catch (error) {
    console.error('DefAPI Status Error:', error.response?.data || error.message);
    res.status(500).json({ error: 'Status check failed' });
  }
});

// ================================
// VIDEO GENERATION (Shotstack)
// ================================

app.post('/api/video/generate', async (req, res) => {
  try {
    const { script, voiceUrl, style = 'social' } = req.body;

    if (!script || script.trim() === '') {
      return res.status(400).json({ error: 'Script is required' });
    }

    if (!process.env.SHOTSTACK_API_KEY) {
      return res.status(500).json({ error: 'Shotstack API key not configured' });
    }

    // Simplified Shotstack API call
    const shotstackResponse = await axios.post(
      'https://api.shotstack.io/stage/render',
      {
        timeline: {
          soundtrack: {
            src: voiceUrl || 'https://shotstack-assets.s3-ap-southeast-2.amazonaws.com/music/freepd/motivation.mp3',
            effect: 'fadeIn'
          },
          tracks: [
            {
              clips: [
                {
                  asset: {
                    type: 'html',
                    html: `<div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 40px; color: white; font-family: Arial; text-align: center;"><h1 style="font-size: 48px; margin: 0;">${script}</h1></div>`
                  },
                  start: 0,
                  length: 5
                }
              ]
            }
          ]
        },
        output: {
          format: 'mp4',
          size: 'landscape_1280x720'
        }
      },
      {
        headers: {
          'x-api-key': process.env.SHOTSTACK_API_KEY,
          'Content-Type': 'application/json'
        },
        timeout: 30000
      }
    );

    res.json({
      success: true,
      renderId: shotstackResponse.data.response.id,
      message: 'Video generation started'
    });

  } catch (error) {
    console.error('Shotstack API Error:', error.response?.data || error.message);
    res.status(500).json({ error: 'Video generation failed' });
  }
});

// ================================
// SOCIAL POSTING (Make.ai)
// ================================

app.post('/api/social/post', async (req, res) => {
  try {
    const { content, platforms, scheduledTime = null } = req.body;

    if (!content || content.trim() === '') {
      return res.status(400).json({ error: 'Content is required' });
    }

    if (!platforms || platforms.length === 0) {
      return res.status(400).json({ error: 'Platforms are required' });
    }

    if (!process.env.MAKEAI_API_KEY) {
      return res.status(500).json({ error: 'Make.ai API key not configured' });
    }

    // Simplified Make.ai integration
    const results = [];

    for (const platform of platforms) {
      try {
        // This would be replaced with actual Make.ai webhook calls
        results.push({
          platform,
          status: 'scheduled',
          message: `Content posted to ${platform}`,
          scheduledTime
        });
      } catch (error) {
        results.push({
          platform,
          status: 'error',
          message: `Failed to post to ${platform}`
        });
      }
    }

    res.json({
      success: true,
      results,
      totalPlatforms: platforms.length,
      scheduledTime
    });

  } catch (error) {
    console.error('Make.ai API Error:', error.message);
    res.status(500).json({ error: 'Social posting failed' });
  }
});

// ================================
// ANALYTICS & PERFORMANCE
// ================================

app.get('/api/analytics/performance', async (req, res) => {
  try {
    // Mock analytics data - replace with actual database queries
    const analytics = {
      totalPosts: Math.floor(Math.random() * 1000),
      scheduledPosts: Math.floor(Math.random() * 50),
      campaigns: Math.floor(Math.random() * 20),
      engagementRate: (Math.random() * 10).toFixed(2),
      reachRate: (Math.random() * 5).toFixed(2),
      conversionRate: (Math.random() * 3).toFixed(2),
      platformBreakdown: {
        instagram: { posts: 150, engagement: '5.2%' },
        tiktok: { posts: 120, engagement: '8.7%' },
        twitter: { posts: 200, engagement: '3.1%' },
        facebook: { posts: 180, engagement: '4.3%' },
        linkedin: { posts: 90, engagement: '6.8%' }
      }
    };

    res.json({
      success: true,
      analytics,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Analytics Error:', error.message);
    res.status(500).json({ error: 'Failed to fetch analytics' });
  }
});

// Error Handling
app.use((error, req, res, next) => {
  console.error('Server Error:', error);
  res.status(500).json({ error: 'Internal server error' });
});

// 404 Handler
app.use('*', (req, res) => {
  res.status(404).json({ 
    error: 'Endpoint not found',
    availableEndpoints: [
      'GET /health',
      'POST /api/voice/generate',
      'GET /api/voices',
      'POST /api/ai/generate-content',
      'POST /api/video/generate',
      'POST /video/start',
      'GET /video/status/:jobId',
      'POST /api/social/post',
      'GET /api/analytics/performance'
    ]
  });
});

app.listen(PORT, () => {
  console.log(`🚀 Ultimate Social Media API running on port ${PORT}`);
  console.log(`📡 Railway deployment ready`);
  console.log(`🎙️ Voice Generation: ElevenLabs`);
  console.log(`🤖 AI Content: OpenAI`);
  console.log(`🎬 Video Generation: Shotstack + DefAPI`);
  console.log(`📱 Social Posting: Make.ai`);
});