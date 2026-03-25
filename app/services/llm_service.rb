# LlmService - Unified Anthropic Claude API service
# Handles both blocking and streaming requests with proper error handling

class LlmService
  # Custom error classes
  class LlmError < StandardError; end
  class ApiError < LlmError; end
  class TimeoutError < LlmError; end
  class ToolExecutionError < LlmError; end

  # Model auto-correction - fixes invalid Railway environment variables
  # Invalid model names will be replaced with valid alternatives
  INVALID_MODEL_MAPPINGS = {
    'claude-sonnet-4-20250514' => 'claude-3-5-sonnet-20241022',
    'claude-3-5-sonnet-20240620' => 'claude-3-5-sonnet-20241022'
  }.freeze

  # Anthropic API Configuration
  BASE_URL = ENV.fetch('ANTHROPIC_BASE_URL', 'https://api.anthropic.com')
  API_VERSION = '2023-06-01'
  # Using claude-3-5-sonnet-20241022 as default (stable, widely supported)
  # Alternative: claude-3-5-sonnet-latest (always newest 3.5)
  # Force correct model - ignore invalid Railway env var
  DEFAULT_MODEL = begin
    model = ENV['ANTHROPIC_MODEL'].presence
    # Fix invalid model names automatically
    if INVALID_MODEL_MAPPINGS.key?(model)
      Rails.logger.warn "[LLM] Invalid model '#{model}' detected, using '#{INVALID_MODEL_MAPPINGS[model]}' instead"
      INVALID_MODEL_MAPPINGS[model]
    else
      model || 'claude-3-5-sonnet-20241022'
    end
  end

  def initialize(prompt:, system: nil, model: nil, max_tokens: 4096, temperature: 1.0, timeout: 60, images: nil, messages: nil, tools: nil, tool_handler: nil)
    @prompt = prompt
    @system = system
    @model = model || DEFAULT_MODEL
    @max_tokens = max_tokens
    @temperature = temperature
    @timeout = timeout
    @images = normalize_images(images)
    @provided_messages = messages
    @tools = tools
    @tool_handler = tool_handler
    @messages = []
  end

  # Blocking call - returns full response
  def call_blocking
    build_initial_messages
    
    loop do
      body = build_request_body
      response = http_request('/v1/messages', body)
      
      message = extract_message(response)
      @messages << message
      
      if message['tool_calls'].present?
        handle_tool_calls(message['tool_calls'])
      else
        return extract_content(response)
      end
    end
  rescue Timeout::Error => e
    raise TimeoutError, "Request timeout: #{e.message}"
  rescue => e
    Rails.logger.error "[LLM] Error in call_blocking: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    raise LlmError, "Claude API error: #{e.message}"
  end

  # Streaming call - yields chunks as they arrive
  def call_stream(&block)
    build_initial_messages
    body = build_request_body.merge(stream: true)
    
    http_stream_request('/v1/messages', body, &block)
  rescue Timeout::Error => e
    raise TimeoutError, "Streaming request timeout: #{e.message}"
  rescue => e
    Rails.logger.error "[LLM] Error in call_stream: #{e.class} - #{e.message}"
    raise LlmError, "Streaming error: #{e.message}"
  end

  class << self
    def call_blocking(prompt:, system: nil, **options)
      new(prompt: prompt, system: system, **options).call_blocking
    end

    def call_stream(prompt:, system: nil, **options, &block)
      new(prompt: prompt, system: system, **options).call_stream(&block)
    end
  end

  private

  def api_key
    # RUNTIME ENV CHECK in LlmService#api_key
    Rails.logger.info "[LLM] === api_key() method called ==="
    Rails.logger.info "[LLM] ENV['ANTHROPIC_API_KEY'] = '#{ENV['ANTHROPIC_API_KEY']}'"
    Rails.logger.info "[LLM] ENV['ANTHROPIC_API_KEY'].present? = #{ENV['ANTHROPIC_API_KEY'].present?}"
    Rails.logger.info "[LLM] ENV['CLACKY_ANTHROPIC_API_KEY'] = '#{ENV['CLACKY_ANTHROPIC_API_KEY']}'"
    Rails.logger.info "[LLM] ENV['CLACKY_ANTHROPIC_API_KEY'].present? = #{ENV['CLACKY_ANTHROPIC_API_KEY'].present?}"
    Rails.logger.info "[LLM] All ENV keys: #{ENV.keys.count} total"
    Rails.logger.info "[LLM] ENV keys with 'ANTHROPIC': #{ENV.keys.select { |k| k.include?('ANTHROPIC') }.inspect}"
    Rails.logger.info "[LLM] ENV keys with 'API': #{ENV.keys.select { |k| k.include?('API') }.count} keys"
    
    key = ENV['ANTHROPIC_API_KEY'].presence || ENV['CLACKY_ANTHROPIC_API_KEY'].presence
    
    # Debug logging to verify API key is being read
    Rails.logger.info "[LLM] Final key present?: #{key.present?}"
    Rails.logger.info "[LLM] Final key first 8 chars: #{key&.slice(0, 8)&.ljust(8, '*') || 'nil'}"
    Rails.logger.info "[LLM] === api_key() method end ==="
    
    key || raise(LlmError, "ANTHROPIC_API_KEY is not configured")
  end

  def build_request_body
    body = {
      model: @model,
      max_tokens: @max_tokens,
      messages: @messages,
      temperature: @temperature
    }

    body[:system] = @system if @system.present?
    body[:tools] = @tools if @tools.present?
    
    body
  end

  def http_request(endpoint, body)
    return mock_response if Rails.env.test?

    require 'net/http'
    require 'uri'
    require 'json'

    url = URI.parse("#{BASE_URL}#{endpoint}")
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = url.scheme == 'https'
    http.read_timeout = @timeout
    http.open_timeout = 10

    request = Net::HTTP::Post.new(url.request_uri)
    request['Content-Type'] = 'application/json'
    request['x-api-key'] = api_key
    request['anthropic-version'] = API_VERSION
    request.body = body.to_json

    Rails.logger.info "[LLM] Sending request to #{endpoint} with model: #{@model}"
    
    response = http.request(request)
    
    Rails.logger.info "[LLM] Response code: #{response.code}"
    Rails.logger.debug "[LLM] Response body: #{response.body[0..500]}"
    
    handle_response(response)
  end

  def http_stream_request(endpoint, body, &block)
    require 'net/http'
    require 'uri'
    require 'json'

    url = URI.parse("#{BASE_URL}#{endpoint}")
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = url.scheme == 'https'
    http.read_timeout = @timeout
    http.open_timeout = 10

    request = Net::HTTP::Post.new(url.request_uri)
    request['Content-Type'] = 'application/json'
    request['x-api-key'] = api_key
    request['anthropic-version'] = API_VERSION
    request['Accept'] = 'text/event-stream'
    request.body = body.to_json

    buffer = ""
    http.request(request) do |response|
      response.read_body do |chunk|
        buffer += chunk
        
        while (line_end = buffer.index("\n"))
          line = buffer[0...line_end].strip
          buffer = buffer[(line_end + 1)..-1]
          
          next if line.empty?
          next unless line.start_with?('data: ')
          
          data = line[6..-1]
          next if data == '[DONE]'
          
          begin
            json = JSON.parse(data)
            block.call(json) if block_given?
          rescue JSON::ParserError
            # Skip invalid JSON
          end
        end
      end
    end
  end

  def handle_response(response)
    case response.code.to_i
    when 200..299
      JSON.parse(response.body)
    when 401, 403
      Rails.logger.error "[LLM] Auth error - API key: #{api_key&.slice(0, 8)}..."
      Rails.logger.error "[LLM] Response body: #{response.body}"
      raise ApiError, 'Invalid API key - check ANTHROPIC_API_KEY'
    when 429
      Rails.logger.error "[LLM] Rate limit - Response: #{response.body}"
      raise ApiError, 'Rate limit exceeded - please try again later'
    when 400..499
      error_body = JSON.parse(response.body) rescue {}
      Rails.logger.error "[LLM] Client error #{response.code} - Full response: #{response.body}"
      error_msg = error_body.dig('error', 'message') || response.body
      raise ApiError, "Bad request: #{error_msg}"
    when 500..599
      Rails.logger.error "[LLM] Server error #{response.code} - Response: #{response.body}"
      raise ApiError, "Claude API server error: #{response.code}"
    else
      Rails.logger.error "[LLM] Unexpected response #{response.code} - Body: #{response.body}"
      raise ApiError, "Unexpected response: #{response.code}"
    end
  rescue JSON::ParserError => e
    Rails.logger.error "[LLM] JSON parse error - Raw response: #{response.body}"
    raise ApiError, "Invalid JSON response: #{e.message}"
  end

  def extract_content(response)
    content_blocks = response['content'] || []
    
    text_content = content_blocks
      .select { |block| block['type'] == 'text' }
      .map { |block| block['text'] }
      .join("\n")
    
    text_content.presence
  end

  def extract_text_content(message)
    content = message['content']
    return content if content.is_a?(String)
    
    if content.is_a?(Array)
      content.select { |c| c['type'] == 'text' }.map { |c| c['text'] }.join("\n")
    end
  end

  def extract_message(response)
    {
      'role' => 'assistant',
      'content' => extract_content(response),
      'tool_calls' => extract_tool_calls(response)
    }.compact
  end

  def extract_tool_calls(response)
    content_blocks = response['content'] || []
    
    tool_calls = content_blocks
      .select { |block| block['type'] == 'tool_use' }
      .map do |block|
        {
          'id' => block['id'],
          'type' => 'function',
          'function' => {
            'name' => block['name'],
            'arguments' => block['input'].to_json
          }
        }
      end
    
    tool_calls.presence
  end

  def handle_tool_calls(tool_calls)
    raise ToolExecutionError, "No tool_handler provided" unless @tool_handler

    tool_calls.each do |tool_call|
      tool_id = tool_call['id']
      function_name = tool_call.dig('function', 'name')
      arguments_json = tool_call.dig('function', 'arguments')

      begin
        arguments = JSON.parse(arguments_json) if arguments_json.is_a?(String)
        arguments ||= {}
        
        result = @tool_handler.call(function_name, arguments)

        @messages << {
          'role' => 'user',
          'content' => [
            {
              'type' => 'tool_result',
              'tool_use_id' => tool_id,
              'content' => result.to_json
            }
          ]
        }
      rescue => e
        @messages << {
          'role' => 'user',
          'content' => [
            {
              'type' => 'tool_result',
              'tool_use_id' => tool_id,
              'content' => { error: e.message }.to_json
            }
          ]
        }
        Rails.logger.error("Tool execution error: #{e.class} - #{e.message}")
      end
    end
  end

  def build_initial_messages
    return if @messages.present?

    @messages.concat(@provided_messages) if @provided_messages.present?
    
    if @images.present?
      user_content = []
      user_content << { type: 'text', text: @prompt.to_s }
      @images.each do |img|
        user_content << { type: 'image', source: { type: 'base64', data: img } }
      end
      @messages << { role: 'user', content: user_content }
    else
      @messages << { role: 'user', content: @prompt }
    end
  end

  def normalize_images(images)
    return [] if images.blank?
    Array(images)
  end

  def mock_response
    {
      'content' => [
        { 'type' => 'text', 'text' => 'Mock response from Claude' }
      ],
      'usage' => { 'input_tokens' => 10, 'output_tokens' => 20 }
    }
  end
end
