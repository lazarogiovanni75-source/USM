# LLM Service - Anthropic Claude API wrapper
# Uses Claude as the default LLM for all AI features
#
# Usage:
#   LlmService.call(prompt: "Hello", system: "You are helpful")
#   LlmService.call_blocking(prompt: "Hello")
#   LlmService.call_stream(prompt: "Hello") { |chunk| ... }
#
# Tool Call Support:
#   - Pass tools: [...] to enable function calling
#   - Pass tool_handler: ->(tool_name, args) { ... } to handle tool execution
class LlmService < ApplicationService
  class LlmError < StandardError; end
  class TimeoutError < LlmError; end
  class ApiError < LlmError; end
  class ToolExecutionError < LlmError; end

  # Anthropic API Configuration
  BASE_URL = ENV.fetch('ANTHROPIC_BASE_URL', 'https://api.anthropic.com')
  API_VERSION = '2023-06-01'
  DEFAULT_MODEL = ENV.fetch('ANTHROPIC_MODEL', 'claude-sonnet-4-20250514')

  def initialize(prompt:, system: nil, messages: nil, **options)
    @prompt = prompt
    @system = system
    @provided_messages = messages || []
    @options = options
    
    # Use Claude model by default
    @model = options[:model] || DEFAULT_MODEL
    @temperature = options[:temperature]&.to_f || 0.7
    @max_tokens = options[:max_tokens] || 4096
    @timeout = options[:timeout] || 60
    
    # Tool call support
    @tools = options[:tools] || []
    @tool_handler = options[:tool_handler]
    @max_tool_iterations = options[:max_tool_iterations] || 5
    
    # Conversation history
    @messages = []
  end

  # Default call - streaming if block given, blocking otherwise
  def call(&block)
    if block_given?
      call_stream(&block)
    else
      call_blocking
    end
  end

  # Explicit blocking call
  def call_blocking
    raise LlmError, "Prompt cannot be blank" if @prompt.blank?

    build_initial_messages

    if @tools.present?
      call_blocking_with_tools
    else
      call_blocking_simple
    end
  rescue => e
    Rails.logger.error("LLM Error: #{e.class} - #{e.message}")
    raise
  end

  # Simple blocking call without tool support
  def call_blocking_simple
    response = http_request('/v1/messages', build_request_body)
    content = extract_content(response)
    
    raise LlmError, "No content in response" if content.blank?
    content
  end

  # Blocking call with tool execution
  def call_blocking_with_tools
    iteration = 0
    final_content = nil

    loop do
      iteration += 1
      raise LlmError, "Max tool iterations (#{@max_tool_iterations}) exceeded" if iteration > @max_tool_iterations

      response = http_request('/v1/messages', build_request_body)
      message = extract_message(response)
      
      # Add assistant message to history
      @messages << message

      # Check for tool calls
      tool_calls = message['tool_calls']
      if tool_calls.present?
        handle_tool_calls(tool_calls)
      else
        final_content = extract_text_content(message)
        break
      end
    end

    raise LlmError, "No content in final response" if final_content.blank?
    final_content
  end

  # Streaming call
  def call_stream(&block)
    raise LlmError, "Prompt cannot be blank" if @prompt.blank?
    raise LlmError, "Block required for streaming" unless block_given?

    build_initial_messages

    if @tools.present?
      call_stream_with_tools(&block)
    else
      call_stream_simple(&block)
    end
  rescue => e
    Rails.logger.error("LLM Stream Error: #{e.class} - #{e.message}")
    raise
  end

  # Simple streaming without tools
  def call_stream_simple(&block)
    full_content = ""

    http_stream_request('/v1/messages', build_request_body.merge(stream: true)) do |event|
      if event['type'] == 'content_block_delta'
        if event['delta']['type'] == 'text_delta'
          content = event['delta']['text']
          full_content += content
          block.call(content)
        end
      elsif event['type'] == 'message_stop'
        # Stream complete
      end
    end

    full_content
  end

  # Streaming with tool support
  def call_stream_with_tools(&block)
    iteration = 0
    final_content = ""

    loop do
      iteration += 1
      raise LlmError, "Max tool iterations (#{@max_tool_iterations}) exceeded" if iteration > @max_tool_iterations

      tool_calls_buffer = {}
      content_buffer = ""
      has_tool_calls = false

      http_stream_request('/v1/messages', build_request_body.merge(stream: true)) do |event|
        case event['type']
        when 'content_block_delta'
          if event['delta']['type'] == 'text_delta'
            content = event['delta']['text']
            content_buffer += content
            block.call(content)
          elsif event['delta']['type'] == 'input_json_delta'
            has_tool_calls = true
            idx = event['content_block_index']
            tool_calls_buffer[idx] ||= {
              'type' => 'tool_use',
              'id' => '',
              'name' => '',
              'input' => ''
            }
            if event['delta']['partial_json']
              tool_calls_buffer[idx]['input'] += event['delta']['partial_json']
            end
          end
        when 'content_block_start'
          if event['content_block']['type'] == 'tool_use'
            idx = event['index']
            tool_calls_buffer[idx] ||= {}
            tool_calls_buffer[idx]['type'] = 'tool_use'
            tool_calls_buffer[idx]['id'] = event['content_block']['id']
            tool_calls_buffer[idx]['name'] = event['content_block']['name']
            tool_calls_buffer[idx]['input'] = ''
          end
        when 'message_stop'
          # Stream complete
        end
      end

      # Build complete message
      message = { 'role' => 'assistant' }
      message['content'] = content_buffer if content_buffer.present?
      if has_tool_calls
        message['tool_calls'] = tool_calls_buffer.values
      end

      @messages << message

      if has_tool_calls
        handle_tool_calls(message['tool_calls'])
      else
        final_content = content_buffer
        break
      end
    end

    final_content
  end

  # Class method shortcuts
  class << self
    def call(prompt:, system: nil, **options, &block)
      new(prompt: prompt, system: system, **options).call(&block)
    end

    def call_blocking(prompt:, system: nil, **options)
      new(prompt: prompt, system: system, **options).call_blocking
    end

    def call_stream(prompt:, system: nil, **options, &block)
      new(prompt: prompt, system: system, **options).call_stream(&block)
    end
  end

  private

  def api_key
    key = ENV['ANTHROPIC_API_KEY'].presence || ENV['CLACKY_ANTHROPIC_API_KEY'].presence
    
    # Debug logging to verify API key is being read
    Rails.logger.info "[LLM] ANTHROPIC_API_KEY present?: #{key.present?}"
    Rails.logger.info "[LLM] ANTHROPIC_API_KEY first 8 chars: #{key&.slice(0, 8)&.ljust(8, '*') || 'nil'}"
    
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
      raise ApiError, 'Invalid API key - check ANTHROPIC_API_KEY'
    when 429
      raise ApiError, 'Rate limit exceeded - please try again later'
    when 400..499
      error_body = JSON.parse(response.body) rescue {}
      raise ApiError, "Bad request: #{error_body.dig('error', 'message') || response.body}"
    when 500..599
      raise ApiError, "Claude API server error: #{response.code}"
    else
      raise ApiError, "Unexpected response: #{response.code}"
    end
  rescue JSON::ParserError => e
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
