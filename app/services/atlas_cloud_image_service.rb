# frozen_string_literal: true

# Atlas Cloud Service for Image Generation (Flux Schnell)
# API Documentation: https://api.atlascloud.ai
class AtlasCloudImageService
  BASE_URL = 'https://api.atlascloud.ai'
  TIMEOUT = 180

  class Error < StandardError; end
  class AuthenticationError < Error; end
  class GenerationError < Error; end

  def initialize(api_key = nil)
    @api_key = api_key || fetch_api_key
    @base_url = BASE_URL
    
    if @api_key.blank?
      Rails.logger.warn "[AtlasCloudImageService] No API key configured!"
    else
      Rails.logger.info "[AtlasCloudImageService] API key configured (length: #{@api_key.length})"
    end
  end

  # Generate image from text prompt using Flux Schnell
  #
  # @param prompt [String] Text prompt describing the image to generate
  # @param size [String] Image size (e.g., "1024x1024")
  # @param quality [String] Image quality ("high" or "standard")
  # @param model [String] Model identifier
  #
  def generate_image(prompt:,
                     size: '1024x1024',
                     quality: 'high',
                     model: 'black-forest-labs/flux-schnell')
    # Parse aspect ratio from size
    aspect_ratio = parse_aspect_ratio(size)

    body = {
      model: model,
      prompt: prompt,
      aspect_ratio: aspect_ratio,
      enable_base64_output: false,
      enable_sync_mode: true,
      output_format: 'png'
    }

    Rails.logger.info "[AtlasCloudImageService] Sending image generation request..."
    Rails.logger.debug "[AtlasCloudImageService] Request body: #{body.inspect}"
    Rails.logger.debug "[AtlasCloudImageService] Request URL: #{@base_url}/api/v1/model/generateImage"

    result = post_request('/api/v1/model/generateImage', body)

    Rails.logger.debug "[AtlasCloudImageService] Response: #{result.inspect}"

    # Parse response - in sync mode, output is returned immediately in data.outputs
    prediction_id = result.dig('data', 'id')
    output_url = result.dig('data', 'outputs')&.first
    status = result.dig('data', 'status')

    if prediction_id.present?
      Rails.logger.info "[AtlasCloudImageService] Generated image prediction_id: #{prediction_id}, status: #{status}"
      # In sync mode, output_url may be present immediately
      if output_url.present?
        Rails.logger.info "[AtlasCloudImageService] Image ready immediately: #{output_url}"
        return { 'prediction_id' => prediction_id, 'output' => output_url, 'status' => status }
      else
        return { 'prediction_id' => prediction_id, 'output' => nil, 'status' => status }
      end
    else
      Rails.logger.error "[AtlasCloudImageService] No prediction_id in response: #{result.inspect}"
      return { 'prediction_id' => nil, 'output' => nil, 'error' => result['message'] || result.dig('error', 'message'), 'raw_response' => result }
    end
  end

  # Get image generation task status
  def task_status(prediction_id)
    result = get_request("/api/v1/model/prediction/#{prediction_id}")

    Rails.logger.info "[AtlasCloudImageService] Task status response: #{result.inspect}"

    # Handle response - API wraps everything in 'data' key
    response_data = result
    response_data = result['data'] if result.is_a?(Hash) && result['data'].present?

    # Parse status from response
    status = response_data['status'] || 'unknown'

    # Get output/image URL from outputs array
    output = nil
    if response_data['outputs'].present? && response_data['outputs'].is_a?(Array) && response_data['outputs'].any?
      output = response_data['outputs'].first
    end

    # Fallback: try direct fields
    output ||= response_data['image_url']
    output ||= response_data['url']
    output ||= response_data['output']

    # Get error message if present
    error = response_data['error'] || response_data['error_message']

    Rails.logger.info "[AtlasCloudImageService] Parsed status: #{status}, output: #{output ? output[0..50] : 'nil'}, error: #{error}"

    {
      'status' => status,
      'output' => output,
      'progress' => response_data['progress'],
      'error' => error
    }
  rescue AtlasCloudImageService::Error => e
    if e.message.include?('404') || e.message.include?('Not Found') || e.message.include?('not found')
      Rails.logger.warn "[AtlasCloudImageService] Task #{prediction_id} not found (404)"
      return { 'status' => 'not_found', 'output' => nil, 'error' => 'Task not found' }
    end
    raise
  end

  def configured?
    @api_key.present?
  end

  private

  def fetch_api_key
    ENV['ATLASCLOUD_IMAGE_API_KEY'] ||
      ENV['CLACKY_ATLASCLOUD_IMAGE_API_KEY'] ||
      Rails.application.config.x.atlascloud_image_api_key ||
      Rails.application.config_for(:application)['ATLASCLOUD_IMAGE_API_KEY']
  end

  def parse_aspect_ratio(size)
    case size
    when '1024x1024'
      '1:1'
    when '1024x1792', '1792x1024'
      '9:16'
    when '512x512'
      '1:1'
    when '256x256'
      '1:1'
    when '1024x768', '768x1024'
      '4:3'
    else
      '1:1'
    end
  end

  def post_request(endpoint, body)
    url = "#{@base_url}#{endpoint}"
    Rails.logger.debug "[AtlasCloudImageService] Using API key: #{@api_key ? @api_key[0..10] + '...' : 'nil'}"
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

    Rails.logger.debug "[AtlasCloudImageService] Raw response code: #{response.code}, body: #{response.body}"

    case response.code
    when 200..299
      # Check for actual errors - not "success" messages
      if parsed.is_a?(Hash)
        # Only treat as error if there's an actual error field or status is 'error'
        error_field = parsed['error'] || parsed.dig('error', 'message')
        status = parsed['status']
        message = parsed['message']
        
        # Ignore "success" messages - they're not errors
        if error_field.present? && error_field != 'success'
          Rails.logger.error "[AtlasCloudImageService] API returned error: #{error_field}"
          raise Error, "API error: #{error_field}"
        elsif status == 'error' && message != 'success'
          Rails.logger.error "[AtlasCloudImageService] API returned error status: #{message}"
          raise Error, "API error: #{message}"
        end
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
      # Check if it's a credit/token issue
      error_msg = parsed.dig('msg') || parsed.dig('error', 'message') || parsed.dig('message')
      if error_msg && (error_msg.include?('令牌') || error_msg.include?('token') || error_msg.include?('credit') || error_msg.include?('unavailable'))
        raise Error, 'Image generation service unavailable - please check your account credits or contact support'
      end
      raise Error, "Server error: #{response.code} - #{error_msg || response.body[0..200]}"
    when 400
      error_msg = parsed.dig('msg') || parsed.dig('error', 'message') || parsed.dig('message') || parsed['error']
      # Check for specific error types
      if error_msg
        if error_msg.include?('not found') || error_msg.include?('model')
          raise Error, 'Image generation model unavailable - please contact support'
        elsif error_msg.include?('invalid') || error_msg.include?('key')
          raise AuthenticationError, 'Invalid API key - please check your Atlas Cloud configuration'
        end
      end
      raise Error, "Bad request: #{error_msg || response.body[0..200]}"
    end
  rescue Error => e
    Rails.logger.error "[AtlasCloudImageService] Error details - Code: #{response.code}, Body: #{response.body}, Parsed: #{parsed.inspect}"
    raise
  end
end
