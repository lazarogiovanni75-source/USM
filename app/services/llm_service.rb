require 'anthropic'

class LlmService
  class TimeoutError < StandardError; end
  class ApiError < StandardError; end

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
