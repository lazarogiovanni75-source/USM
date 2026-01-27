// Video Generation Service

// Video Generation Service - Calls Railway backend (Shotstack)
class VideoService {
  constructor() {
    this.baseUrl = 'https://backend-api-production-00f5.up.railway.app';
  }

  // Generate video using Shotstack via Railway backend
  async generateVideo(script, options = {}) {
    try {
      const response = await fetch(`${this.baseUrl}/api/video/generate`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          script: script,
          voiceUrl: options.voiceUrl || null,
          style: options.style || 'social'
        })
      });

      if (!response.ok) {
        throw new Error(`Video generation failed: ${response.statusText}`);
      }

      const data = await response.json();
      return {
        success: true,
        renderId: data.renderId,
        message: data.message,
        status: 'processing' // Video is being rendered
      };
    } catch (error) {
      console.error('Video generation error:', error);
      throw new Error(`Failed to generate video: ${error.message}`);
    }
  }

  // Generate video with voice-over
  async generateVideoWithVoice(script, voiceBlob) {
    try {
      // First, upload voice file or get URL
      const voiceUrl = await this.uploadVoiceFile(voiceBlob);
      
      // Generate video with voice
      return await this.generateVideo(script, {
        voiceUrl: voiceUrl,
        style: 'social'
      });
    } catch (error) {
      console.error('Video with voice generation error:', error);
      throw new Error(`Failed to generate video with voice: ${error.message}`);
    }
  }

  // Upload voice file (simplified - you might want to use a proper file hosting service)
  async uploadVoiceFile() {
    // In a real implementation, you'd upload this to a file hosting service
    // For now, we'll return a placeholder URL
    const timestamp = Date.now();
    return `https://your-storage-service.com/audio/${timestamp}.mp3`;
  }

  // Create video from text content
  async createTextVideo(textContent, style = 'modern') {
    const script = `Create a video showing: ${textContent}`;
    return this.generateVideo(script, { style });
  }

  // Check video render status (would need to implement this endpoint)
  async checkRenderStatus(renderId) {
    try {
      const response = await fetch(`${this.baseUrl}/api/video/status/${renderId}`);
      
      if (!response.ok) {
        throw new Error(`Failed to check render status: ${response.statusText}`);
      }

      const data = await response.json();
      return {
        renderId: renderId,
        status: data.status,
        progress: data.progress,
        videoUrl: data.videoUrl,
        completed: data.status === 'done'
      };
    } catch (error) {
      console.error('Check render status error:', error);
      throw new Error(`Failed to check render status: ${error.message}`);
    }
  }
}

export default new VideoService();