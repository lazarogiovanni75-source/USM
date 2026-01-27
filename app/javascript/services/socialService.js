// Social Media API Service

// Social Media Posting Service - Calls Railway backend (Make.ai)
class SocialService {
  constructor() {
    this.baseUrl = 'https://backend-api-production-00f5.up.railway.app';
    this.supportedPlatforms = ['instagram', 'twitter', 'facebook', 'linkedin', 'tiktok'];
  }

  // Post content to multiple platforms using Make.ai via Railway backend
  async postToPlatforms(content, platforms, options = {}) {
    try {
      // Validate platforms
      const validPlatforms = platforms.filter(p => 
        this.supportedPlatforms.includes(p.toLowerCase())
      );

      if (validPlatforms.length === 0) {
        throw new Error('No valid platforms specified');
      }

      const response = await fetch(`${this.baseUrl}/api/social/post`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          content: content,
          platforms: validPlatforms,
          scheduledTime: options.scheduledTime || null,
          mediaUrls: options.mediaUrls || []
        })
      });

      if (!response.ok) {
        throw new Error(`Social posting failed: ${response.statusText}`);
      }

      const data = await response.json();
      return {
        success: true,
        results: data.results,
        totalPlatforms: data.totalPlatforms,
        scheduledTime: data.scheduledTime,
        postedCount: data.results.filter(r => r.status === 'scheduled' || r.status === 'posted').length,
        failedCount: data.results.filter(r => r.status === 'error').length
      };
    } catch (error) {
      console.error('Social posting error:', error);
      throw new Error(`Failed to post to social media: ${error.message}`);
    }
  }

  // Post to single platform
  async postToPlatform(content, platform, options = {}) {
    return this.postToPlatforms(content, [platform], options);
  }

  // Schedule post for later
  async schedulePost(content, platforms, scheduledTime) {
    return this.postToPlatforms(content, platforms, {
      scheduledTime: scheduledTime
    });
  }

  // Get analytics from Railway backend
  async getAnalytics() {
    try {
      const response = await fetch(`${this.baseUrl}/api/analytics/performance`);
      
      if (!response.ok) {
        throw new Error(`Failed to fetch analytics: ${response.statusText}`);
      }

      const data = await response.json();
      return {
        success: true,
        analytics: data.analytics,
        timestamp: data.timestamp
      };
    } catch (error) {
      console.error('Analytics error:', error);
      throw new Error(`Failed to fetch analytics: ${error.message}`);
    }
  }

  // Get platform-specific posting tips
  getPlatformTips(platform) {
    const tips = {
      instagram: [
        'Use high-quality images or videos',
        'Include 5-10 relevant hashtags',
        'Post during peak hours (6-9 PM)',
        'Use Instagram Stories for engagement',
        'Add location tags when relevant'
      ],
      twitter: [
        'Keep tweets under 280 characters',
        'Use 1-2 relevant hashtags',
        'Include trending topics when relevant',
        'Tweet during business hours',
        'Engage with replies and mentions'
      ],
      facebook: [
        'Use eye-catching visuals',
        'Ask questions to encourage engagement',
        'Share behind-the-scenes content',
        'Use Facebook Live for real-time engagement',
        'Post during afternoon hours'
      ],
      linkedin: [
        'Share professional insights',
        'Use industry-specific hashtags',
        'Post during business hours',
        'Engage with comments and discussions',
        'Share company updates and achievements'
      ],
      tiktok: [
        'Use trending sounds and effects',
        'Keep videos short and engaging',
        'Post consistently',
        'Use popular hashtags',
        'Collaborate with other creators'
      ]
    };

    return tips[platform.toLowerCase()] || [];
  }

  // Validate content for platform
  validateContent(content, platform) {
    const validation = {
      platform: platform,
      isValid: true,
      warnings: [],
      suggestions: []
    };

    switch (platform.toLowerCase()) {
      case 'twitter':
        if (content.length > 280) {
          validation.isValid = false;
          validation.warnings.push('Content exceeds 280 character limit');
        }
        break;
      
      case 'instagram':
        if (!content.includes('#')) {
          validation.suggestions.push('Consider adding hashtags for better reach');
        }
        break;
    }

    return validation;
  }
}

export default new SocialService();