class VoiceChatController < ApplicationController
  require "net/http"
  require "json"

  def index
    # Render the voice chat view
  end

  # POST /chat
  def chat
    uri = URI("https://api.openai.com/v1/chat/completions")

    response = Net::HTTP.post(
      uri,
      {
        model: "gpt-4o-mini",
        messages: [
          { role: "user", content: params[:message] }
        ]
      }.to_json,
      {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{ENV['OPENAI_API_KEY']}"
      }
    )

    # Parse and return in format expected by frontend
    openai_response = JSON.parse(response.body)
    ai_message = openai_response.dig("choices", 0, "message", "content") || ""
    
    render json: { response: ai_message }
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

    response = Net::HTTP.post(
      uri,
      {
        model: "gpt-4o-mini-tts",
        voice: voice,
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
