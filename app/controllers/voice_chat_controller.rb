class VoiceChatController < ApplicationController
  # API namespace - exempt from Turbo Stream architecture
  # These endpoints return binary audio data (speak) or JSON (chat, transcribe)
  require "net/http"
  require "json"

  def index
    # Render the voice chat view
  end

  # POST /chat
  def chat
    # Get the message from params (handles both direct params and nested voice_chat)
    message = params[:message] || params.dig(:voice_chat, :message)
    
    if message.blank?
      render json: { error: 'Message is required' }, status: :bad_request
      return
    end

    # Use ConversationOrchestrator for full AI capabilities including image generation
    if current_user
      begin
        stream_channel = "voice_chat_#{current_user.id}"
        
        result = ConversationOrchestrator.process_message(
          user: current_user,
          conversation_id: nil,
          content: message,
          modality: 'voice',
          stream_channel: stream_channel
        )
        
        ai_response = result[:response]
        
        render json: { 
          response: ai_response,
          message: ai_response
        }
      rescue => e
        Rails.logger.error "VoiceChatController error: #{e.message}"
        render json: { error: "Failed to process message: #{e.message}" }, status: :internal_server_error
      end
    else
      # Fallback for non-authenticated users - use basic chat
      basic_chat_response(message)
    end
  end

  # POST /transcribe
  def transcribe
    uri = URI("https://api.openai.com/v1/audio/transcriptions")

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{ENV['OPENAI_API_KEY']}"

    form_data = [
      ['file', params[:audio].tempfile],
      ['model', 'whisper-1']
    ]

    request.set_form form_data, 'multipart/form-data'

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    render json: JSON.parse(response.body)
  end

  # POST /speak
  def speak
    uri = URI("https://api.openai.com/v1/audio/speech")

    # Get voice from params or use default (allow alloy, echo, fable, onyx, nova, shimmer)
    voice = params[:voice] || 'alloy'
    valid_voices = ['alloy', 'echo', 'fable', 'onyx', 'nova', 'shimmer']
    voice = 'alloy' unless valid_voices.include?(voice)
    
    # Get speech rate (default 1.0, range 0.25 to 4.0)
    rate = params[:rate]&.to_f || 1.0
    rate = 1.0 if rate < 0.25 || rate > 4.0

    response = Net::HTTP.post(
      uri,
      {
        model: "gpt-4o-mini-tts",
        voice: voice,
        input: params[:text],
        speed: rate
      }.to_json,
      {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{ENV['OPENAI_API_KEY']}"
      }
    )

    send_data response.body, type: "audio/mpeg", disposition: "inline"
  end

  private

  def basic_chat_response(message)
    # Use Agent::Orchestrator for intelligent agentic AI chat
    begin
      orchestrator = Agent::Orchestrator.new(
        user: current_user,
        max_iterations: 5
      )
      
      ai_message = orchestrator.run(message)
      
      render json: { response: ai_message }
    rescue => e
      Rails.logger.error "Agent::Orchestrator voice chat error: #{e.message}"
      render json: { 
        response: "I'm having trouble processing your request. Please try again.",
        error: e.message 
      }, status: 500
    end
  end
end
