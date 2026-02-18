# frozen_string_literal: true

# OpenAI Image Generation Service (Direct API)
# Secondary image generation service when Defapi is unavailable
# Uses OpenAI's GPT-Image-1.0 API
class OpenaiImageService
  BASE_URL = 'https://api.openai.com/v1'
  TIMEOUT = 120

  class Error < StandardError; end
  class AuthenticationError < Error; end
  class GenerationError < Error; end

  def initialize(api_key = nil)
    @api_key = api_key || fetch_api_key
    @base_url = BASE_URL
  end

  # Generate image using OpenAI's GPT-Image-1.0 (direct API)
  # Documentation: https://platform.openai.com/docs/guides/images
  #
  # @param prompt [String] Text prompt describing the image
  # @param size [String] Image size (1024x1024, 1024x1536, 1536x1024)
  # @param quality [String] Quality (standard, hd) - 'high' maps to 'hd'
  # @param n [Integer] Number of images to generate
  #
  def generate_gpt_image(prompt:,
                        size: '1024x1024',
                        quality: 'high',
                        n: 1)
    body = {
      model: 'gpt-image-1',
      prompt: prompt,
      size: size,
      quality: quality,
      n: n
    }

    result = post_request('/images/generations', body)
    
    # Handle both url and b64_json response formats
    # b64_json is used for 'high' quality, url for 'standard'
    image_data = result.dig('data', 0)
    image_url = image_data&.dig('url')
    image_b64 = image_data&.dig('b64_json')
    revised_prompt = image_data&.dig('revised_prompt')
    
    { 'task_id' => revised_prompt, 'output' => image_url || image_b64 }
  end

  # Alias for backwards compatibility
  alias_method :generate_image, :generate_gpt_image

  # Check if service is configured
  def configured?
    @api_key.present?
  end

  private

  def fetch_api_key
    ENV['OPENAI_API_KEY'] ||
      ENV['CLACKY_OPENAI_API_KEY'] ||
      Rails.application.config.x.openai_api_key ||
      Rails.application.config_for(:application)['OPENAI_API_KEY']
  end

  def post_request(endpoint, body)
    url = "#{@base_url}#{endpoint}"
    response = HTTParty.post(url, body: body.to_json, headers: request_headers, timeout: TIMEOUT)
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
    when 400
      raise GenerationError, "Bad request: #{response.body}"
    when 429
      raise Error, 'Rate limit exceeded'
    when 500..599
      raise Error, "Server error: #{response.code}"
    else
      raise Error, "Unexpected response: #{response.code} - #{response.body}"
    end
  end
end
