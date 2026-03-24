// Voice Service for Text-to-Speech and Speech-to-Text

// Voice Generation Service - Calls Railway backend
class VoiceService {
  constructor() {
    this.baseUrl = 'https://backend-api-production-00f5.up.railway.app';
    this.defaultVoice = 'pNInz6obpgDQGcFmaJgB'; // Adam voice
  }

  // Generate speech from text using Railway backend (ElevenLabs)
  async generateSpeech(text, voiceId = null) {
    try {
      const response = await fetch(`${this.baseUrl}/api/voice/generate`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          text: text,
          voice: voiceId || this.defaultVoice,
          speed: 1.0
        })
      });

      if (!response.ok) {
        throw new Error(`Voice generation failed: ${response.statusText}`);
      }

      // Return the audio blob directly
      return await response.blob();
    } catch (error) {
      console.error('Voice generation error:', error);
      throw new Error(`Failed to generate speech: ${error.message}`);
    }
  }

  // Get available voices from Railway backend
  async getVoices() {
    try {
      const response = await fetch(`${this.baseUrl}/api/voices`);
      
      if (!response.ok) {
        throw new Error(`Failed to fetch voices: ${response.statusText}`);
      }

      const data = await response.json();
      return data.voices || [];
    } catch (error) {
      console.error('Get voices error:', error);
      throw new Error(`Failed to get voices: ${error.message}`);
    }
  }

  // Play audio blob in browser
  async playAudio(audioBlob) {
    return new Promise((resolve, reject) => {
      const audio = new Audio();
      const url = URL.createObjectURL(audioBlob);
      
      audio.src = url;
      audio.onended = () => {
        URL.revokeObjectURL(url);
        resolve();
      };
      audio.onerror = () => {
        URL.revokeObjectURL(url);
        reject(new Error('Audio playback failed'));
      };
      
      audio.play().catch(reject);
    });
  }

  // Download audio file
  async downloadAudio(audioBlob, filename = 'voice.mp3') {
    const url = URL.createObjectURL(audioBlob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }
}

export default new VoiceService();