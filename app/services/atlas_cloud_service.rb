
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

  # Available text-to-video models (user selected)
  TEXT_TO_VIDEO_MODELS = {
    'openai/sora-2/text-to-video' => 'OpenAI Sora 2 (High Quality)',
    'bytedance/seedance-v1-pro-fast/text-to-video' => 'ByteDance Seedance V1 Pro (Fast)'
  }.freeze

  IMAGE_TO_VIDEO_MODELS = {
    'atlascloud/magi-1-24b' => 'Magi-1 24B (Image-to-Video)',
    'vidu/q3-pro/start-end-to-video' => 'Vidu Q3-Pro (Start-End-to-Video)',
    'alibaba/wan-2.5/image-to-video' => 'Wan 2.5 Image-to-Video'
  }.freeze

  # Available image models (user selected)
  IMAGE_MODELS = {
    'z-image/turbo' => 'Z-Image Turbo (Fast)',
    'alibaba/qwen-image/text-to-image-plus' => 'Alibaba Qwen Image Plus (High Quality)'
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
  # @param aspect_ratio [String] Aspect ratio (16:9, 9:16, 1:1, 4:3, 3:4)
  # @return [Hash] { task_id:, output:, status: }
  #
  def generate_image(prompt:, model: 'black-forest-labs/flux-1.1-pro', aspect_ratio: '1:1')
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
  # @return [Hash] { task_id:, output:, status: }
  #
  def generate_video_from_text(prompt:,
                                model: 'atlascloud/magi-1-24b',
                                aspect_ratio: '16:9',
                                duration: 5)
    body = {
      model: model,
      prompt: prompt,
      aspect_ratio: aspect_ratio,
      resolution: '480p',
      duration: duration
    }

    Rails.logger.info "[AtlasCloudService] Submitting text-to-video with model: #{model}"

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

  # Generate video from an image (image-to-video)
  #
  # @param image_url [String] URL of the source image
  # @param prompt [String] Optional text prompt to guide the generation
  # @param model [String] Model ID (default: atlascloud/magi-1-24b)
  # @param aspect_ratio [String] Aspect ratio (default: 16:9)
  # @param duration [Integer] Video duration in seconds (default: 5)
  # @return [Hash] { task_id:, output:, status: }
  #
  def generate_video_from_image(image_url:,
                                 prompt: '',
                                 model: 'atlascloud/magi-1-24b',
                                 aspect_ratio: '16:9',
                                 duration: 5)
    body = {
      model: model,
      prompt: prompt,
      image_url: image_url,
      aspect_ratio: aspect_ratio,
      resolution: '480p',
      duration: duration
    }

    Rails.logger.info "[AtlasCloudService] Submitting image-to-video with model: #{model}"

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

    Rails.logger.debug "[AtlasCloudService] Task status for #{task_id}: #{result.inspect}"

    data = result.dig('data') || result
    status = normalize_status(data['status'] || 'unknown')

    output = nil
    if data['outputs'].is_a?(Array) && data['outputs'].any?
      output = data['outputs'].first
    elsif data['output'].present?
      output = data['output']
    elsif data['url'].present?
      output = data['url']
    end

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

  def fetch_api_key
    ENV['ATLASCLOUD_API_KEY'].presence ||
      ENV['ATLAS_CLOUD_API_KEY'].presence ||
      ENV['CLACKY_ATLASCLOUD_API_KEY'].presence
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

    Rails.logger.debug "[AtlasCloudService] Response code: #{response.code}, body: #{response.body[0..500]}"

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
