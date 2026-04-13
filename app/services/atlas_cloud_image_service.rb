# frozen_string_literal: true

# Atlas Cloud Image Generation Service
# Uses unified API: POST /api/v1/model/generateImage
# API Base: https://api.atlascloud.ai
# Authentication: Bearer token via ATLASCLOUD_API_KEY environment variable
class AtlasCloudImageService
  BASE_URL = 'https://api.atlascloud.ai'
  DEFAULT_MODEL = 'qwen/qwen-image-2.0/text-to-image'
  TIMEOUT = 120

  # Available image models (user selected) - organized by tier
  AVAILABLE_MODELS = {
    # Standard tier
    'qwen/qwen-image-2.0/text-to-image' => 'Qwen 2.0 Text-to-Image (Standard)',
    'z-image/turbo' => 'Z-Turbo (Standard)',
    # Premium tier
    'google/nano-banana-2/text-to-image' => 'Google Nano Banana 2 (Premium)',
    # HD tier
    'google/imagen4-ultra' => 'Google Imagen 4 Ultra (HD)'
  }.freeze

  # Image edit models
  IMAGE_EDIT_MODELS = {
    'qwen/qwen-image-2.0/edit' => 'Qwen 2.0 Image Edit',
    'alibaba/qwen-image/edit' => 'Alibaba Qwen Image Edit'
  }.freeze

  class Error < StandardError; end
  class AuthenticationError < Error; end
  class GenerationError < Error; end

  def initialize(api_key = nil)
    @api_key = api_key || fetch_api_key
    @base_url = BASE_URL
  end

  # Generate image using Atlas Cloud unified API
  #
  # @param prompt [String] Text prompt describing the image
  # @param model [String] Model ID (default: black-forest-labs/flux-1.1-pro)
  # @param aspect_ratio [String] Aspect ratio (1:1, 16:9, 9:16, 4:3, 3:4)
  # @param n [Integer] Number of images to generate
  # @param quality [String] Quality tier (standard, hd)
  # @return [Hash] { task_id:, output:, status: }
  #
  def generate_image(prompt:,
                     model: DEFAULT_MODEL,
                     aspect_ratio: '1:1',
                     n: 1,
                     quality: 'standard')
    body = {
      model: model,
      prompt: prompt,
      aspect_ratio: aspect_ratio,
      n: 1,  # Always generate exactly 1 image
      quality: quality  # Pass quality tier to API
    }

    Rails.logger.info "[AtlasCloudImageService] Generating image with model: #{model}, aspect_ratio: #{aspect_ratio}, quality: #{quality}"

    result = post_request('/api/v1/model/generateImage', body)

    task_id = extract_task_id(result)

    if task_id.present?
      Rails.logger.info "[AtlasCloudImageService] Image generation started, task_id: #{task_id}"
      { 'task_id' => task_id, 'output' => nil, 'status' => 'pending' }
    else
      Rails.logger.error "[AtlasCloudImageService] No task_id in response: #{result.inspect}"
      { 'task_id' => nil, 'output' => nil, 'error' => result['message'] || 'Failed to start generation' }
    end
  end

  # Alias for backwards compatibility
  alias_method :generate_gpt_image, :generate_image

  # Edit an existing image using Atlas Cloud unified API
  #
  # @param image_url [String] URL of the source image to edit
  # @param prompt [String] Text prompt describing the edit
  # @param model [String] Model ID for image editing
  # @param aspect_ratio [String] Aspect ratio (1:1, 16:9, 9:16, 4:3, 3:4)
  # @return [Hash] { task_id:, output:, status: }
  #
  def edit_image(image_url:,
                 prompt:,
                 model: 'qwen/qwen-image-2.0/edit',
                 aspect_ratio: '1:1')
    body = {
      model: model,
      prompt: prompt,
      image_url: image_url,
      aspect_ratio: aspect_ratio
    }

    Rails.logger.info "[AtlasCloudImageService] Editing image with model: #{model}"

    result = post_request('/api/v1/model/generateImage', body)

    task_id = extract_task_id(result)

    if task_id.present?
      Rails.logger.info "[AtlasCloudImageService] Image edit started, task_id: #{task_id}"
      { 'task_id' => task_id, 'output' => nil, 'status' => 'pending' }
    else
      Rails.logger.error "[AtlasCloudImageService] No task_id in response: #{result.inspect}"
      { 'task_id' => nil, 'output' => nil, 'error' => result['message'] || 'Failed to start image editing' }
    end
  end

  # Get image task status
  #
  # @param task_id [String] Task ID from generate_image
  # @return [Hash] { status:, output:, progress:, error: }
  #
  def image_status(task_id)
    result = get_request("/api/v1/model/prediction/#{task_id}")

    Rails.logger.debug "[AtlasCloudImageService] Task status response: #{result.inspect}"

    # Handle response - API wraps everything in 'data' key
    data = result.dig('data') || result

    # Normalize status
    status = normalize_status(data['status'] || 'unknown')

    # Get output/image URL
    output = nil
    if data['outputs'].is_a?(Array) && data['outputs'].any?
      output = data['outputs'].first
    elsif data['output'].present?
      output = data['output']
    elsif data['url'].present?
      output = data['url']
    end

    # Get error message if present
    error = data['error'] || data['error_message']

    {
      'status' => status,
      'output' => output,
      'progress' => data['progress'],
      'error' => error
    }
  rescue => e
    Rails.logger.error "[AtlasCloudImageService] Status check error: #{e.message}"
    if e.message.include?('404') || e.message.include?('Not Found')
      return { 'status' => 'not_found', 'output' => nil, 'error' => 'Task not found - may still be processing' }
    end
    { 'status' => 'error', 'output' => nil, 'error' => e.message }
  end

  # Alias for backwards compatibility
  alias_method :task_status, :image_status

  def configured?
    @api_key.present?
  end

  # Get available models for UI display
  def self.available_models
    AVAILABLE_MODELS
  end

  # Get available image edit models for UI display
  def self.available_image_edit_models
    IMAGE_EDIT_MODELS
  end

  # Get all image models combined for dropdowns
  def self.all_image_models
    AVAILABLE_MODELS.merge(IMAGE_EDIT_MODELS)
  end

  private

  def normalize_status(status)
    case status&.downcase
    when 'success', 'completed', 'done', 'ready', 'succeeded'
      'success'
    when 'failed', 'error', 'cancelled'
      'failed'
    when 'pending', 'queued', 'submitted', 'not_started'
      'pending'
    when 'processing', 'in_progress', 'running', 'starting'
      'processing'
    else
      status || 'unknown'
    end
  end

  def extract_task_id(result)
    result.dig('data', 'id') ||
      result.dig('data', 'task_id') ||
      result['id'] ||
      result['task_id']
  end

  def fetch_api_key
    ENV['ATLASCLOUD_API_KEY'].presence ||
      ENV['ATLAS_CLOUD_API_KEY'].presence ||
      ENV['API_KEY_ATLASCLOUD'].presence
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

    Rails.logger.error "[AtlasCloudImageService] Response code: #{response.code}, body: #{response.body[0..500]}"

    case response.code
    when 200..299
      if parsed.is_a?(Hash) && (parsed['error'].present? || parsed['message'].to_s.present? || parsed['status'] == 'error')
        error_msg = parsed['error'] || parsed['message'] || parsed.dig('error', 'message')
        Rails.logger.error "[AtlasCloudImageService] API returned error: #{error_msg}"
        raise Error, "API error: #{error_msg}"
      end
      parsed
    when 401, 403
      raise AuthenticationError, 'Invalid API key - please check your Atlas Cloud API key configuration'
    when 402
      error_msg = parsed.dig('error', 'message') || 'Insufficient credits - please top up your Atlas Cloud account'
      raise Error, error_msg
    when 429
      raise Error, 'Rate limit exceeded - please try again later'
    when 500..599
      raise Error, "Server error: #{response.code}"
    else
      raise Error, "Unexpected response: #{response.code} - #{response.body[0..200]}"
    end
  end
end
