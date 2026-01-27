class VoiceController < ApplicationController
  before_action :authenticate_user!

  def generate_voice
    text = params[:text]
    voice_id = params[:voice_id] || 'pNInz6obpgDQGcFmaJgB' # Default voice
    tone = params[:tone] || 'neutral'
    speed = params[:speed] || 1.0

    # Call Railway backend for voice generation
    response = call_railway_voice_api(text, voice_id, tone, speed)
    
    render json: response
  end

  def speech_to_text
    audio_file = params[:audio_file]
    
    # Call Railway backend for speech-to-text
    response = call_railway_speech_api(audio_file)
    
    render json: response
  end

  def get_voices
    # Call Railway backend to get available voices
    response = call_railway_voices_api()
    
    render json: response
  end

  def save_voice_settings
    user_voice_setting = current_user.voice_settings.find_or_initialize_by(
      voice_id: params[:voice_id]
    )
    
    if user_voice_setting.update(
      tone: params[:tone],
      speed: params[:speed]
    )
      render json: { success: true, message: "Voice settings saved" }
    else
      render json: { success: false, errors: user_voice_setting.errors.full_messages }
    end
  end

  private

  def call_railway_voice_api(text, voice_id, tone, speed)
    begin
      response = RestClient.post(
        "#{ENV['RAILWAY_BACKEND_URL']}/api/voice/generate",
        {
          text: text,
          voice_id: voice_id,
          tone: tone,
          speed: speed.to_f
        },
        {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{ENV['RAILWAY_API_KEY']}"
        }
      )
      
      JSON.parse(response.body)
    rescue => e
      Rails.logger.error "Railway Voice API Error: #{e.message}"
      { success: false, error: "Voice generation failed" }
    end
  end

  def call_railway_speech_api(audio_file)
    begin
      # Upload audio file to Railway backend
      form_data = {
        audio: Faraday::UploadIO.new(audio_file.tempfile, audio_file.content_type, audio_file.original_filename)
      }
      
      response = RestClient.post(
        "#{ENV['RAILWAY_BACKEND_URL']}/api/voice/speech-to-text",
        form_data,
        {
          'Authorization' => "Bearer #{ENV['RAILWAY_API_KEY']}"
        }
      )
      
      JSON.parse(response.body)
    rescue => e
      Rails.logger.error "Railway Speech API Error: #{e.message}"
      { success: false, error: "Speech-to-text failed" }
    end
  end

  def call_railway_voices_api
    begin
      response = RestClient.get(
        "#{ENV['RAILWAY_BACKEND_URL']}/api/voice/voices",
        {
          'Authorization' => "Bearer #{ENV['RAILWAY_API_KEY']}"
        }
      )
      
      JSON.parse(response.body)
    rescue => e
      Rails.logger.error "Railway Voices API Error: #{e.message}"
      { success: false, voices: [], error: "Failed to fetch voices" }
    end
  end
end