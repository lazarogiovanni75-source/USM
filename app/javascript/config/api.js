// API Configuration for Ultimate Social Media Platform
const RAILWAY_API_URL = 'https://backend-api-production-00f5.up.railway.app';

export const apiConfig = {
  baseUrl: RAILWAY_API_URL,
  endpoints: {
    // Voice Generation (ElevenLabs)
    voice: {
      generate: '/api/voice/generate',
      voices: '/api/voices'
    },
    // AI Content Generation (OpenAI)
    ai: {
      generateContent: '/api/ai/generate-content'
    },
    // Video Generation (Shotstack)
    video: {
      generate: '/api/video/generate'
    },
    // Social Media Posting (Make.ai)
    social: {
      post: '/api/social/post'
    },
    // Analytics
    analytics: {
      performance: '/api/analytics/performance'
    }
  }
};

// Test connection to Railway backend
export const testConnection = async () => {
  try {
    const response = await fetch(`${apiConfig.baseUrl}/health`);
    const data = await response.json();
    console.log('✅ Railway API Connected:', data);
    return true;
  } catch (error) {
    console.error('❌ Railway API Connection Failed:', error);
    return false;
  }
};

// Auto-test connection on import
testConnection();