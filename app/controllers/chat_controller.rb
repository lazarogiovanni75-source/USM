class ChatController < ApplicationController
  require "net/http"
  require "json"

  def create
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

    render json: JSON.parse(response.body)
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
