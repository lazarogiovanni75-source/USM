# frozen_string_literal: true

# Defapy Service for Sora 2 Pro - Video/Image/Voice Generation
# API Documentation: https://defapy.com/docs
class DefapyService
  BASE_URL = 'https://api.defapy.com/v1'
  TIMEOUT = 120

  class Error < StandardError; end
  class AuthenticationError < Error; end
  class GenerationError < Error; end

  def initialize(api_key = nil)
    @api_key = api_key || fetch_api_key
    @base_url = ENV.fetch('DEFAPI_BASE_URL', BASE_URL)
  end

  # Generate image from text prompt
  def generate_image(prompt:, size: '1024x1024', style: 'realistic')
    body = {
      model: 'sora-image-1',
      input: {
        prompt: prompt,
        size: size,
        style: style
      }
    }
    post_request('/generations/image', body)
  end

  # Generate video from text prompt (Sora 2 Pro)
  def generate_video(prompt:, duration: '5s', aspect_ratio: '16:9')
    body = {
      model: 'sora-2-hd',
      input: {
        prompt: prompt,
        duration: duration,
        aspect_ratio: aspect_ratio
      }
    }
    post_request('/generations/video', body)
  end

  # Generate voice from text (Text-to-Speech)
  def generate_voice(text:, voice: 'en_us_male_1', speed: 1.0, pitch: 1.0)
    body = {
      model: 'tts-1',
      input: {
        text: text,
        voice: voice,
        speed: speed,
        pitch: pitch
      }
    }
    post_request('/generations/voice', body)
  end

  # Get generation status
  def generation_status(generation_id)
    get_request("/generations/#{generation_id}")
  end

  # Cancel a pending generation
  def cancel_generation(generation_id)
    delete_request("/generations/#{generation_id}")
  end

  # List available voice models
  def voices
    get_request('/voices')
  end

  def configured?
    @api_key.present?
  end

  private

  attr_reader :api_key, :base_url

  def fetch_api_key
    ENV.fetch('DEFAPI_API_KEY') do
      Rails.application.config.x.defapi_api_key ||
        Rails.application.config_for(:application)['DEFAPI_API_KEY']
    end
  rescue KeyError
    Rails.logger.warn('[DefapyService] API key not configured.')
    nil
  end

  def post_request(endpoint, body)
    url = "#{base_url}#{endpoint}"
    response = HTTParty.post(url, body: body.to_json, headers: request_headers, timeout: TIMEOUT)
    handle_response(response)
  end

  def get_request(endpoint)
    url = "#{base_url}#{endpoint}"
    response = HTTParty.get(url, headers: request_headers, timeout: TIMEOUT)
    handle_response(response)
  end

  def delete_request(endpoint)
    url = "#{base_url}#{endpoint}"
    response = HTTParty.delete(url, headers: request_headers, timeout: TIMEOUT)
    handle_response(response)
  end

  def request_headers
    {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{api_key}",
      'User-Agent' => 'UltimateSocialMedia/1.0'
    }
  end

  def handle_response(response)
    case response.code
    when 200..299
      response.parsed_response
    when 401
      raise AuthenticationError, 'Invalid API key'
    when 429
      raise Error, 'Rate limit exceeded'
    when 500..599
      raise Error, "Server error: #{response.code}"
    else
      raise Error, "Unexpected response: #{response.code}"
    end
  end
end
