require 'anthropic'

class LlmService
  class TimeoutError < StandardError; end
  class ApiError < StandardError; end

  # Include human-sounding prompt constants
  include LlmPrompts

  # Prepends any custom instructions to system prompt
  def self.system_prompt_with_brand_voice(base_system_prompt, user)
    base_system_prompt
  end

  # Convenience method for legacy compatibility
  def self.inject_brand_voice(user)
    ""
  end

  # Streaming call method for LlmStreamJob
  # Usage: LlmService.call(prompt: '...') { |chunk| ... }
  def self.call(prompt:, system: nil, user: nil, **options, &block)
    api_key = ENV['ANTHROPIC_API_KEY']

    if api_key.blank?
      raise ApiError, "ANTHROPIC_API_KEY environment variable is not configured"
    end

    client = Anthropic::Client.new(api_key: api_key)
    model = ENV.fetch('ANTHROPIC_MODEL', 'claude-sonnet-4-6')

    # Inject brand voice into system prompt if user is provided
    system_with_brand_voice = system_prompt_with_brand_voice(system, user)

    # Build messages array - Anthropic API uses system parameter separately
    messages = [{ role: 'user', content: prompt }]

    # For streaming, we need to use the messages stream endpoint
    stream_params = {
      model: model,
      max_tokens: 4096,
      messages: messages
    }
    stream_params[:system] = system_with_brand_voice if system_with_brand_voice

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

  def self.generate(prompt, user: nil)
    api_key = ENV['ANTHROPIC_API_KEY']
    
    if api_key.blank?
      Rails.logger.error "[LlmService] ANTHROPIC_API_KEY is not set or blank"
      raise "ANTHROPIC_API_KEY environment variable is not configured"
    end
    
    Rails.logger.info "[LlmService] API key present, length: #{api_key.length}, first 4 chars: #{api_key[0..3]}"
    
    client = Anthropic::Client.new(api_key: api_key)
    
    # Use human-sounding assistant prompt
    system_prompt = GENERAL_ASSISTANT
    system_with_brand_voice = system_prompt_with_brand_voice(system_prompt, user)
    
    create_params = {
      model: 'claude-sonnet-4-6',
      max_tokens: 1024,
      messages: [{ role: 'user', content: prompt }]
    }
    create_params[:system] = system_with_brand_voice if system_with_brand_voice
    
    response = client.messages.create(**create_params)
    response.content.first.text
  rescue Anthropic::AuthenticationError => e
    Rails.logger.error "[LlmService] Authentication error: #{e.message}"
    raise "Anthropic API authentication failed. Please check your API key."
  end
  
  # Generate content with structured response format (for controllers)
  # Usage: LlmService.generate_content(prompt: '...', user_id: current_user.id, content_type: 'caption')
  def self.generate_content(prompt:, user_id: nil, content_type: 'caption', **options)
    user = user_id ? User.find_by(id: user_id) : nil
    
    system_prompt = case content_type
    when 'caption'
      [CONTENT_CREATOR, "Return a JSON object with 'title' and 'body' keys."].join("\n\n")
    when 'ideas'
      [CONTENT_CREATOR, "Generate content ideas in a natural, conversational format."].join("\n\n")
    when 'blog_post'
      "You're a content writer who keeps readers engaged from start to finish. Write blog posts that feel like a conversation, not a lecture."
    when 'ad_copy'
      "You're a copywriter who knows how to sell without being pushy. Your ads feel helpful, not spammy."
    else
      GENERAL_ASSISTANT
    end
    
    content = call_blocking(prompt: prompt, system: system_prompt, user: user, **options)
    
    # Parse content based on content_type
    parsed_content = case content_type
    when 'caption'
      parse_caption_content(content)
    else
      { 'body' => content, 'title' => nil }
    end
    
    { success: true, content: parsed_content }
  rescue => e
    Rails.logger.error "[LlmService.generate_content] Error: #{e.message}"
    { success: false, error: e.message }
  end
  
  def self.parse_caption_content(content)
    # Try to extract JSON from the response
    json_match = content.match(/\{[^{}]*\}/m)
    if json_match
      begin
        JSON.parse(json_match[0])
      rescue JSON::ParserError
        { 'title' => nil, 'body' => content }
      end
    else
      { 'title' => nil, 'body' => content }
    end
  end
  
  # Blocking call method for LLM generation with brand voice support
  # Usage: LlmService.call_blocking(prompt: '...', system: '...', user: current_user)
  def self.call_blocking(prompt:, system: nil, user: nil, **options)
    api_key = ENV['ANTHROPIC_API_KEY']
    
    if api_key.blank?
      raise ApiError, "ANTHROPIC_API_KEY environment variable is not configured"
    end
    
    client = Anthropic::Client.new(api_key: api_key)
    model = options[:model] || ENV.fetch('ANTHROPIC_MODEL', 'claude-sonnet-4-6')
    temperature = options[:temperature]&.to_f || 0.7
    max_tokens = options[:max_tokens] || 4096
    
    # Inject brand voice into system prompt if user is provided
    system_with_brand_voice = system_prompt_with_brand_voice(system, user)
    
    messages = [{ role: 'user', content: prompt }]
    
    create_params = {
      model: model,
      max_tokens: max_tokens,
      messages: messages,
      temperature: temperature
    }
    create_params[:system] = system_with_brand_voice if system_with_brand_voice
    
    response = client.messages.create(**create_params)
    response.content.first.text
  rescue Anthropic::AuthenticationError => e
    raise ApiError, "Anthropic API authentication failed: #{e.message}"
  rescue Net::ReadTimeout, Net::OpenTimeout => e
    raise TimeoutError, "Request to Anthropic API timed out: #{e.message}"
  end

  # Chat method with conversation history support
  # Usage: LlmService.chat(system: '...', messages: [{role: 'user', content: '...'}, ...])
  def self.chat(system:, messages:, **options)
    api_key = ENV['ANTHROPIC_API_KEY']
    
    if api_key.blank?
      raise ApiError, "ANTHROPIC_API_KEY environment variable is not configured"
    end
    
    client = Anthropic::Client.new(api_key: api_key)
    model = options[:model] || ENV.fetch('ANTHROPIC_MODEL', 'claude-sonnet-4-6')
    max_tokens = options[:max_tokens] || 1024
    
    create_params = {
      model: model,
      max_tokens: max_tokens,
      system: system,
      messages: messages
    }
    
    response = client.messages.create(**create_params)
    response.content.first.text
  rescue Anthropic::AuthenticationError => e
    raise ApiError, "Anthropic API authentication failed: #{e.message}"
  rescue Net::ReadTimeout, Net::OpenTimeout => e
    raise TimeoutError, "Request to Anthropic API timed out: #{e.message}"
  end
end
