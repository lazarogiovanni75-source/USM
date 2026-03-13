# frozen_string_literal: true

# Atlas Cloud Service for Video Generation
# API Documentation: https://api.atlascloud.ai
# Model: bytedance/seedance-v1-pro-fast/text-to-video
class AtlasCloudService
  BASE_URL = 'https://api.atlascloud.ai'
  TIMEOUT = 120

  class Error < StandardError; end
  class AuthenticationError < Error; end
  class GenerationError < Error; end

  def initialize(api_key = nil)
    @api_key = api_key || fetch_api_key
    @base_url = BASE_URL
  end

  # Generate video from text prompt
  # API Documentation: https://api.atlascloud.ai
  #
  # @param prompt [String] Text prompt describing the video to generate
  # @param duration [Integer] Video duration (2-12 seconds)
  # @param aspect_ratio [String] Aspect ratio ("16:9" default or "9:16" for vertical)
  # @param model [String] Model identifier (default: bytedance/seedance-v1-pro-fast/text-to-video)
  # @param resolution [String] Resolution ("480p", "720p", "1080p")
  #
  def generate_video(prompt:,
                     duration: 5,
                     aspect_ratio: '16:9',
                     model: nil,
                     resolution: '720p')
    # Validate duration (must be 2-12)
    duration_value = duration.to_i
    duration_value = 5 unless (2..12).include?(duration_value)

    # Build input payload with correct format
    body = {
      model: model || 'bytedance/seedance-v1-pro-fast/text-to-video',
      prompt: prompt,
      duration: duration_value,
      aspect_ratio: aspect_ratio,
      resolution: resolution
    }

    Rails.logger.debug "[AtlasCloudService] Sending request with body: #{body.inspect}"
    
    result = post_request('/api/v1/model/generateVideo', body)
    
    Rails.logger.debug "[AtlasCloudService] Response: #{result.inspect}"

    # Parse response - task ID is in result['data']['id']
    response_data = result.dig('data')
    task_id = response_data&.dig('id')
    
    if task_id.present?
      Rails.logger.info "[AtlasCloudService] Generated video task_id: #{task_id}"
      return { 'task_id' => task_id, 'output' => nil }
    else
      Rails.logger.error "[AtlasCloudService] No task_id in response: #{result.inspect}"
      return { 'task_id' => nil, 'output' => nil, 'error' => result.dig('message') || result.dig('error', 'message'), 'raw_response' => result }
    end
  end

  # Get generation task status
  def task_status(task_id)
    result = get_request("/api/v1/model/prediction/#{task_id}")
    
    Rails.logger.info "[AtlasCloudService] Task status response: #{result.inspect}"
    
    # Handle response - API wraps everything in 'data' key
    response_data = result.dig('data')
    return { 'status' => 'unknown', 'output' => nil, 'error' => 'No response data' } unless response_data
    
    # Parse status from response
    status = response_data['status'] || 'unknown'
    
    # Get output/video URL from outputs array
    output = nil
    if response_data['outputs'].present? && response_data['outputs'].is_a?(Array) && response_data['outputs'].any?
      output = response_data['outputs'].first
    end
    
    # Get error message if present
    error = response_data['error']
    
    Rails.logger.info "[AtlasCloudService] Parsed status: #{status}, output: #{output ? output[0..50] : 'nil'}, error: #{error}"
    
    {
      'status' => status,
      'output' => output,
      'progress' => nil,
      'error' => error
    }
  rescue AtlasCloudService::Error => e
    # If 404, return not_found so polling continues
    if e.message.include?('404') || e.message.include?('Not Found') || e.message.include?('task not found')
      Rails.logger.warn "[AtlasCloudService] Task #{task_id} not found (404)"
      return { 'status' => 'not_found', 'output' => nil, 'error' => 'Task not found' }
    end
    raise
  end

  # Get user credit balance
  def credit_balance
    # Atlas Cloud may have different endpoint for user info
    nil
  end

  def configured?
    @api_key.present?
  end

  private

  def fetch_api_key
    # Video generation should use the main ATLASCLOUD_API_KEY
    ENV['ATLASCLOUD_API_KEY'] ||
      ENV['CLACKY_ATLASCLOUD_API_KEY'] ||
      ENV['ATLAS_CLOUD_API_KEY'] ||
      ENV['CLACKY_ATLAS_CLOUD_API_KEY'] ||
      Rails.application.config.x.atlas_cloud_api_key ||
      Rails.application.config_for(:application)['ATLASCLOUD_API_KEY'] ||
      Rails.application.config_for(:application)['ATLAS_CLOUD_API_KEY'] ||
      # Fallback to image-to-video key if main key not available
      ENV['ATLASCLOUD_IMAGE_TO_VIDEO_API_KEY'] ||
      ENV['CLACKY_ATLASCLOUD_IMAGE_TO_VIDEO_API_KEY'] ||
      ENV['ATLAS_CLOUD_IMAGE_TO_VIDEO_API_KEY'] ||
      ENV['CLACKY_ATLAS_CLOUD_IMAGE_TO_VIDEO_API_KEY'] ||
      Rails.application.config_for(:application)['ATLASCLOUD_IMAGE_TO_VIDEO_API_KEY'] ||
      Rails.application.config_for(:application)['ATLAS_CLOUD_IMAGE_TO_VIDEO_API_KEY']
  end

  def post_request(endpoint, body)
    url = "#{@base_url}#{endpoint}"
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
      'x-api-key' => @api_key,
      'User-Agent' => 'UltimateSocialMedia/1.0'
    }
  end

  def handle_response(response)
    parsed = response.parsed_response
    
    Rails.logger.debug "[AtlasCloudService] Raw response code: #{response.code}, body: #{response.body}"
    
    case response.code
    when 200..299
      # Check if response indicates an error even with 200 status
      # Note: message can be empty string "" which is truthy, so use present? check
      error_msg = parsed['error'] || (parsed['message'].presence) || (parsed['status'] == 'error' ? 'Status error' : nil)
      if error_msg
        Rails.logger.error "[AtlasCloudService] API returned error: #{error_msg}"
        raise Error, "API error: #{error_msg}"
      end
      parsed
    when 401
      raise AuthenticationError, 'Invalid API key - please check your Atlas Cloud API key configuration'
    when 402
      error_msg = parsed.dig('error', 'message') || 'Insufficient credits - please top up your Atlas Cloud account'
      raise Error, error_msg
    when 429
      raise Error, 'Rate limit exceeded - please try again later'
    when 500..599
      raise Error, "Server error: #{response.code}"
    else
      raise Error, "Unexpected response: #{response.code} - #{response.body}"
    end
  end
end
