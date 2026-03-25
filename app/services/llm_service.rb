require 'anthropic'

class LlmService
  def self.generate(prompt)
    client = Anthropic::Client.new(api_key: ENV['ANTHROPIC_API_KEY'])
    response = client.messages(
      model: 'claude-sonnet-4-6',
      max_tokens: 1024,
      messages: [{ role: 'user', content: prompt }]
    )
    response.content.first.text
  end
end
