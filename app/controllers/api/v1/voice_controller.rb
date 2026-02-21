class Api::V1::VoiceController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_default_headers

  # Simple text-based voice response (for browser speech recognition)
  def chat
    text = params[:text]
    stream_name = params[:stream_name] || "voice_chat_#{current_user&.id || 'anon'}"

    if text.blank?
      render json: { error: 'Text is required' }, status: :bad_request
      return
    end

    begin
      # Generate AI response
      api_key = ENV['OPENAI_API_KEY'] || ENV['CLACKY_OPENAI_API_KEY'] || Figaro.env.openai_api_key || Rails.application.config.x.openai_api_key
      llm_model = Rails.application.config_for(:application)['LLM_MODEL'] || 'gpt-4o-mini'

      system_prompt = <<~PROMPT
        You are a helpful AI voice assistant for a marketing platform.
        Keep responses friendly, concise (1-3 sentences), and conversational.
        Help with: marketing campaigns, social media content, scheduling, performance analysis.
      PROMPT

      uri = URI.parse('https://api.openai.com/v1/chat/completions')
      body = {
        model: llm_model,
        messages: [
          { role: "system", content: system_prompt.strip },
          { role: "user", content: text }
        ],
        max_tokens: 300,
        temperature: 0.7
      }.to_json

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 15
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri.path)
      request['Authorization'] = "Bearer #{api_key}"
      request['Content-Type'] = 'application/json'
      request.body = body

      response = http.request(request)

      if response.is_a?(Net::HTTPSuccess)
        result = JSON.parse(response.body)
        ai_response = result.dig('choices', 0, 'message', 'content')
        render json: { response: ai_response }
      else
        render json: { error: "AI error: #{response.code}" }, status: :bad_request
      end
    rescue => e
      Rails.logger.error "Voice chat error: #{e.message}"
      render json: { error: e.message }, status: :internal_server_error
    end
  end

  def transcribe
    audio = params[:audio]
    detect_wake_word = params[:detect_wake_word] == 'true'
    wake_phrase = params[:wake_phrase] || 'hey Otto'

    if audio.blank?
      render json: { error: 'Audio file is required' }, status: :bad_request
      return
    end

    begin
      if audio.respond_to?(:tempfile)
        audio_content = audio.tempfile.read
        original_filename = audio.original_filename || 'audio.webm'
        content_type = audio.content_type || 'audio/webm'
      elsif audio.respond_to?(:read)
        audio_content = audio.read
        original_filename = 'audio.webm'
        content_type = 'audio/webm'
      else
        audio_content = audio
        original_filename = 'audio.webm'
        content_type = 'audio/webm'
      end

      Rails.logger.info "Audio content size: #{audio_content.bytesize}, content_type: #{content_type}"

      header_bytes = audio_content[0..19].bytes
      header_hex = header_bytes.map { |b| '%02x' % b }.join(' ')
      Rails.logger.info "Audio header bytes: #{header_hex}"

      processed_audio = process_audio(audio_content)
      unless processed_audio[:success]
        render json: { error: processed_audio[:error] }, status: :bad_request
        return
      end

      require 'net/http'
      require 'uri'

      api_key = ENV['OPENAI_API_KEY'] || ENV['CLACKY_OPENAI_API_KEY'] || Figaro.env.openai_api_key || Rails.application.config.x.openai_api_key
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

      body << "--#{boundary}\r\n"
      body << "Content-Disposition: form-data; name=\"language\"\r\n"
      body << "\r\n"
      body << "en\r\n"

      body << "--#{boundary}--\r\n"

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 30
      http.read_timeout = 60

      request = Net::HTTP::Post.new(uri.path)
      request['Authorization'] = "Bearer #{api_key}"
      request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
      request.body = body

      Rails.logger.info "Sending request to OpenAI..."
      response = http.request(request)

      Rails.logger.info "OpenAI response status: #{response.code}"

      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.error "OpenAI API error: #{response.code} - #{response.body}"
        render json: { error: "OpenAI API returned #{response.code}: #{extract_error_message(response.body)}" }, status: :bad_request
        return
      end

      result = JSON.parse(response.body)
      Rails.logger.info "OpenAI response: #{result.inspect}"

      transcribed_text = result['text'] || ''
      Rails.logger.info "Transcribed text extracted: '#{transcribed_text}'"

      # Wake word detection
      wake_word_detected = false
      if detect_wake_word
        wake_word_detected = check_wake_word(transcribed_text, wake_phrase)
        Rails.logger.info "Wake word detected: #{wake_word_detected}"
      end

      # Generate AI response based on transcribed text using ConversationOrchestrator
      if transcribed_text.present? && current_user.present?
        # Use ConversationOrchestrator for unified conversation flow
        conversation_id = params[:conversation_id]
        stream_channel = "ai_chat_#{current_user.id}_#{conversation_id || 'new'}"
        
        result = ConversationOrchestrator.process_message(
          user: current_user,
          conversation_id: conversation_id,
          content: transcribed_text,
          modality: 'voice',
          stream_channel: stream_channel
        )
        
        ai_response = result[:response]
        Rails.logger.info "AI response generated: '#{ai_response}'"
        
        # Wake word detection also triggers a response
        if wake_word_detected
          ai_response = "🎯 Wake word detected! #{ai_response}"
        end
      elsif transcribed_text.present?
        # Fallback for non-authenticated requests
        ai_response = generate_ai_response(transcribed_text)
        Rails.logger.info "AI response generated (fallback): '#{ai_response}'"
        
        if wake_word_detected
          ai_response = "🎯 Wake word detected! #{ai_response}"
        end
      else
        ai_response = nil
        Rails.logger.info "Empty transcribed text"
      end

      response_data = {
        text: transcribed_text,
        ai_response: ai_response,
        wake_word_detected: wake_word_detected,
        wake_phrase: wake_phrase,
        detected_at: Time.current.iso8601
      }
      Rails.logger.info "Final response: #{response_data.inspect}"

      render json: response_data

    rescue StandardError => e
      Rails.logger.error "Transcription error: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
      render json: { error: "Failed to transcribe audio: #{e.message}" }, status: :internal_server_error
    end
  end

  private

  def process_audio(audio_content)
    return { success: true, data: audio_content, filename: 'audio.webm', content_type: 'audio/webm' } if audio_content.bytesize < 8

    header_bytes = audio_content[0..7].bytes
    header_hex = header_bytes.map { |b| '%02x' % b }.join(' ')
    Rails.logger.info "Audio header bytes: #{header_hex}"

    if valid_wav_header?(header_bytes)
      Rails.logger.info "Standard WAV header detected, sending directly"
      return { success: true, data: audio_content, filename: 'audio.wav', content_type: 'audio/wav' }
    end

    if valid_webm_header?(header_bytes)
      Rails.logger.info "Standard WebM header detected, sending directly"
      return { success: true, data: audio_content, filename: 'audio.webm', content_type: 'audio/webm' }
    end

    if valid_ogg_header?(header_bytes)
      Rails.logger.info "OGG audio detected, sending directly"
      return { success: true, data: audio_content, filename: 'audio.ogg', content_type: 'audio/ogg' }
    end

    # Check for malformed headers that start with common audio patterns
    if audio_content.start_with?('RIFF'.b) || audio_content.start_with?("\x52\x49\x46\x46")
      Rails.logger.info "WAV-like header detected, sending as WAV"
      return { success: true, data: audio_content, filename: 'audio.wav', content_type: 'audio/wav' }
    end

    Rails.logger.info "Unknown format detected, sending as raw audio"
    { success: true, data: audio_content, filename: 'audio.wav', content_type: 'audio/wav' }
  end

  def valid_wav_header?(bytes)
    return false if bytes.length < 4
    # WAV files start with "RIFF"
    riff = [0x52, 0x49, 0x46, 0x46]
    bytes[0..3] == riff
  end

  def valid_webm_header?(bytes)
    return false if bytes.length < 4
    ebml_magic = [0x1A, 0x45, 0xDF, 0xA3]
    bytes[0..3] == ebml_magic
  end

  def valid_ogg_header?(bytes)
    return false if bytes.length < 4
    ogg_magic = [0x4F, 0x67, 0x67, 0x53]
    bytes[0..3] == ogg_magic
  end

  def extract_error_message(response_body)
    begin
      JSON.parse(response_body)['error']&.[]('message') || response_body
    rescue StandardError
      response_body
    end
  end

  def check_wake_word(text, wake_phrase)
    wake_phrase_lower = wake_phrase.downcase
    return true if text.downcase.include?(wake_phrase_lower)
    false
  end

  def generate_ai_response(text)
    # Use OpenAI to generate intelligent, contextual responses
    api_key = ENV['OPENAI_API_KEY'] || ENV['CLACKY_OPENAI_API_KEY'] || Figaro.env.openai_api_key || Rails.application.config.x.openai_api_key
    # Use configured LLM model (default: gpt-4o-mini)
    llm_model = Rails.application.config_for(:application)['LLM_MODEL'] || 'gpt-4o-mini'
    uri = URI.parse('https://api.openai.com/v1/chat/completions')

    system_prompt = <<~PROMPT
      You are a helpful AI voice assistant for a marketing platform called Otto.
      Your role is to:
      1. Listen to what the user says
      2. Understand their intent naturally
      3. Respond in a friendly, conversational way
      4. Help them with marketing tasks like:
         - Creating marketing campaigns
         - Generating social media content
         - Scheduling posts
         - Analyzing performance
         - Answering marketing questions
      
      Keep responses concise but helpful (1-3 sentences max for simple queries,
      2-4 sentences for detailed responses). Use emojis sparingly.
      Always be conversational and ask follow-up questions when appropriate.
    PROMPT

    body = {
      model: llm_model,
      messages: [
        { role: "system", content: system_prompt.strip },
        { role: "user", content: "User said: \"#{text}\". Respond helpfully." }
      ],
      max_tokens: 200,
      temperature: 0.7
    }.to_json

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 15
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri.path)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'
    request.body = body

    Rails.logger.info "Calling OpenAI for voice response..."
    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "OpenAI response error: #{response.code} - #{response.body}"
      return nil
    end

    result = JSON.parse(response.body)
    ai_text = result.dig('choices', 0, 'message', 'content')

    Rails.logger.info "OpenAI response: #{ai_text}"
    ai_text
  rescue StandardError => e
    Rails.logger.error "OpenAI error: #{e.message}"
    return nil
  end

  def set_default_headers
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'POST, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
  end
end
