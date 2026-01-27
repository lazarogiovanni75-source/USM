/* eslint-disable no-undef */
const express = require('express');
const cors = require('cors');
const axios = require('axios');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
  credentials: true
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'voice-generation-service' });
});

// ElevenLabs Text-to-Speech endpoint
app.post('/voice/generate', async (req, res) => {
  try {
    const { text, voice = 'pNInz6obpgDQGcFmaJgB' } = req.body;

    if (!text || text.trim() === '') {
      return res.status(400).json({ error: 'Text is required' });
    }

    if (!process.env.ELEVENLABS_API_KEY) {
      return res.status(500).json({ error: 'ElevenLabs API key not configured' });
    }

    // Call ElevenLabs API
    const elevenLabsResponse = await axios.post(
      `https://api.elevenlabs.io/v1/text-to-speech/${voice}`,
      {
        text: text.trim(),
        model_id: 'eleven_monolingual_v1',
        voice_settings: {
          stability: 0.5,
          similarity_boost: 0.5,
          style: 0.0,
          use_speaker_boost: true
        }
      },
      {
        headers: {
          'xi-api-key': process.env.ELEVENLABS_API_KEY,
          'Content-Type': 'application/json',
          'Accept': 'audio/mpeg'
        },
        responseType: 'arraybuffer'
      }
    );

    // Set response headers for audio stream
    res.setHeader('Content-Type', 'audio/mpeg');
    res.setHeader('Content-Length', elevenLabsResponse.data.length);
    res.setHeader('Cache-Control', 'public, max-age=3600');

    // Return audio stream
    res.send(Buffer.from(elevenLabsResponse.data));

  } catch (error) {
    console.error('ElevenLabs API Error:', error.response?.data || error.message);
    
    if (error.response?.status === 401) {
      return res.status(401).json({ error: 'Invalid ElevenLabs API key' });
    } else if (error.response?.status === 413) {
      return res.status(413).json({ error: 'Text too long' });
    } else if (error.response?.status === 422) {
      return res.status(422).json({ error: 'Invalid voice ID or text format' });
    } else {
      return res.status(500).json({ 
        error: 'Voice generation failed',
        details: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
});

// Get available voices
app.get('/voices', async (req, res) => {
  try {
    if (!process.env.ELEVENLABS_API_KEY) {
      return res.status(500).json({ error: 'ElevenLabs API key not configured' });
    }

    const voicesResponse = await axios.get(
      'https://api.elevenlabs.io/v1/voices',
      {
        headers: {
          'xi-api-key': process.env.ELEVENLABS_API_KEY
        }
      }
    );

    res.json(voicesResponse.data);

  } catch (error) {
    console.error('Get voices error:', error.response?.data || error.message);
    res.status(500).json({ error: 'Failed to fetch voices' });
  }
});

// Error handling middleware
app.use((error, req, res) => {
  console.error('Server Error:', error);
  res.status(500).json({ error: 'Internal server error' });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Endpoint not found' });
});

app.listen(PORT, () => {
  console.log(`🎙️ Voice Generation Service running on port ${PORT}`);
  console.log(`📝 Available endpoints:`);
  console.log(`   POST /voice/generate - Generate speech from text`);
  console.log(`   GET  /voices - Get available voices`);
  console.log(`   GET  /health - Health check`);
});