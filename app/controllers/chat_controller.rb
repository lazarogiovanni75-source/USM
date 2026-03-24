class ChatController < ApplicationController
  # API namespace - exempt from Turbo Stream architecture
  # These endpoints return binary audio data (speak) or JSON (chat, transcribe)
  require "net/http"
  require "json"

  def create
    # Use Agent::Orchestrator for intelligent agentic AI chat
    begin
      orchestrator = Agent::Orchestrator.new(
        user: current_user,
        max_iterations: 5
      )
      
      response_text = orchestrator.run(params[:message])
      
      # Return in OpenAI-compatible format for frontend compatibility
      render json: {
        choices: [
          {
            message: {
              role: 'assistant',
              content: response_text
            },
            finish_reason: 'stop'
          }
        ]
      }
    rescue => e
      Rails.logger.error "Agent::Orchestrator chat error: #{e.message}"
      render json: {
        error: {
          message: e.message,
          type: 'agent_error'
        }
      }, status: 500
    end
  end

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

  def speak
    uri = URI("https://api.openai.com/v1/audio/speech")

    response = Net::HTTP.post(
      uri,
      {
        model: "gpt-4o-mini-tts",
        voice: "alloy",
        input: params[:text]
      }.to_json,
      {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{ENV['OPENAI_API_KEY']}"
      }
    )

    send_data response.body, type: "audio/mpeg", disposition: "inline"
  end
end
