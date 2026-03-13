// Video Generation Service
// Calls Atlas Cloud Service for video generation

class VideoService {
  constructor() {
    this.baseUrl = '/content_creation';
  }

  // Generate video using Atlas Cloud
  async generateVideo(script) {
    try {
      const response = await fetch(`${this.baseUrl}/generate_video`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]')?.content || ''
        },
        body: new URLSearchParams({
          prompt: script
        })
      });

      if (!response.ok) {
        throw new Error(`Video generation failed: ${response.statusText}`);
      }

      const data = await response.json();
      return {
        success: true,
        message: data.notice || 'Video generation started',
        status: 'processing'
      };
    } catch (error) {
      console.error('Video generation error:', error);
      throw new Error(`Failed to generate video: ${error.message}`);
    }
  }

  // Create video from text content
  async createTextVideo(textContent) {
    return this.generateVideo(textContent);
  }
}

export default new VideoService();
