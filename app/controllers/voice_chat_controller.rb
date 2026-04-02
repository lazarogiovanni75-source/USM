# frozen_string_literal: true

class VoiceChatController < ApplicationController
  # API namespace - exempt from Turbo Stream architecture
  # These endpoints return binary audio data (speak) or JSON (chat, transcribe)
  
  require "net/http"
  require "json"

  # Session storage for conversation history
  CONVERSATION_KEY = "claude_voice_conversation"

  def index
    # Render the voice chat view
  end

  # POST /chat - Send message to Claude
  def chat
    message = params[:message] || params.dig(:voice_chat, :message)
    
    if message.blank?
      render json: { error: "Message is required" }, status: :bad_request
      return
    end

    begin
      # Get or initialize conversation history
      conversation_history = get_conversation_history
      
      # Add user message to history
      conversation_history << { role: "user", content: message }
      
      # Call Claude API
      response = call_claude(conversation_history)
      
      # Add assistant response to history
      conversation_history << { role: "assistant", content: response }
      
      # Save updated conversation (limit to last 20 messages to manage token usage)
      save_conversation_history(conversation_history.last(20))
      
      render json: { response: response }
    rescue => e
      Rails.logger.error "VoiceChatController error: #{e.message}"
      render json: { error: "Failed to process message: #{e.message}" }, status: :internal_server_error
    end
  end

  # POST /transcribe - Transcribe audio using OpenAI Whisper
  def transcribe
    if params[:audio].blank?
      render json: { error: "Audio file is required" }, status: :bad_request
      return
    end

    api_key = ENV["OPENAI_API_KEY"].presence || ENV["API_KEY_OPENAI"].presence
    
    if api_key.blank?
      render json: { error: "OpenAI API key not configured" }, status: :internal_server_error
      return
    end

    uri = URI("https://api.openai.com/v1/audio/transcriptions")

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{api_key}"

    form_data = [
      ["file", params[:audio].tempfile],
      ["model", "whisper-1"]
    ]

    request.set_form form_data, "multipart/form-data"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      render json: JSON.parse(response.body)
    else
      Rails.logger.error "Whisper API error: #{response.code} - #{response.body}"
      render json: { error: "Transcription failed: #{response.code}" }, status: :internal_server_error
    end
  end

  # POST /speak - Convert text to speech using Google Cloud TTS
  def speak
    text = params[:text]
    
    if text.blank?
      head :bad_request
      return
    end

    begin
      audio_content = call_google_tts(text)
      send_data audio_content, type: "audio/mpeg", disposition: "inline"
    rescue => e
      Rails.logger.error "Google TTS error: #{e.message}"
      # Fallback to OpenAI TTS if Google Cloud is not configured
      begin
        audio_content = call_openai_tts(text)
        send_data audio_content, type: "audio/mpeg", disposition: "inline"
      rescue => fallback_error
        Rails.logger.error "OpenAI TTS fallback also failed: #{fallback_error.message}"
        head :internal_server_error
      end
    end
  end

  private

  # Get conversation history from session
  def get_conversation_history
    session[CONVERSATION_KEY] ||= []
  end

  # Save conversation history to session
  def save_conversation_history(history)
    session[CONVERSATION_KEY] = history
  end

  # Clear conversation history
  def clear_conversation
    session[CONVERSATION_KEY] = []
  end

  # Call Claude API using Anthropic
  def call_claude(messages)
    api_key = ENV["ANTHROPIC_API_KEY"]
    
    if api_key.blank?
      raise "ANTHROPIC_API_KEY is not configured"
    end

    # Build messages array (Anthropic format)
    # System prompt goes in the system parameter
    system_prompt = <<~PROMPT
      You are Claude, a helpful AI assistant. You are engaging in a conversational voice chat.
      Keep your responses conversational and concise (1-3 sentences max unless more detail is needed).
      Be friendly, helpful, and natural in your responses.
    PROMPT

    # Prepare messages for Anthropic (exclude system message if already in array)
    anthropic_messages = messages.map do |msg|
      { role: msg[:role], content: msg[:content] }
    end

    # Make API request
    uri = URI("https://api.anthropic.com/v1/messages")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 60

    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"
    request["x-api-key"] = api_key
    request["anthropic-version"] = "2023-06-01"
    request["anthropic-dangerous-direct-browser-access"] = "true"
    request.body = {
      model: ENV.fetch("ANTHROPIC_MODEL", "claude-sonnet-4-6"),
      max_tokens: 1024,
      system: system_prompt,
      messages: anthropic_messages
    }.to_json

    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      result = JSON.parse(response.body)
      result.dig("content", 0, "text") || ""
    else
      error_body = JSON.parse(response.body) rescue {}
      raise "Claude API error: #{error_body.dig('error', 'type')} - #{error_body.dig('error', 'message')}"
    end
  end

  # Call Google Cloud Text-to-Speech API (free tier)
  def call_google_tts(text)
    api_key = ENV["GOOGLE_CLOUD_TTS_API_KEY"]
    
    if api_key.blank?
      raise "GOOGLE_CLOUD_TTS_API_KEY is not configured"
    end

    uri = URI("https://texttospeech.googleapis.com/v1/text:synthesize?key=#{api_key}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"

    request.body = {
      input: { text: text },
      voice: {
        languageCode: "en-US",
        name: "en-US-Neural2-J", # Natural sounding voice
        ssmlGender: "MALE"
      },
      audioConfig: {
        audioEncoding: "MP3",
        speakingRate: 1.0, # Normal speed
        pitch: 0.0
      }
    }.to_json

    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      result = JSON.parse(response.body)
      # Decode base64 audio content
      Base64.decode64(result["audioContent"])
    else
      error_body = JSON.parse(response.body) rescue {}
      raise "Google TTS error: #{error_body.dig('error', 'message') || response.code}"
    end
  end

  # Fallback: Call OpenAI TTS if Google Cloud is not configured
  def call_openai_tts(text)
    api_key = ENV["OPENAI_API_KEY"].presence || ENV["API_KEY_OPENAI"].presence
    
    if api_key.blank?
      raise "No TTS API key configured"
    end

    uri = URI("https://api.openai.com/v1/audio/speech")

    response = Net::HTTP.post(
      uri,
      {
        model: "gpt-4o-mini-tts",
        voice: "alloy",
        input: text,
        speed: 1.0
      }.to_json,
      {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{api_key}"
      }
    )

    if response.is_a?(Net::HTTPSuccess)
      response.body
    else
      raise "OpenAI TTS error: #{response.code}"
    end
  end
end
