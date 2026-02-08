class Api::V1::VoiceController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_default_headers

  def transcribe
    # Handle wake word detection via OpenAI Whisper
    audio = params[:audio]
    detect_wake_word = params[:detect_wake_word] == 'true'
    wake_phrase = params[:wake_phrase] || 'hey autopilot'

    if audio.blank?
      render json: { error: 'Audio file is required' }, status: :bad_request
      return
    end

    begin
      # Read audio file
      audio_content = audio.read

      # Call OpenAI Whisper API
      require 'openai'
      client = OpenAI::Client.new(
        api_key: ENV.fetch('OPENAI_API_KEY')
      )

      response = client.audio.transcriptions(
        model: 'whisper-1',
        audio: audio_content,
        language: 'en',
        prompt: "You are transcribing voice commands for a social media AI assistant. Wake phrase is \"#{wake_phrase}\"."
      )

      transcribed_text = response['text']&.strip&.downcase || ''

      # Check for wake word if requested
      wake_word_detected = false
      if detect_wake_word
        wake_word_detected = check_wake_word(transcribed_text, wake_phrase)
      end

      render json: {
        text: response['text'],
        wake_word_detected: wake_word_detected,
        wake_phrase: wake_phrase,
        detected_at: Time.current.iso8601
      }

    rescue OpenAI::Error => e
      Rails.logger.error "OpenAI Whisper API error: #{e.message}"
      render json: { error: 'Transcription service error' }, status: :service_unavailable
    rescue StandardError => e
      Rails.logger.error "Transcription error: #{e.message}"
      render json: { error: 'Failed to transcribe audio' }, status: :internal_server_error
    end
  end

  private

  def check_wake_word(text, wake_phrase)
    wake_phrase_lower = wake_phrase.downcase
    
    # Direct match
    return true if text.include?(wake_phrase_lower)
    
    # Check variations
    variations = [
      wake_phrase_lower.gsub(/\s+/, ''),
      "hey #{wake_phrase_lower.gsub('hey ', '')}",
      "okay #{wake_phrase_lower}",
      "ok #{wake_phrase_lower}"
    ]
    
    variations.any? { |v| text.include?(v) }
  end

  def set_default_headers
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
  end
end