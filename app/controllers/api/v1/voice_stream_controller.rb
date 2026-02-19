# frozen_string_literal: true

class Api::V1::VoiceStreamController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_default_headers

  def health
    render json: {
      status: 'ok',
      service: 'voice_stream',
      timestamp: Time.current.iso8601
    }
  end

  def transcribe_and_stream
    audio = params[:audio]
    conversation_id = params[:conversation_id]
    detect_wake_word = params[:detect_wake_word] == 'true'
    early_trigger = params[:early_trigger] == 'true'

    if audio.blank?
      render json: { error: 'Audio file is required' }, status: :bad_request
      return
    end

    # Require user authentication for streaming chat
    if current_user.blank?
      render json: { error: 'Authentication required' }, status: :unauthorized
      return
    end

    begin
      # Process and transcribe audio
      processed_audio = process_audio(audio)
      unless processed_audio[:success]
        render json: { error: processed_audio[:error] }, status: :bad_request
        return
      end

      # Transcribe using OpenAI Whisper
      transcribed_text = transcribe_audio(processed_audio)
      if transcribed_text.blank?
        # No speech detected - return silently
        render json: { text: '', status: 'no_speech' }
        return
      end

      # Check wake word if enabled
      wake_phrase = params[:wake_phrase] || 'hey Otto'
      wake_word_detected = false
      if detect_wake_word
        wake_word_detected = transcribed_text.downcase.include?(wake_phrase.downcase)
        Rails.logger.info "Wake word detected: #{wake_word_detected}"
      end

      # Create or get conversation service
      voice_service = VoiceConversationService.new(
        user: current_user,
        conversation_id: conversation_id
      )

      # Generate streaming channel name FIRST
      stream_name = VoiceConversationService.conversation_channel(current_user.id, voice_service.conversation.id)

      # Get conversation history BEFORE adding the new message
      conversation_history = get_conversation_history(voice_service)

      # Add user message to conversation
      voice_service.add_user_message(transcribed_text)

      # Broadcast confirmation that command was received (for TTS)
      # Also broadcast to user-based channel for reliability
      ActionCable.server.broadcast(stream_name, {
        type: 'command-received',
        transcript: transcribed_text,
        message: "I heard: #{transcribed_text}. Processing your request...",
        timestamp: Time.current
      })
      
      # Also broadcast to user channel for reliability
      user_channel = "voice_chat_#{current_user.id}"
      unless user_channel == stream_name
        ActionCable.server.broadcast(user_channel, {
          type: 'command-received',
          transcript: transcribed_text,
          message: "I heard: #{transcribed_text}. Processing your request...",
          timestamp: Time.current
        })
      end

      # Build the prompt for LLM
      prompt = voice_service.build_prompt_for_llm(transcribed_text)

      # Start streaming LLM response via ActionCable
      VoiceStreamJob.perform_later(
        stream_name: stream_name,
        prompt: prompt,
        system: voice_service.system_prompt,
        conversation_id: voice_service.conversation.id,
        user_id: current_user.id,
        conversation_history: conversation_history,
        wake_word_detected: wake_word_detected,
        stream_tts: true,  # Enable TTS streaming
        enable_tools: true  # Enable tool execution for real task handling
      )

      render json: {
        text: transcribed_text,
        conversation_id: voice_service.conversation.id,
        stream_name: stream_name,
        status: 'streaming_started',
        wake_word_detected: wake_word_detected,
        early_trigger: early_trigger
      }

    rescue StandardError => e
      Rails.logger.error "Voice streaming error: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
      render json: { error: "Failed to process voice: #{e.message}" }, status: :internal_server_error
    end
  end

  private

  def process_audio(audio)
    if audio.respond_to?(:tempfile) && audio.tempfile
      # It's a file upload with tempfile - read the content
      { 
        success: true, 
        data: audio.tempfile.read, 
        filename: audio.original_filename || 'audio.webm', 
        content_type: audio.content_type || 'audio/webm' 
      }
    elsif audio.respond_to?(:read)
      # It's a file-like object - read its content
      { success: true, data: audio.read, filename: 'audio.webm', content_type: 'audio/webm' }
    else
      # It's already a string (raw audio data)
      { success: true, data: audio, filename: 'audio.webm', content_type: 'audio/webm' }
    end
  end

  def transcribe_audio(processed_audio)
    api_key = ENV.fetch('OPENAI_API_KEY')
    uri = URI.parse('https://api.openai.com/v1/audio/transcriptions')

    boundary = "----RubyMultipartBoundary#{SecureRandom.hex(16)}"

    body = +""
    body << "--#{boundary}\r\n"
    body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{processed_audio[:filename]}\"\r\n"
    body << "Content-Type: #{processed_audio[:content_type]}\r\n"
    body << "\r\n"
    body << processed_audio[:data]
    body << "\r\n"
    body << "--#{boundary}\r\n"
    body << "Content-Disposition: form-data; name=\"model\"\r\n"
    body << "\r\n"
    body << "whisper-1\r\n"
    body << "--#{boundary}--\r\n"

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 30
    http.read_timeout = 60

    request = Net::HTTP::Post.new(uri.path)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
    request.body = body

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "Whisper API error: #{response.code}"
      return nil
    end

    result = JSON.parse(response.body)
    result['text'] || ''
  rescue StandardError => e
    Rails.logger.error "Transcription error: #{e.message}"
    nil
  end

  def get_conversation_history(voice_service)
    voice_service.conversation_messages.map do |msg|
      { role: msg.role, content: msg.content }
    end
  end

  def set_default_headers
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'POST, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
  end
end
