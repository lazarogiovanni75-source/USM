# frozen_string_literal: true

# VoicePipelineService - Unified voice processing pipeline
# Handles both Speech-to-Text (Whisper) and Text-to-Speech (OpenAI TTS)
#
# Usage:
#   pipeline = VoicePipelineService.new(user: current_user)
#   
#   # Transcribe audio
#   result = pipeline.transcribe(audio_data)
#   # => { success: true, text: "Hello world" }
#
#   # Synthesize speech
#   audio_url = pipeline.synthesize("Hello, how can I help you?")
#   # => "https://..."
#
#   # Full pipeline: voice input -> AI -> voice output
#   response = pipeline.process_voice_input(audio_data)
#   # => { text: "transcribed", audio_url: "https://...", response: "AI response" }
class VoicePipelineService
  class Error < StandardError; end
  class TranscriptionError < Error; end
  class SynthesisError < Error; end

  # Available OpenAI TTS voices
  VOICES = %w[alloy echo fable onyx nova shimmer].freeze

  # Available OpenAI TTS models
  MODELS = %w[tts-1 tts-1-hd].freeze

  def initialize(user: nil)
    @user = user
    @openai_api_key = fetch_api_key(:openai)
  end

  # ==================== Speech-to-Text (Whisper) ====================

  # Transcribe audio using OpenAI Whisper
  # @param audio_data [String/IO] Raw audio data or file
  # @param options [Hash] Options like :language, :prompt
  # @return [Hash] { success: bool, text: string, error: string }
  def transcribe(audio_data, options = {})
    language = options[:language] || 'en'
    prompt = options[:prompt] || ''

    Rails.logger.info "[VoicePipeline] Transcribing audio (language: #{language})"

    begin
      response = call_whisper_api(audio_data, language: language, prompt: prompt)
      
      if response.success?
        result = JSON.parse(response.body)
        text = result['text'] || ''
        Rails.logger.info "[VoicePipeline] Transcription successful: #{text[0..50]}..."
        
        { success: true, text: text }
      else
        Rails.logger.error "[VoicePipeline] Whisper API error: #{response.code} - #{response.body}"
        { success: false, error: "Transcription failed: #{response.code}" }
      end
    rescue => e
      Rails.logger.error "[VoicePipeline] Transcription error: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # ==================== Text-to-Speech (OpenAI TTS) ====================

  # Synthesize speech using OpenAI TTS
  # @param text [String] Text to synthesize
  # @param options [Hash] Options like :voice, :model, :speed
  # @return [Hash] { success: bool, audio_url: string, error: string }
  def synthesize(text, options = {})
    voice = options[:voice] || 'alloy'
    model = options[:model] || 'tts-1-hd'  # Use HD model for better quality
    speed = options[:speed] || 1.0

    Rails.logger.info "[VoicePipeline] Synthesizing with OpenAI (voice: #{voice}, model: #{model})"

    begin
      response = call_openai_tts_api(text, voice: voice, model: model, speed: speed)

      if response.success?
        audio_url = save_audio_response(response.body, 'audio/mpeg')
        Rails.logger.info "[VoicePipeline] OpenAI TTS successful: #{audio_url}"
        
        { success: true, audio_url: audio_url }
      else
        Rails.logger.error "[VoicePipeline] OpenAI TTS error: #{response.code}"
        { success: false, error: "OpenAI TTS failed: #{response.code}" }
      end
    rescue => e
      Rails.logger.error "[VoicePipeline] OpenAI TTS error: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # ==================== Full Pipeline ====================

  # Process complete voice interaction
  # 1. Transcribe audio input
  # 2. Generate AI response
  # 3. Synthesize speech output
  # 
  # @param audio_data [String/IO] Raw audio from user
  # @param ai_prompt [String] Prompt to send to AI (if nil, uses default)
  # @param options [Hash] Additional options
  # @return [Hash] { text:, audio_url:, response: }
  def process_voice_input(audio_data, ai_prompt = nil, options = {})
    # Step 1: Transcribe
    transcription = transcribe(audio_data)
    return { success: false, error: transcription[:error] } unless transcription[:success]

    text = transcription[:text]
    Rails.logger.info "[VoicePipeline] User said: #{text}"

    # Step 2: Generate AI response
    ai_response = generate_ai_response(text, ai_prompt || default_ai_prompt)
    Rails.logger.info "[VoicePipeline] AI response: #{ai_response[0..100]}..."

    # Step 3: Synthesize response (optional - can be disabled)
    synthesize_speech = options[:synthesize] != false
    
    if synthesize_speech
      audio_result = synthesize(ai_response, voice: options[:voice])
      return { success: false, error: audio_result[:error] } unless audio_result[:success]

      {
        success: true,
        text: text,
        ai_response: ai_response,
        audio_url: audio_result[:audio_url]
      }
    else
      {
        success: true,
        text: text,
        ai_response: ai_response,
        audio_url: nil
      }
    end
  end

  # ==================== Configuration ====================

  # Get available TTS voices
  def available_voices
    VOICES
  end

  # Get available TTS models
  def available_models
    MODELS
  end

  # Get user's preferred voice settings
  def user_voice_settings
    return @user_voice_settings if @user_voice_settings

    if @user&.voice_settings&.any?
      settings = @user.voice_settings.first
      @user_voice_settings = {
        voice: settings.voice || 'alloy',
        voice_name: settings.name || 'Default',
        language: settings.language || 'en',
        model: settings.model || 'gpt-4o-mini-tts',
        speed: settings.speed || 1.0
      }
    else
      @user_voice_settings = default_voice_settings
    end
  end

  # Check if TTS is configured
  def tts_configured?
    @openai_api_key.present?
  end

  # Check if STT (Whisper) is configured
  def stt_configured?
    @openai_api_key.present?
  end

  private

  # API Keys
  def fetch_api_key(service)
    case service
    when :openai
      ENV['ANTHROPIC_API_KEY'] || ENV['OPENAI_API_KEY'] || ENV['ULTIMATE_OPENAI_API_KEY'] || Figaro.env.openai_api_key
    end
  end

  def default_ai_prompt
    <<~PROMPT
      You are Pilot, a helpful AI voice assistant for a marketing platform.
      Keep responses conversational and concise (1-3 sentences).
      Help with: marketing campaigns, social media content, scheduling, analytics.
    PROMPT
  end

  def default_voice_settings
    {
      voice: 'alloy',
      voice_name: 'Alloy',
      language: 'en',
      model: 'tts-1-hd',
      speed: 1.0
    }
  end

  # ==================== API Calls ====================

  def whisper_api_url
    'https://api.openai.com/v1/audio/transcriptions'
  end

  def tts_api_url
    'https://api.openai.com/v1/audio/speech'
  end

  def openai_headers
    {
      'Authorization' => "Bearer #{@openai_api_key}",
      'Content-Type' => 'application/json'
    }
  end

  def multipart_headers
    {
      'Authorization' => "Bearer #{@openai_api_key}"
    }
  end

  def call_whisper_api(audio_data, language:, prompt:)
    # Prepare audio for API
    audio_io = prepare_audio(audio_data)

    # Build multipart form request
    body = {
      file: audio_io,
      model: 'whisper-1',
      language: language,
      response_format: 'json'
    }
    body[:prompt] = prompt if prompt.present?

    HTTParty.post(whisper_api_url, {
      headers: multipart_headers,
      body: body,
      timeout: 60
    })
  end

  def call_openai_tts_api(text, voice:, model:, speed:)
    body = {
      model: model,
      voice: voice,
      input: text,
      speed: speed
    }

    HTTParty.post(tts_api_url, {
      headers: openai_headers,
      body: body.to_json,
      timeout: 30
    })
  end

  # ==================== Audio Processing ====================

  def prepare_audio(audio_data)
    if audio_data.is_a?(String)
      # Assume it's a file path or base64
      if audio_data.start_with?('data:')
        # Base64 encoded
        require 'base64'
        data = audio_data.split(',', 2).last
        StringIO.new(Base64.decode64(data))
      else
        # File path
        File.open(audio_data, 'rb')
      end
    elsif audio_data.respond_to?(:read)
      # Already an IO object
      audio_data
    else
      raise TranscriptionError, "Unsupported audio data type: #{audio_data.class}"
    end
  end

  def save_audio_response(audio_body, content_type)
    # Return base64 data URL for immediate browser playback
    "data:audio/mpeg;base64,#{Base64.strict_encode64(audio_body)}"
  end

  def generate_ai_response(text, prompt)
    # This would integrate with your existing AI service
    # For now, return a simple response
    # In production, this would call GPT-4 or similar
    "I heard you say: #{text}. This is a placeholder response."
  end
end
