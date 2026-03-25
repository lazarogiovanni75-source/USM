# LLM Service - OpenAI API wrapper
# Uses GPT as the default LLM for all AI features
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

  # OpenAI API Configuration
  BASE_URL = ENV.fetch('LLM_BASE_URL', 'https://api.openai.com/v1')
  DEFAULT_MODEL = ENV.fetch('LLM_MODEL', 'gpt-4o')

  def initialize(prompt:, system: nil, messages: nil, **options)
    @prompt = prompt
    @system = system
    @provided_messages = messages || []
    @options = options
    
    # Use configured model or default
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
    response = http_request('/chat/completions', build_request_body)
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

      response = http_request('/chat/completions', build_request_body)
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

    http_stream_request('/chat/completions', build_request_body.merge(stream: true)) do |event|
      if event['choices']&.first&.dig('delta', 'content')
        content = event['choices'].first['delta']['content']
        full_content += content
        block.call(content)
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

      tool_calls_buffer = []
      content_buffer = ""
      has_tool_calls = false

      http_stream_request('/chat/completions', build_request_body.merge(stream: true)) do |event|
        delta = event.dig('choices', 0, 'delta')
        
        if delta
          # Accumulate content
          if delta['content']
            content_buffer += delta['content']
            block.call(delta['content']) if block_given?
          end
          
          # Accumulate tool calls
          if delta['tool_calls']
            has_tool_calls = true
            delta['tool_calls'].each_with_index do |tool_call, idx|
              tool_calls_buffer[idx] ||= {
                'id' => '',
                'type' => 'function',
                'function' => { 'name' => '', 'arguments' => '' }
              }
              tool_calls_buffer[idx]['id'] = tool_call['id'] if tool_call['id']
              tool_calls_buffer[idx]['function']['name'] = tool_call.dig('function', 'name') if tool_call.dig('function', 'name')
              tool_calls_buffer[idx]['function']['arguments'] += tool_call.dig('function', 'arguments').to_s
            end
          end
        end
      end

      # Build complete message
      message = { 'role' => 'assistant' }
      message['content'] = content_buffer if content_buffer.present?
      message['tool_calls'] = tool_calls_buffer if tool_calls_buffer.present?

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
    ENV['CLACKY_OPENAI_API_KEY'] || ENV['OPENAI_API_KEY'] || ENV['ULTIMATE_OPENAI_API_KEY'] || Figaro.env.openai_api_key || raise(LlmError, "CLACKY_OPENAI_API_KEY is not configured")
  end

  def build_request_body
    body = {
      model: @model,
      messages: @messages,
      temperature: @temperature,
      max_tokens: @max_tokens
    }

    body[:tools] = format_tools(@tools) if @tools.present?
    
    body
  end

  def format_tools(tools)
    tools.map do |tool|
      {
        type: 'function',
        function: {
          name: tool[:name],
          description: tool[:description] || '',
          parameters: tool[:parameters] || { type: 'object', properties: {}, required: [] }
        }
      }
    end
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
    request['Authorization'] = "Bearer #{api_key}"
    request.body = body.to_json

    response = http.request(request)
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
    request['Authorization'] = "Bearer #{api_key}"
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
      raise ApiError, 'Invalid API key - check CLACKY_OPENAI_API_KEY'
    when 429
      raise ApiError, 'Rate limit exceeded - please try again later'
    when 400..499
      error_body = JSON.parse(response.body) rescue {}
      raise ApiError, "Bad request: #{error_body.dig('error', 'message') || response.body}"
    when 500..599
      raise ApiError, "OpenAI API server error: #{response.code}"
    else
      raise ApiError, "Unexpected response: #{response.code}"
    end
  rescue JSON::ParserError => e
    raise ApiError, "Invalid JSON response: #{e.message}"
  end

  def extract_content(response)
    # OpenAI format: response['choices']&.first&.dig('message', 'content')
    response.dig('choices', 0, 'message', 'content')
  end

  def extract_text_content(message)
    message['content']
  end

  def extract_message(response)
    choice = response.dig('choices', 0)
    return nil unless choice
    
    message = choice['message'] || {}
    result = {
      'role' => message['role'] || 'assistant',
      'content' => message['content']
    }.compact
    
    # Extract tool calls from message
    if message['tool_calls']
      result['tool_calls'] = message['tool_calls'].map do |tc|
        {
          'id' => tc['id'],
          'type' => 'function',
          'function' => {
            'name' => tc.dig('function', 'name'),
            'arguments' => tc.dig('function', 'arguments')
          }
        }
      end
    end
    
    result
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
          'role' => 'tool',
          'tool_call_id' => tool_id,
          'content' => result.to_json
        }
      rescue => e
        @messages << {
          'role' => 'tool',
          'tool_call_id' => tool_id,
          'content' => { error: e.message }.to_json
        }
        Rails.logger.error("Tool execution error: #{e.class} - #{e.message}")
      end
    end
  end

  def build_initial_messages
    return if @messages.present?

    @messages.concat(@provided_messages) if @provided_messages.present?
    
    # Add system message first
    @messages.unshift({ 'role' => 'system', 'content' => @system }) if @system.present?
    
    # Add user message with prompt
    @messages << { 'role' => 'user', 'content' => @prompt }
  end

  def mock_response
    {
      'choices' => [
        { 'message' => { 'role' => 'assistant', 'content' => 'Mock response from OpenAI' } }
      ],
      'usage' => { 'prompt_tokens' => 10, 'completion_tokens' => 20 }
    }
  end
end
