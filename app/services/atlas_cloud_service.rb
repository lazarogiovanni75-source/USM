# frozen_string_literal: true

# Atlas Cloud Service for Video Generation (Seedance v1 Pro)
# API Documentation: https://api.atlascloud.ai
class AtlasCloudService
  BASE_URL = 'https://api.atlascloud.ai'
  TIMEOUT = 300

  class Error < StandardError; end
  class AuthenticationError < Error; end
  class GenerationError < Error; end

  def initialize(api_key = nil)
    @api_key = api_key || fetch_api_key
    @base_url = BASE_URL
    
    if @api_key.blank?
      Rails.logger.warn "[AtlasCloudService] No API key configured!"
    else
      Rails.logger.info "[AtlasCloudService] API key configured (length: #{@api_key.length})"
    end
  end

  # Generate video from text prompt using Seedance v1 Pro
  #
  # @param prompt [String] Text prompt describing the video to generate
  # @param duration [Integer] Video duration in seconds (default: 10)
  # @param aspect_ratio [String] Aspect ratio ("16:9" or "9:16")
  # @param resolution [String] Resolution ("1080p")
  # @param camera_fixed [Boolean] Whether camera should be fixed
  # @param seed [Integer] Random seed (-1 for random)
  #
  def generate_video(prompt:,
                     duration: 10,
                     aspect_ratio: '16:9',
                     resolution: '1080p',
                     camera_fixed: false,
                     seed: -1)
    body = {
      model: 'bytedance/seedance-v1-pro-fast/text-to-video',
      prompt: prompt,
      duration: duration,
      aspect_ratio: aspect_ratio,
      resolution: resolution,
      camera_fixed: camera_fixed,
      seed: seed
    }

    Rails.logger.info "[AtlasCloudService] Sending video generation request..."
    Rails.logger.debug "[AtlasCloudService] Request body: #{body.inspect}"
    Rails.logger.debug "[AtlasCloudService] Request URL: #{@base_url}/api/v1/model/generateVideo"

    result = post_request('/api/v1/model/generateVideo', body)

    Rails.logger.debug "[AtlasCloudService] Response: #{result.inspect}"

    # Parse response - prediction_id is in data.id
    prediction_id = result.dig('data', 'id')

    if prediction_id.present?
      Rails.logger.info "[AtlasCloudService] Generated video prediction_id: #{prediction_id}"
      return { 'prediction_id' => prediction_id, 'output' => nil }
    else
      Rails.logger.error "[AtlasCloudService] No prediction_id in response: #{result.inspect}"
      return { 'prediction_id' => nil, 'output' => nil, 'error' => result['message'] || result.dig('error', 'message'), 'raw_response' => result }
    end
  end

  # Get generation task status
  def task_status(prediction_id)
    result = get_request("/api/v1/model/prediction/#{prediction_id}")

    Rails.logger.info "[AtlasCloudService] Task status response: #{result.inspect}"

    # Handle response - API wraps everything in 'data' key
    response_data = result
    response_data = result['data'] if result.is_a?(Hash) && result['data'].present?

    # Parse status from response
    status = response_data['status'] || 'unknown'

    # Get output/video URL from outputs array
    output = nil
    if response_data['outputs'].present? && response_data['outputs'].is_a?(Array) && response_data['outputs'].any?
      output = response_data['outputs'].first
    end

    # Fallback: try direct fields
    output ||= response_data['video_url']
    output ||= response_data['url']
    output ||= response_data['output']

    # Get error message if present
    error = response_data['error'] || response_data['error_message']

    Rails.logger.info "[AtlasCloudService] Parsed status: #{status}, output: #{output ? output[0..50] : 'nil'}, error: #{error}"

    {
      'status' => status,
      'output' => output,
      'progress' => response_data['progress'],
      'error' => error
    }
  rescue AtlasCloudService::Error => e
    # If 404, return not_found so polling continues
    if e.message.include?('404') || e.message.include?('Not Found') || e.message.include?('not found')
      Rails.logger.warn "[AtlasCloudService] Task #{prediction_id} not found (404)"
      return { 'status' => 'not_found', 'output' => nil, 'error' => 'Task not found' }
    end
    raise
  end

  def configured?
    @api_key.present?
  end

  private

  def fetch_api_key
    ENV['ATLASCLOUD_API_KEY'] ||
      ENV['CLACKY_ATLASCLOUD_API_KEY'] ||
      Rails.application.config.x.atlascloud_api_key ||
      Rails.application.config_for(:application)['ATLASCLOUD_API_KEY']
  end

  def post_request(endpoint, body)
    url = "#{@base_url}#{endpoint}"
    Rails.logger.debug "[AtlasCloudService] Using API key: #{@api_key ? @api_key[0..10] + '...' : 'nil'}"
    response = HTTParty.post(url, body: body.to_json, headers: request_headers, timeout: TIMEOUT)
    handle_response(response)
  end

  def get_request(endpoint)
    url = "#{@base_url}#{endpoint}"
    response = HTTParty.get(url, headers: request_headers, timeout: TIMEOUT)
    handle_response(response)
  end

  def request_headers
    {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{@api_key}",
      'User-Agent' => 'UltimateSocialMedia/1.0'
    }
  end

  def handle_response(response)
    parsed = response.parsed_response

    Rails.logger.debug "[AtlasCloudService] Raw response code: #{response.code}, body: #{response.body}"

    case response.code
    when 200..299
      # Check if response indicates an error even with 200 status
      if parsed.is_a?(Hash) && (parsed['error'] || parsed['message'] || parsed['status'] == 'error')
        error_msg = parsed['error'] || parsed['message'] || parsed.dig('error', 'message')
        Rails.logger.error "[AtlasCloudService] API returned error: #{error_msg}"
        raise Error, "API error: #{error_msg}"
      end
      parsed
    when 401
      raise AuthenticationError, 'Invalid API key - please check your Atlas Cloud API key configuration'
    when 402
      error_msg = parsed.dig('error', 'message') || 'Insufficient credits - please top up your Atlas Cloud account'
      raise Error, error_msg
    when 403
      raise AuthenticationError, "Access forbidden - #{response.body}"
    when 429
      raise Error, 'Rate limit exceeded - please try again later'
    when 500..599
      raise Error, "Server error: #{response.code} - #{response.body}"
    else
      raise Error, "Unexpected response: #{response.code} - #{response.body}"
    end
  rescue Error => e
    Rails.logger.error "[AtlasCloudService] Error details - Code: #{response.code}, Body: #{response.body}, Parsed: #{parsed.inspect}"
    raise
  end
end
