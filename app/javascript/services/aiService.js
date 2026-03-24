// API Service for AI Content Generation

// AI Content Generation Service - Calls Railway backend (OpenAI)
class AiService {
  constructor() {
    // Use environment variable for Railway backend URL with fallback
    this.baseUrl = process.env.RAILWAY_BACKEND_URL || 'https://your-backend-app.up.railway.app';
  }

  // Generate content using OpenAI via Railway backend
  async generateContent(prompt, options = {}) {
    try {
      const response = await fetch(`${this.baseUrl}/api/ai/generate-content`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          prompt: prompt,
          contentType: options.contentType || 'post',
          platform: options.platform || 'general',
          campaign: options.campaign || null
        })
      });

      if (!response.ok) {
        throw new Error(`Content generation failed: ${response.statusText}`);
      }

      const data = await response.json();
      return {
        success: true,
        content: data.content,
        contentType: data.contentType,
        platform: data.platform,
        campaign: data.campaign,
        usage: data.usage
      };
    } catch (error) {
      console.error('AI content generation error:', error);
      throw new Error(`Failed to generate content: ${error.message}`);
    }
  }

  // Generate specific types of content
  async generatePost(platform, topic) {
    const prompt = `Create an engaging social media post for ${platform} about: ${topic}`;
    return this.generateContent(prompt, {
      contentType: 'post',
      platform: platform
    });
  }

  async generateCaption(platform, imageDescription) {
    const prompt = `Create a compelling caption for a ${platform} post showing: ${imageDescription}`;
    return this.generateContent(prompt, {
      contentType: 'caption',
      platform: platform
    });
  }

  async generateHashtags(topic, count = 5) {
    const prompt = `Generate ${count} relevant hashtags for this topic: ${topic}. Return only the hashtags separated by spaces.`;
    return this.generateContent(prompt, {
      contentType: 'hashtags'
    });
  }

  async generateCampaignIdea(industry, targetAudience) {
    const prompt = `Generate creative social media campaign ideas for a ${industry} company targeting ${targetAudience}. Provide 3-5 actionable campaign concepts.`;
    return this.generateContent(prompt, {
      contentType: 'campaign'
    });
  }

  // Generate voice-over script
  async generateVoiceScript(content, voiceStyle = 'professional') {
    const prompt = `Create a ${voiceStyle} voice-over script for this content: ${content}. Make it sound natural and engaging for audio playback.`;
    return this.generateContent(prompt, {
      contentType: 'voice_script'
    });
  }
}

export default new AiService();