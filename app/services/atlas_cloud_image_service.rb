# frozen_string_literal: true

# Atlas Cloud Image Generation Service
# Model: z-image/turbo
# API Documentation: https://api.atlascloud.ai
class AtlasCloudImageService
  BASE_URL = 'https://api.atlascloud.ai'
  DEFAULT_MODEL = 'z-image/turbo'
  TIMEOUT = 120

  class Error < StandardError; end
  class AuthenticationError < Error; end
  class GenerationError < Error; end

  def initialize(api_key = nil)
    @api_key = api_key || fetch_api_key
    @base_url = BASE_URL
  end

  # Generate image using z-image/turbo via Atlas Cloud
  #
  # @param prompt [String] Text prompt describing the image
  # @param size [String] Image size (1:1, 16:9, 9:16, etc.)
  # @param quality [String] Quality - 'high' maps to default
  # @param n [Integer] Number of images to generate
  #
  def generate_gpt_image(prompt:,
                        size: '1:1',
                        quality: 'high',
                        n: 1)
    size_value = map_size(size)

    body = {
      model: DEFAULT_MODEL,
      input: {
        prompt: prompt,
        size: size_value,
        n: n
      }
    }

    result = post_request('/api/generate/submit', body)
    
    # Extract task_id from response
    task_id = result.dig('data', 'task_id') || result['task_id']
    
    if task_id.present?
      Rails.logger.info "[AtlasCloudImageService] Image generation started, task_id: #{task_id}"
      { 'task_id' => task_id, 'output' => nil, 'status' => 'not_started' }
    else
      Rails.logger.error "[AtlasCloudImageService] No task_id in response: #{result.inspect}"
      { 'task_id' => nil, 'output' => nil, 'error' => result['message'] || 'Failed to start generation' }
    end
  end

  # Get image task status
  def image_status(task_id)
    result = get_request("/api/generate/status/#{task_id}")
    
    Rails.logger.info "[AtlasCloudImageService] Task status response: #{result.inspect}"
    
    # Handle response - API wraps everything in 'data' key
    response_data = result
    response_data = result['data'] if result.is_a?(Hash) && result['data'].present?
    
    # Parse status from response
    status = response_data['status'] || 'unknown'
    
    # Get output/image URL from files array
    output = nil
    if response_data['files'].present? && response_data['files'].is_a?(Array)
      image_file = response_data['files'].find { |f| f['file_type'] == 'image' } || response_data['files'].first
      output = image_file['file_url'] if image_file
    end
    
    # Fallback: try direct fields
    output ||= response_data['image_url']
    output ||= response_data['url']
    output ||= response_data['output']
    
    # Get error message if present
    error = response_data['error_message'] || response_data['error']
    
    {
      'status' => status,
      'output' => output,
      'progress' => response_data['progress'],
      'error' => error
    }
  rescue => e
    Rails.logger.error "[AtlasCloudImageService] Status check error: #{e.message}"
    { 'status' => 'error', 'output' => nil, 'error' => e.message }
  end

  # Alias for backwards compatibility
  alias_method :generate_image, :generate_gpt_image

  # Check if service is configured
  def configured?
    @api_key.present?
  end

  private

  def map_size(size)
    # Convert "1024x1024" format to "1:1" format
    case size
    when '1024x1024', '1:1', 'square'
      '1:1'
    when '1024x1536', '9:16', 'portrait'
      '9:16'
    when '1536x1024', '16:9', 'landscape'
      '16:9'
    when '1024x1792', '9:19'
      '9:19'
    else
      '1:1'
    end
  end

  def fetch_api_key
    ENV['ATLASCLOUD_API_KEY'] ||
      ENV['ATLAS_CLOUD_API_KEY']
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
    
    Rails.logger.debug "[AtlasCloudImageService] Raw response code: #{response.code}, body: #{response.body}"
    
    case response.code
    when 200..299
      if parsed.is_a?(Hash) && (parsed['error'] || parsed['message'] || parsed['status'] == 'error')
        error_msg = parsed['error'] || parsed['message'] || parsed.dig('error', 'message')
        Rails.logger.error "[AtlasCloudImageService] API returned error: #{error_msg}"
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
