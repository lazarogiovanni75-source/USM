class VoiceController < ApplicationController
  before_action :authenticate_user!

  def generate_voice
    text = params[:text]
    voice_id = params[:voice_id] || 'pNInz6obpgDQGcFmaJgB'
    tone = params[:tone] || 'neutral'
    speed = params[:speed] || 1.0

    @response = call_railway_voice_api(text, voice_id, tone, speed)
  end

  def speech_to_text
    audio_file = params[:audio_file]
    @response = call_railway_speech_api(audio_file)
  end

  def get_voices
    @response = call_railway_voices_api()
  end

  def save_voice_settings
    user_voice_setting = current_user.voice_settings.find_or_initialize_by(
      voice_id: params[:voice_id]
    )
    
    update_params = {
      tone: params[:tone],
      speed: params[:speed]
    }
    
    # Handle tts_enabled if provided and column exists
    if params.key?(:tts_enabled) && user_voice_setting.respond_to?(:tts_enabled=)
      update_params[:tts_enabled] = (params[:tts_enabled] == 'true' || params[:tts_enabled] == true)
    end
    
    # Handle language if provided and column exists
    if params.key?(:language) && user_voice_setting.respond_to?(:language=)
      update_params[:language] = params[:language]
    end
    
    # Handle enabled if provided
    update_params[:enabled] = (params[:enabled] == 'true' || params[:enabled] == true) if params.key?(:enabled)
    
    if user_voice_setting.update(update_params)
      flash[:notice] = "Voice settings saved"
    else
      flash[:alert] = user_voice_setting.errors.full_messages.join(', ')
    end
    redirect_to voice_settings_path
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