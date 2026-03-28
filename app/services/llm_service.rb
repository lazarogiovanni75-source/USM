require 'anthropic'

class LlmService
  class TimeoutError < StandardError; end
  class ApiError < StandardError; end

  # Streaming call method for LlmStreamJob
  # Usage: LlmService.call(prompt: '...') { |chunk| ... }
  def self.call(prompt:, system: nil, **options, &block)
    api_key = ENV['ANTHROPIC_API_KEY']

    if api_key.blank?
      raise ApiError, "ANTHROPIC_API_KEY environment variable is not configured"
    end

    client = Anthropic::Client.new(api_key: api_key)
    model = ENV.fetch('ANTHROPIC_MODEL', 'claude-sonnet-4-6')

    # Build messages array - Anthropic API uses system parameter separately
    messages = [{ role: 'user', content: prompt }]

    # For streaming, we need to use the messages stream endpoint
    stream_params = {
      model: model,
      max_tokens: 4096,
      messages: messages
    }
    stream_params[:system] = system if system

    response = client.messages.stream(**stream_params) do |chunk|
      if chunk.type == 'content_block_delta' && chunk.delta.type == 'text_delta'
        block.call(chunk.delta.text) if block
      end
    end

    response
  rescue Anthropic::AuthenticationError => e
    raise ApiError, "Anthropic API authentication failed: #{e.message}"
  rescue Net::ReadTimeout, Net::OpenTimeout => e
    raise TimeoutError, "Request to Anthropic API timed out: #{e.message}"
  end

  def self.generate(prompt)
    api_key = ENV['ANTHROPIC_API_KEY']
    
    if api_key.blank?
      Rails.logger.error "[LlmService] ANTHROPIC_API_KEY is not set or blank"
      raise "ANTHROPIC_API_KEY environment variable is not configured"
    end
    
    Rails.logger.info "[LlmService] API key present, length: #{api_key.length}, first 4 chars: #{api_key[0..3]}"
    
    client = Anthropic::Client.new(api_key: api_key)
    response = client.messages.create(
      model: 'claude-sonnet-4-6',
      max_tokens: 1024,
      messages: [{ role: 'user', content: prompt }]
    )
    response.content.first.text
  rescue Anthropic::AuthenticationError => e
    Rails.logger.error "[LlmService] Authentication error: #{e.message}"
    raise "Anthropic API authentication failed. Please check your API key."
  end
end
