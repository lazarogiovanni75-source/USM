
# frozen_string_literal: true

# Atlas Cloud Service - Video Generation
# Image-to-Video model: vidu/q3-pro/start-end-to-video
# Text-to-Video model:  vidu/q3-pro/text-to-video
# API: https://api.atlascloud.ai
class AtlasCloudService
  BASE_URL = 'https://api.atlascloud.ai'
  DEFAULT_MODEL = 'vidu/q3-pro/start-end-to-video'
  TEXT_TO_VIDEO_MODEL = 'vidu/q3-pro/text-to-video'
  TIMEOUT = 120

  class Error < StandardError; end
  class AuthenticationError < Error; end
  class GenerationError < Error; end

  def initialize(api_key = nil)
    @api_key = api_key || fetch_api_key
    @base_url = BASE_URL
  end

  # Generate video from a start image and end image
  #
  # @param start_image_url [String] URL of the starting frame image
  # @param end_image_url [String] URL of the ending frame image
  # @param prompt [String] Optional text prompt to guide the generation
  # @param duration [Integer] Video duration in seconds (default: 4)
  # @param aspect_ratio [String] Aspect ratio e.g. "16:9", "9:16", "1:1"
  # @param model [String] Override the default model
  #
  def generate_video(start_image_url:,
                     end_image_url:,
                     prompt: '',
                     duration: 4,
                     aspect_ratio: '16:9',
                     model: nil)
    body = {
      model: model || DEFAULT_MODEL,
      start_image_url: start_image_url,
      end_image_url: end_image_url,
      prompt: prompt,
      duration: duration.to_i,
      aspect_ratio: aspect_ratio
    }

    Rails.logger.info "[AtlasCloudService] Submitting image-to-video job with model: #{body[:model]}"

    result = post_request('/api/v1/model/generateVideo', body)

    task_id = result.dig('data', 'id') || result['task_id']

    if task_id.present?
      Rails.logger.info "[AtlasCloudService] Video job started, task_id: #{task_id}"
      { 'task_id' => task_id, 'output' => nil, 'status' => 'pending' }
    else
      Rails.logger.error "[AtlasCloudService] No task_id in response: #{result.inspect}"
      { 'task_id' => nil, 'output' => nil, 'error' => result.dig('message') || 'Failed to start video generation' }
    end
  end

  # Generate video from a text prompt
  #
  # @param prompt [String] Text description of the video to generate
  # @param duration [Integer] Video duration in seconds (default: 4)
  # @param aspect_ratio [String] Aspect ratio e.g. "16:9", "9:16", "1:1"
  # @param model [String] Override the default text-to-video model
  #
  def generate_video_from_text(prompt:,
                                duration: 4,
                                aspect_ratio: '16:9',
                                model: nil)
    body = {
      model: model || TEXT_TO_VIDEO_MODEL,
      prompt: prompt,
      duration: duration.to_i,
      aspect_ratio: aspect_ratio
    }

    Rails.logger.info "[AtlasCloudService] Submitting text-to-video job with model: #{body[:model]}"

    result = post_request('/api/v1/model/generateVideo', body)

    task_id = result.dig('data', 'id') || result['task_id']

    if task_id.present?
      Rails.logger.info "[AtlasCloudService] Text-to-video job started, task_id: #{task_id}"
      { 'task_id' => task_id, 'output' => nil, 'status' => 'pending' }
    else
      Rails.logger.error "[AtlasCloudService] No task_id in response: #{result.inspect}"
      { 'task_id' => nil, 'output' => nil, 'error' => result.dig('message') || 'Failed to start video generation' }
    end
  end

  # Poll the status of a video generation task
  #
  # @param task_id [String] Task ID returned from generate_video
  # @return [Hash] { status:, output:, progress:, error: }
  #
  def task_status(task_id)
    result = get_request("/api/v1/model/prediction/#{task_id}")

    Rails.logger.info "[AtlasCloudService] Task status for #{task_id}: #{result.inspect}"

    data = result.dig('data') || result
    status = data['status'] || 'unknown'

    output = nil
    if data['outputs'].is_a?(Array) && data['outputs'].any?
      output = data['outputs'].first
    end

    {
      'status' => status,
      'output' => output,
      'progress' => data['progress'],
      'error' => data['error']
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
