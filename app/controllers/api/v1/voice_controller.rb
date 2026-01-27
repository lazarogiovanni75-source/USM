class Api::V1::VoiceController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_default_headers

  def generate
    text = params[:text]
    voice = params[:voice] || 'pNInz6obpgDQGcFmaJgB'

    if text.blank?
      render json: { error: 'Text is required' }, status: :bad_request
      return
    end

    begin
      # Call Node.js voice service
      response = HTTParty.post(
        "#{ENV['VOICE_SERVICE_URL'] || 'http://localhost:3001'}/voice/generate",
        body: { text: text, voice: voice }.to_json,
        headers: {
          'Content-Type' => 'application/json'
        },
        timeout: 60 # 60 second timeout
      )

      case response.code
      when 200
        # Return the audio stream
        send_data response.body, 
          type: 'audio/mpeg',
          filename: "voice_#{Time.current.to_i}.mp3",
          disposition: 'inline'
      when 400
        render json: JSON.parse(response.body), status: :bad_request
      when 401
        render json: { error: 'Voice service authentication failed' }, status: :unauthorized
      when 422
        render json: { error: 'Invalid voice parameters' }, status: :unprocessable_entity
      when 500
        render json: { error: 'Voice service error' }, status: :internal_server_error
      else
        render json: { error: 'Voice service unavailable' }, status: :service_unavailable
      end

    rescue Net::OpenTimeout, Net::ReadTimeout
      render json: { error: 'Voice service timeout' }, status: :gateway_timeout
    rescue StandardError => e
      Rails.logger.error "Voice service error: #{e.message}"
      render json: { error: 'Voice service connection failed' }, status: :service_unavailable
    end
  end

  def voices
    begin
      response = HTTParty.get(
        "#{ENV['VOICE_SERVICE_URL'] || 'http://localhost:3001'}/voices",
        timeout: 30
      )

      if response.success?
        render json: response.body, status: :ok
      else
        render json: { error: 'Failed to fetch voices' }, status: :service_unavailable
      end

    rescue StandardError => e
      Rails.logger.error "Voice service error: #{e.message}"
      render json: { error: 'Voice service connection failed' }, status: :service_unavailable
    end
  end

  def health
    render json: { status: 'ok', service: 'voice_api' }, status: :ok
  end

  private

  def set_default_headers
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
  end
end