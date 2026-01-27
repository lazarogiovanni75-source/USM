// Ultimate Social Media Service

// Main Ultimate Social Media Service - Coordinates all Railway backend calls
import voiceService from './voiceService';
import aiService from './aiService';
import videoService from './videoService';
import socialService from './socialService';

class UltimateSocialMediaService {
  constructor() {
    this.voice = voiceService;
    this.ai = aiService;
    this.video = videoService;
    this.social = socialService;
    this.baseUrl = 'https://backend-api-production-00f5.up.railway.app';
  }

  // Complete workflow: Generate AI content, create voice-over, and post to social
  async createAndPostCampaign(options) {
    try {
      const {
        topic,
        platforms,
        contentType = 'post',
        scheduledTime = null,
        includeVoice = false,
        includeVideo = false
      } = options;

      // Step 1: Generate AI content
      const aiResult = await this.ai.generateContent(
        `Create engaging ${contentType} content about: ${topic}`,
        { contentType, platforms: platforms.join(',') }
      );

      let campaign = {
        content: aiResult.content,
        platforms: platforms,
        scheduledTime: scheduledTime,
        aiUsage: aiResult.usage
      };

      // Step 2: Generate voice-over if requested
      if (includeVoice) {
        const voiceResult = await this.voice.generateSpeech(aiResult.content);
        campaign.voiceAudio = voiceResult;
      }

      // Step 3: Generate video if requested
      if (includeVideo) {
        const videoResult = await this.video.generateVideo(aiResult.content);
        campaign.videoRenderId = videoResult.renderId;
      }

      // Step 4: Post to social platforms
      const socialResult = await this.social.postToPlatforms(
        aiResult.content,
        platforms,
        { scheduledTime }
      );

      return {
        success: true,
        campaign: campaign,
        socialResults: socialResult,
        message: 'Campaign created and posted successfully'
      };

    } catch (error) {
      console.error('Campaign creation error:', error);
      throw new Error(`Failed to create campaign: ${error.message}`);
    }
  }

  // Voice Command Workflow
  async processVoiceCommand(commandText) {
    try {
      // Generate AI response based on command
      const aiResult = await this.ai.generateContent(
        `User said: "${commandText}". Interpret this as a social media command and suggest appropriate actions.`
      );

      // If they want voice generation, create audio
      let audioBlob = null;
      if (aiResult.content.toLowerCase().includes('speak') || 
          aiResult.content.toLowerCase().includes('voice')) {
        audioBlob = await this.voice.generateSpeech(aiResult.content);
      }

      return {
        success: true,
        interpretation: aiResult.content,
        audio: audioBlob,
        usage: aiResult.usage
      };

    } catch (error) {
      console.error('Voice command processing error:', error);
      throw new Error(`Failed to process voice command: ${error.message}`);
    }
  }

  // Get comprehensive analytics
  async getFullAnalytics() {
    try {
      const analytics = await this.social.getAnalytics();
      return {
        success: true,
        analytics: analytics.analytics,
        timestamp: analytics.timestamp,
        servicesConnected: {
          voice: true,
          ai: true,
          video: true,
          social: true
        }
      };
    } catch (error) {
      console.error('Full analytics error:', error);
      throw new Error(`Failed to get analytics: ${error.message}`);
    }
  }

  // Test all Railway connections
  async testAllConnections() {
    const results = {
      voice: false,
      ai: false,
      video: false,
      social: false,
      overall: false
    };

    try {
      // Test health endpoint
      const healthResponse = await fetch(`${this.baseUrl}/health`);
      const health = await healthResponse.json();

      if (health.status === 'ok') {
        results.overall = true;
        
        // Test individual services
        try {
          await this.voice.getVoices();
          results.voice = true;
        } catch {
          // Silent catch for individual service failures
        }

        try {
          await this.ai.generateContent('test', { contentType: 'test' });
          results.ai = true;
        } catch {
          // Silent catch for individual service failures
        }

        try {
          await this.social.getAnalytics();
          results.social = true;
        } catch {
          // Silent catch for individual service failures
        }
      }

      return results;
    } catch (error) {
      console.error('Connection test failed:', error);
      return results;
    }
  }
}

// Create singleton instance
const ultimateSocialMediaService = new UltimateSocialMediaService();

// Export both the class and instance
export default ultimateSocialMediaService;
export { UltimateSocialMediaService };