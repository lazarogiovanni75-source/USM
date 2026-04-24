
# frozen_string_literal: true

# Atlas Cloud Unified Service - Image and Video Generation
# API Base: https://api.atlascloud.ai
# Authentication: Bearer token via ATLASCLOUD_API_KEY environment variable
#
# Image Generation: POST /api/v1/model/generateImage
# Video Generation: POST /api/v1/model/generateVideo
# Status Polling:   GET  /api/v1/model/prediction/{id}
class AtlasCloudService
  BASE_URL = 'https://api.atlascloud.ai'
  TIMEOUT = 120

  # Available text-to-video models (ByteDance Seedance only)
  TEXT_TO_VIDEO_MODELS = {
    'bytedance/seedance-v1.5-pro/text-to-video-fast' => 'ByteDance Seedance V1.5 Pro'
  }.freeze

  IMAGE_TO_VIDEO_MODELS = {
    'bytedance/seedance-v1.5-pro/image-to-video-fast' => 'ByteDance Seedance V1.5 Pro'
  }.freeze

  # Available image models (ByteDance Seedream only)
  IMAGE_MODELS = {
    'bytedance/seedream-v4.5/sequential' => 'ByteDance Seedream 4.5 (Text-to-Image)'
  }.freeze

  # Image editing models (ByteDance Seedream only)
  IMAGE_EDIT_MODELS = {
    'bytedance/seedream-v4.5/edit-sequential' => 'ByteDance Seedream 4.5 (Image Edit)'
  }.freeze

  # Dual video model selection based on text content
  VIDEO_MODEL_TEXT = 'bytedance/seedance-v1.5-pro/text-to-video-fast'.freeze
  VIDEO_MODEL_VISUAL = 'bytedance/seedance-v1.5-pro/image-to-video-fast'.freeze
  VIDEO_DEFAULTS = { resolution: '720p', max_duration: 10 }.freeze

  class Error < StandardError; end
  class AuthenticationError < Error; end
  class GenerationError < Error; end

  # Detect if prompt contains text elements
  TEXT_PATTERNS = [
    /\btext\b/i,
    /\btitle\b/i,
    /\bcaption\b/i,
    /\bwords?\b/i,
    /\bsays?\b/i,
    /\breads?\b/i,
    /\boverlay\b/i,
    /"[^"]+"/
  ].freeze

  def initialize(api_key = nil)
    @api_key = api_key || fetch_api_key
    @base_url = BASE_URL
  end

  # Generate image using Atlas Cloud unified API
  #
  # @param prompt [String] Text prompt describing the image
  # @param model [String] Model ID (default: bytedance/seedream-v4.5/sequential)
  # @param aspect_ratio [String] Aspect ratio (16:9, 9:16, 1:1, 4:3, 3:4)
  # @return [Hash] { task_id:, output:, status: }
  #
  def generate_image(prompt:, model: 'bytedance/seedream-v4.5/sequential', aspect_ratio: '1:1')
    body = {
      model: model,
      prompt: prompt,
      aspect_ratio: aspect_ratio
    }

    Rails.logger.info "[AtlasCloudService] Generating image with model: #{model}"

    result = post_request('/api/v1/model/generateImage', body)

    task_id = extract_task_id(result)

    if task_id.present?
      Rails.logger.info "[AtlasCloudService] Image generation started, task_id: #{task_id}"
      { 'task_id' => task_id, 'output' => nil, 'status' => 'pending' }
    else
      Rails.logger.error "[AtlasCloudService] No task_id in response: #{result.inspect}"
      { 'task_id' => nil, 'output' => nil, 'error' => result.dig('message') || 'Failed to start image generation' }
    end
  end

  # Generate video from text prompt
  #
  # @param prompt [String] Text description of the video
  # @param model [String] Model ID (default: atlascloud/magi-1-24b)
  # @param aspect_ratio [String] Aspect ratio (default: 16:9)
  # @param duration [Integer] Video duration in seconds (default: 5)
  # @param quality [String] Quality tier (standard, hd)
  # @return [Hash] { task_id:, output:, status: }
  #
  def generate_video_from_text(prompt:,
                               model: nil,
                               aspect_ratio: '16:9',
                               duration: VIDEO_DEFAULTS[:max_duration],
                               quality: 'standard')
    selected_model = model.presence || select_video_model(prompt)
    resolution = VIDEO_DEFAULTS[:resolution]

    body = {
      model: selected_model,
      prompt: prompt,
      aspect_ratio: aspect_ratio,
      duration: duration,
      resolution: resolution,
      quality: quality
    }

    Rails.logger.info "[AtlasCloudService] Submitting text-to-video with model: #{selected_model}, resolution: #{resolution}"


    result = post_request('/api/v1/model/generateVideo', body)


    task_id = extract_task_id(result)

    if task_id.present?
      Rails.logger.info "[AtlasCloudService] Video generation started, task_id: #{task_id}"
      { 'task_id' => task_id, 'output' => nil, 'status' => 'pending' }
    else
      Rails.logger.error "[AtlasCloudService] No task_id in response: #{result.inspect}"
      { 'task_id' => nil, 'output' => nil, 'error' => result.dig('message') || 'Failed to start video generation' }
    end
  end

  def select_video_model(prompt)
    if prompt_contains_text?(prompt)
      Rails.logger.info "[AtlasCloudService] Prompt contains text - using Veo 3.1 lite"
      VIDEO_MODEL_TEXT
    else
      Rails.logger.info "[AtlasCloudService] Prompt is purely visual - using Wan 2.5"
      VIDEO_MODEL_VISUAL
    end
  end

  def prompt_contains_text?(prompt)
    TEXT_PATTERNS.any? { |pattern| pattern.match?(prompt) }
  end

  # Generate video from an image (image-to-video)
  #
  # @param image_url [String] URL of the source image
  # @param prompt [String] Optional text prompt to guide the generation
  # @param model [String] Model ID (default: atlascloud/magi-1-24b)
  # @param aspect_ratio [String] Aspect ratio (default: 16:9)
  # @param duration [Integer] Video duration in seconds (default: 5)
  # @param quality [String] Quality tier (standard, hd)
  # @return [Hash] { task_id:, output:, status: }
  #
  def generate_video_from_image(image_url:,
                                prompt: '',
                                model: 'bytedance/seedance-v1.5-pro/image-to-video-fast',
                                aspect_ratio: '16:9',
                                duration: 5,
                                quality: 'standard')
    body = {
      model: model,
      prompt: prompt,
      image_url: image_url,
      aspect_ratio: aspect_ratio,
      duration: duration,
      quality: quality
    }

    Rails.logger.info "[AtlasCloudService] Submitting image-to-video with model: #{model}, quality: #{quality}"

    result = post_request('/api/v1/model/generateVideo', body)

    task_id = extract_task_id(result)

    if task_id.present?
      Rails.logger.info "[AtlasCloudService] Image-to-video started, task_id: #{task_id}"
      { 'task_id' => task_id, 'output' => nil, 'status' => 'pending' }
    else
      Rails.logger.error "[AtlasCloudService] No task_id in response: #{result.inspect}"
      { 'task_id' => nil, 'output' => nil, 'error' => result.dig('message') || 'Failed to start video generation' }
    end
  end

  # Poll the status of a generation task
  #
  # @param task_id [String] Task ID returned from generate_* methods
  # @return [Hash] { status:, output:, progress:, error: }
  #
  def task_status(task_id)
    result = get_request("/api/v1/model/prediction/#{task_id}")

    Rails.logger.info "[AtlasCloudService] Raw status response for #{task_id}: #{result.inspect}"

    data = result.dig('data') || result
    status = normalize_status(data['status'] || 'unknown')

    # Extract output URL using comprehensive extraction
    output = extract_output_url(data)

    Rails.logger.info "[AtlasCloudService] Task #{task_id} - Status: #{status}, Output found: #{output.present?}"

    {
      'status' => status,
      'output' => output,
      'progress' => data['progress'],
      'error' => data['error']
    }
  rescue AtlasCloudService::Error => e
    if e.message.include?('404') || e.message.include?('Not Found') || e.message.include?('not found')
      Rails.logger.warn "[AtlasCloudService] Task #{task_id} not found (404)"
      return { 'status' => 'not_found', 'output' => nil, 'error' => 'Task not found' }
    end
    raise
  end

  def configured?
    @api_key.present?
  end

  # Backwards-compatible alias for generate_video_from_text
  # Used by GenerateVideoJob and legacy code
  # @deprecated Use generate_video_from_text or generate_video_from_image instead
  def generate_video(start_image_url: nil,
                     end_image_url: nil,
                     prompt: '',
                     duration: 4,
                     aspect_ratio: '16:9',
                     model: nil)
    if start_image_url.present? || end_image_url.present?
      # Image-to-video with start/end images (legacy behavior)
      generate_video_from_image(
        image_url: start_image_url,
        prompt: prompt,
        model: model || TEXT_TO_VIDEO_MODELS.keys.first,
        aspect_ratio: aspect_ratio,
        duration: duration
      )
    else
      # Text-to-video
      generate_video_from_text(
        prompt: prompt,
        model: model || TEXT_TO_VIDEO_MODELS.keys.first,
        aspect_ratio: aspect_ratio,
        duration: duration
      )
    end
  end

  # Get available models (for UI display)
  def self.available_video_models
    TEXT_TO_VIDEO_MODELS.merge(IMAGE_TO_VIDEO_MODELS)
  end

  def self.available_image_models
    IMAGE_MODELS
  end

  def self.available_image_edit_models
    IMAGE_EDIT_MODELS
  end

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

    Rails.logger.info "[AtlasCloudService] Editing image with model: #{model}"

    result = post_request('/api/v1/model/generateImage', body)

    task_id = extract_task_id(result)

    if task_id.present?
      Rails.logger.info "[AtlasCloudService] Image edit started, task_id: #{task_id}"
      { 'task_id' => task_id, 'output' => nil, 'status' => 'pending' }
    else
      Rails.logger.error "[AtlasCloudService] No task_id in response: #{result.inspect}"
      { 'task_id' => nil, 'output' => nil, 'error' => result.dig('message') || 'Failed to start image editing' }
    end
  end

  private

  def normalize_status(status)
    case status&.downcase
    when 'success', 'completed', 'done', 'finished', 'ready', 'succeeded'
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

  # Extract output URL from various possible response structures
  def extract_output_url(data)
    # Try data.outputs array (common pattern)
    if data['outputs'].is_a?(Array) && data['outputs'].any?
      output = data['outputs'].first
      Rails.logger.debug "[AtlasCloudService] Found output in data.outputs: #{output}"
      return output
    end

    # Try data.output directly
    if data['output'].present?
      Rails.logger.debug "[AtlasCloudService] Found output in data.output: #{data['output']}"
      return data['output']
    end

    # Try data.data.output (nested)
    if data['data'].is_a?(Hash) && data.dig('data', 'output').present?
      Rails.logger.debug "[AtlasCloudService] Found output in data.data.output: #{data.dig('data', 'output')}"
      return data.dig('data', 'output')
    end

    # Try data.urls.get
    if data.dig('urls', 'get').present?
      Rails.logger.debug "[AtlasCloudService] Found output in data.urls.get: #{data.dig('urls', 'get')}"
      return data.dig('urls', 'get')
    end

    # Try data.url
    if data['url'].present?
      Rails.logger.debug "[AtlasCloudService] Found output in data.url: #{data['url']}"
      return data['url']
    end

    # Try data.result
    if data['result'].present?
      Rails.logger.debug "[AtlasCloudService] Found output in data.result: #{data['result']}"
      return data['result']
    end

    # Try data.data.result
    if data['data'].is_a?(Hash) && data.dig('data', 'result').present?
      Rails.logger.debug "[AtlasCloudService] Found output in data.data.result: #{data.dig('data', 'result')}"
      return data.dig('data', 'result')
    end

    # Try data.generated_media
    if data['generated_media'].present?
      Rails.logger.debug "[AtlasCloudService] Found output in data.generated_media: #{data['generated_media']}"
      return data['generated_media']
    end

    # Try data.videos array
    if data['videos'].is_a?(Array) && data['videos'].any?
      Rails.logger.debug "[AtlasCloudService] Found output in data.videos: #{data['videos'].first}"
      return data['videos'].first
    end

    # Try data.images array
    if data['images'].is_a?(Array) && data['images'].any?
      Rails.logger.debug "[AtlasCloudService] Found output in data.images: #{data['images'].first}"
      return data['images'].first
    end

    Rails.logger.warn "[AtlasCloudService] No output URL found in response data"
    nil
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

    Rails.logger.error "[AtlasCloudService] Response code: #{response.code}, body: #{response.body[0..500]}"

    case response.code
    when 200..299
      error_msg = parsed['error'] ||
                  (parsed['message'].presence) ||
                  (parsed['status'] == 'error' ? 'Status error' : nil)
      if error_msg
        Rails.logger.error "[AtlasCloudService] API returned error: #{error_msg}"
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
