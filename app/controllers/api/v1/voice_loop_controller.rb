# frozen_string_literal: true

# API::V1::VoiceLoopController - Full voice conversation loop API
# Endpoints: transcribe, claude, speak, and full_conversation loop
class Api::V1::VoiceLoopController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_default_headers

  # Session key for conversation history
  CONVERSATION_KEY = 'voice_loop_conversation'

  # POST /api/v1/voice_loop/conversation
  # Full conversation loop: record → transcribe → Claude → TTS
  def conversation
    Rails.logger.info "VoiceLoop API: Starting conversation loop"

    # Get audio file
    audio = params[:audio]
    if audio.blank?
      render json: { error: 'Audio file is required' }, status: :bad_request
      return
    end

    # Get conversation ID from params or session
    conversation_id = params[:conversation_id] || session[CONVERSATION_KEY]

    begin
      # Read audio data
      audio_data = read_audio_data(audio)
      filename = audio.original_filename || 'audio.webm'
      content_type = audio.content_type || 'audio/webm'

      # Create service instance
      service = VoiceLoopService.new(user: current_user, conversation_id: conversation_id)

      # Full loop
      result = service.full_conversation_loop(audio_data, filename: filename, content_type: content_type)

      if result[:error]
        render json: { error: result[:error] }, status: :unprocessable_entity
        return
      end

      # Store conversation ID in session
      session[CONVERSATION_KEY] = result[:conversation_id]

      # Generate TTS audio for the response
      tts_audio = service.text_to_speech(result[:claude_response])

      # Return both text response and audio
      render json: {
        success: true,
        conversation_id: result[:conversation_id],
        transcribed_text: result[:transcribed_text],
        response: result[:claude_response],
        message_count: result[:message_count]
      }

    rescue => e
      Rails.logger.error "VoiceLoop API error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      render json: { error: e.message }, status: :internal_server_error
    end
  end

  # POST /api/v1/voice_loop/transcribe
  # Step 1: Transcribe audio using Whisper
  def transcribe
    Rails.logger.info "VoiceLoop API: Transcribing audio"

    audio = params[:audio]
    if audio.blank?
      render json: { error: 'Audio file is required' }, status: :bad_request
      return
    end

    begin
      audio_data = read_audio_data(audio)
      filename = audio.original_filename || 'audio.webm'
      content_type = audio.content_type || 'audio/webm'

      service = VoiceLoopService.new(user: current_user)
      transcribed_text = service.transcribe(audio_data, filename: filename, content_type: content_type)

      if transcribed_text.blank?
        render json: { error: 'Could not transcribe audio' }, status: :unprocessable_entity
        return
      end

      render json: {
        success: true,
        text: transcribed_text
      }

    rescue => e
      Rails.logger.error "Transcribe error: #{e.message}"
      render json: { error: e.message }, status: :internal_server_error
    end
  end

  # POST /api/v1/voice_loop/claude
  # Step 2: Send message to Claude with conversation history
  def claude
    Rails.logger.info "VoiceLoop API: Sending to Claude"

    message = params[:message] || params[:text]
    if message.blank?
      render json: { error: 'Message is required' }, status: :bad_request
      return
    end

    begin
      conversation_id = session[CONVERSATION_KEY] || params[:conversation_id]

      # Load existing conversation history from session
      history = session["#{CONVERSATION_KEY}_history"] || []
      history << { role: 'user', content: message }

      # Call Claude with history
      service = VoiceLoopService.new(user: current_user, conversation_id: conversation_id)
      service.instance_variable_set(:@conversation_history, history)

      response = service.process_with_claude(message)

      if response.blank?
        render json: { error: 'Claude failed to respond' }, status: :unprocessable_entity
        return
      end

      # Save updated history
      session["#{CONVERSATION_KEY}_history"] = service.conversation_history
      session[CONVERSATION_KEY] = conversation_id || service.conversation_id

      render json: {
        success: true,
        response: response,
        conversation_id: service.conversation_id,
        message_count: service.conversation_history.length / 2
      }

    rescue => e
      Rails.logger.error "Claude error: #{e.message}"
      render json: { error: e.message }, status: :internal_server_error
    end
  end

  # POST /api/v1/voice_loop/speak
  # Step 3: Convert text to speech using OpenAI TTS
  def speak
    Rails.logger.info "VoiceLoop API: Converting to speech"

    text = params[:text] || params[:message]
    if text.blank?
      head :bad_request
      return
    end

    begin
      service = VoiceLoopService.new(user: current_user)
      audio_data = service.text_to_speech(text)

      if audio_data.blank?
        render json: { error: 'TTS failed' }, status: :unprocessable_entity
        return
      end

      send_data audio_data, type: 'audio/mpeg', disposition: 'inline'

    rescue => e
      Rails.logger.error "TTS error: #{e.message}"
      render json: { error: e.message }, status: :internal_server_error
    end
  end

  # POST /api/v1/voice_loop/reset
  # Reset conversation history
  def reset
    Rails.logger.info "VoiceLoop API: Resetting conversation"

    session[CONVERSATION_KEY] = nil
    session["#{CONVERSATION_KEY}_history"] = nil

    render json: {
      success: true,
      message: 'Conversation reset'
    }
  end

  # GET /api/v1/voice_loop/status
  # Get current conversation state
  def status
    conversation_id = session[CONVERSATION_KEY]
    history = session["#{CONVERSATION_KEY}_history"] || []

    render json: {
      conversation_id: conversation_id,
      message_count: history.length / 2,
      has_history: history.any?
    }
  end

  private

  def read_audio_data(audio)
    if audio.respond_to?(:tempfile)
      audio.tempfile.read
    elsif audio.respond_to?(:read)
      audio.read
    else
      audio
    end
  end

  def set_default_headers
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS'
    headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
  end
end
