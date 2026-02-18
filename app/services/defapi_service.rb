# frozen_string_literal: true

# Defapi Service for Self-hosted Sora 2 Video Generation
# API Documentation: https://api.defapi.org
class DefapiService
  BASE_URL = 'https://api.defapi.org'
  TIMEOUT = 120

  class Error < StandardError; end
  class AuthenticationError < Error; end
  class GenerationError < Error; end

  def initialize(api_key = nil)
    @api_key = api_key || fetch_api_key
    @base_url = BASE_URL
  end

  # Generate video from text prompt (OpenAI Sora 2)
  # API Documentation: https://defapi.org/en/model/openai/sora-2-pro
  #
  # @param prompt [String] Text prompt describing the video to generate
  # @param duration [String] Video duration ("10", "15", or "25") - sora-2-pro supports "25"
  # @param aspect_ratio [String] Aspect ratio ("16:9" default or "9:16" for vertical)
  # @param model [String] Model identifier ("sora-2", "sora-2-hd", or "sora-2-pro")
  # @param image [String, optional] Reference image URL for image-to-video (max 1)
  #
  def generate_video(prompt:,
                     duration: '10',
                     aspect_ratio: '16:9',
                     model: 'sora-2-pro',
                     image: nil)
    body = {
      prompt: prompt,
      duration: duration,
      aspect_ratio: aspect_ratio,
      model: model
    }

    body[:image] = [image] if image.present?

    result = post_request('/api/sora2/gen', body)
    { 'task_id' => result.dig('data', 'task_id'), 'output' => nil }
  end

  # Generate image from text prompt (OpenAI GPT Image - Legacy)
  #
  # @param prompt [String] Text prompt describing the image to generate
  # @param size [String, optional] Image size (e.g., "1024x1024", "1792x1024", "1024x1792")
  # @param quality [String, optional] Image quality (e.g., "standard", "hd")
  #
  def generate_image(prompt:, size: nil, quality: nil)
    body = { prompt: prompt }

    # Add optional parameters if provided
    body[:size] = size if size.present?
    body[:quality] = quality if quality.present?

    result = post_request('/api/image/gen', body)
    { 'task_id' => result.dig('data', 'task_id'), 'output' => nil }
  end

  # Generate image using GPT-Image-1.5 API
  # API Documentation: https://defapi.org/en/model/openai/gpt-image-1.5
  #
  # @param prompt [String] Text prompt describing the image to generate
  # @param model [String] Model identifier (e.g., "openai/gpt-image-1.5")
  # @param size [String, optional] Image size ("auto", "1024x1024", "1536x1024", "1024x1536")
  # @param quality [String, optional] Image quality ("auto", "high", "medium", "low")
  # @param background [String, optional] Background type ("auto", "opaque", "transparent")
  # @param output_format [String, optional] Output format ("png", "jpeg", "webp")
  # @param images [Array, optional] Reference image URLs or base64
  #
  def generate_gpt_image(prompt:,
                         model: 'openai/gpt-image-1.5',
                         size: nil,
                         quality: nil,
                         background: nil,
                         output_format: nil,
                         images: nil)
    body = {
      model: model,
      prompt: prompt
    }

    body[:size] = size if size.present?
    body[:quality] = quality if quality.present?
    body[:background] = background if background.present?
    body[:output_format] = output_format if output_format.present?
    body[:images] = images if images.present?

    result = post_request('/api/gpt-image/gen', body)
    { 'task_id' => result.dig('data', 'task_id'), 'output' => nil }
  end

  # Get image generation task status (Legacy)
  def image_status(task_id)
    result = get_request("/api/task/query?task_id=#{task_id}")
    {
      'status' => result.dig('data', 'status'),
      'output' => result.dig('data', 'result', 'image'),
      'progress' => result.dig('data', 'progress'),
      'consumed' => result.dig('data', 'consumed')
    }
  end

  # Get GPT-Image generation task status
  # Handles array-based results from /api/gpt-image/gen
  def gpt_image_status(task_id)
    result = get_request("/api/task/query?task_id=#{task_id}")
    task_data = result.dig('data')

    # Extract image from array-based result
    result_array = task_data&.dig('result')
    image_output = nil
    if result_array.is_a?(Array) && result_array.first
      image_output = result_array.first['image']
    elsif result_array.is_a?(Hash)
      image_output = result_array['image']
    end

    {
      'status' => task_data&.dig('status'),
      'output' => image_output,
      'progress' => task_data&.dig('progress'),
      'consumed' => task_data&.dig('consumed'),
      'created_at' => task_data&.dig('created_at')
    }
  end

  # Get generation task status
  def task_status(task_id)
    result = get_request("/api/task/query?task_id=#{task_id}")
    
    # Extract all possible error information
    error_message = result.dig('data', 'status_reason', 'message') ||
                   result.dig('data', 'error') ||
                   result.dig('data', 'message') ||
                   result.dig('error', 'message') ||
                   result['message']
    
    # Check for various status indicators
    status = result.dig('data', 'status')
    
    # Also check if there's an error flag in the response
    if result.dig('data', 'status_reason', 'type') == 'error' ||
       result.dig('data', 'status_reason', 'code') && result.dig('data', 'status_reason', 'code') != 200
      status = 'error'
    end
    
    {
      'status' => status,
      'output' => result.dig('data', 'result', 'video'),
      'progress' => result.dig('data', 'progress'),
      'consumed' => result.dig('data', 'consumed'),
      'error' => error_message,
      'message' => error_message,
      'status_reason' => result.dig('data', 'status_reason')
    }
  end

  # Get user credit balance
  def credit_balance
    result = get_request('/api/user')
    result.dig('data', 'credit')
  end

  # Get user information and credit balance
  def user_info
    get_request('/api/user')
  end

  def configured?
    @api_key.present?
  end

  private

  def fetch_api_key
    ENV['DEFAPI_API_KEY'] ||
      ENV['CLACKY_DEFAPI_API_KEY'] ||
      Rails.application.config.x.defapi_api_key ||
      Rails.application.config_for(:application)['DEFAPI_API_KEY']
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
      raise Error, "Unexpected response: #{response.code} - #{response.body}"
    end
  end
end
