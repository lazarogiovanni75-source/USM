# frozen_string_literal: true

# Claude Agent SDK Service
# Uses Anthropic's official SDK for Claude integration
# Model: claude-sonnet-4-6 by default
class ClaudeService
  class ClaudeError < StandardError; end
  class BudgetExceededError < StandardError; end

  BASE_URL = ENV.fetch('ANTHROPIC_BASE_URL', 'https://api.anthropic.com')
  DEFAULT_MODEL = 'claude-sonnet-4-6'
  API_VERSION = '2023-06-01'

  # Cost per 1000 tokens (approximate)
  COST_PER_1K_INPUT_TOKENS = 0.003
  COST_PER_1K_OUTPUT_TOKENS = 0.015

  attr_reader :total_cost, :total_tokens

  def initialize(api_key: nil, model: nil, max_tokens: nil, max_budget_usd: nil)
    @api_key = api_key || ENV['ANTHROPIC_API_KEY'].presence || ENV['CLACKY_ANTHROPIC_API_KEY'].presence
    raise ClaudeError, 'ANTHROPIC_API_KEY is not configured' unless @api_key
    @model = model || DEFAULT_MODEL
    @max_tokens = max_tokens || 4096
    @max_budget_usd = max_budget_usd&.to_f
    @total_cost = 0.0
    @total_tokens = 0
  end

  # Main message call - supports both text and tool use
  #
  # @param messages [Array<Hash>] Array of message hashes with :role and :content
  # @param system [String, nil] Optional system prompt
  # @param tools [Array<Hash>, nil] Tool definitions in Anthropic format
  # @param tool_choice [String, Hash, nil] 'auto', 'any', or {type: 'tool', name: 'tool_name'}
  # @param temperature [Float] Sampling temperature (0.0 to 1.0)
  # @return [Hash] { content:, tool_calls:, cost:, usage: }
  #
  def messages(messages:, system: nil, tools: nil, tool_choice: nil, temperature: 0.7)
    check_budget!

    body = build_request_body(
      messages: messages,
      system: system,
      tools: tools,
      tool_choice: tool_choice,
      temperature: temperature
    )

    response = http_request('/v1/messages', body)
    result = parse_response(response)

    # Track usage and cost
    track_usage(result.dig('usage') || {})

    result
  end

  # Streaming messages call
  #
  # @param messages [Array<Hash>] Array of message hashes
  # @param system [String, nil] Optional system prompt
  # @param tools [Array<Hash>, nil] Tool definitions
  # @yield [chunk] Yields each chunk of the response
  # @return [Hash] Final result with usage stats
  #
  def messages_stream(messages:, system: nil, tools: nil, &block)
    check_budget!

    body = build_request_body(
      messages: messages,
      system: system,
      tools: tools,
      tool_choice: nil,
      temperature: 0.7
    ).merge(stream: true)

    response = http_stream_request('/v1/messages', body, &block)
    result = parse_response(response)

    track_usage(result.dig('usage') || {})

    result
  end

  # Convert OpenAI-style tools to Anthropic format
  def self.tools_to_anthropic(tools)
    return [] if tools.blank?

    tools.map do |tool|
      func = tool[:function] || tool['function']
      next nil unless func

      {
        name: func[:name] || func['name'],
        description: func[:description] || func['description'],
        input_schema: func[:parameters] || func['parameters'] || { type: 'object', properties: {} }
      }
    end.compact
  end

  def configured?
    @api_key.present?
  end

  private

  def build_request_body(messages:, system:, tools:, tool_choice:, temperature:)
    body = {
      model: @model,
      max_tokens: @max_tokens,
      messages: messages,
      temperature: temperature
    }

    body[:system] = system if system.present?
    body[:tools] = tools if tools.present?
    body[:tool_choice] = tool_choice if tool_choice.present?

    body
  end

  def http_request(endpoint, body)
    require 'net/http'
    require 'uri'
    require 'json'

    url = URI.parse("#{BASE_URL}#{endpoint}")
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = url.scheme == 'https'

    request = Net::HTTP::Post.new(url.request_uri)
    request['Content-Type'] = 'application/json'
    request['x-api-key'] = @api_key
    request['anthropic-version'] = API_VERSION
    request['User-Agent'] = 'UltimateSocialMedia/1.0'
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
    http.set_debug_output($stdout) if Rails.env.development?

    request = Net::HTTP::Post.new(url.request_uri)
    request['Content-Type'] = 'application/json'
    request['x-api-key'] = @api_key
    request['anthropic-version'] = API_VERSION
    request['User-Agent'] = 'UltimateSocialMedia/1.0'
    request.body = body.to_json

    response = http.request(request) do |chunk|
      # Parse SSE format
      chunk.split("\n").each do |line|
        next unless line.start_with?('data: ')
        data = line[6..]
        next if data == '[DONE]'

        begin
          json = JSON.parse(data)
          block.call(json) if block_given?
        rescue JSON::ParserError
          # Skip invalid JSON
        end
      end
    end

    handle_response(response)
  end

  def handle_response(response)
    case response.code.to_i
    when 200..299
      JSON.parse(response.body)
    when 401, 403
      raise ClaudeError, 'Invalid API key - check ANTHROPIC_API_KEY'
    when 429
      raise ClaudeError, 'Rate limit exceeded - please try again later'
    when 400..499
      error_body = JSON.parse(response.body) rescue {}
      raise ClaudeError, "Bad request: #{error_body.dig('error', 'message') || response.body}"
    when 500..599
      raise ClaudeError, "Claude API server error: #{response.code}"
    else
      raise ClaudeError, "Unexpected response: #{response.code}"
    end
  end

  def parse_response(response)
    content_blocks = response['content'] || []

    # Extract text content
    text_content = content_blocks
      .select { |block| block['type'] == 'text' }
      .map { |block| block['text'] }
      .join("\n")

    # Extract tool use blocks
    tool_calls = content_blocks
      .select { |block| block['type'] == 'tool_use' }
      .map do |block|
        {
          id: block['id'],
          name: block['name'],
          input: block['input']
        }
      end

    {
      'content' => text_content.presence,
      'tool_calls' => tool_calls.presence,
      'usage' => response['usage'] || {},
      'model' => response['model'],
      'stop_reason' => response['stop_reason']
    }
  end

  def track_usage(usage)
    input_tokens = usage['input_tokens'] || 0
    output_tokens = usage['output_tokens'] || 0

    @total_tokens += input_tokens + output_tokens

    input_cost = (input_tokens / 1000.0) * COST_PER_1K_INPUT_TOKENS
    output_cost = (output_tokens / 1000.0) * COST_PER_1K_OUTPUT_TOKENS

    @total_cost += input_cost + output_cost

    Rails.logger.info "[ClaudeService] Usage: #{input_tokens} input + #{output_tokens} output tokens, cost: $#{'%.6f' % (@total_cost)}"
  end

  def check_budget!
    return if @max_budget_usd.nil?

    if @total_cost >= @max_budget_usd
      raise BudgetExceededError, "Budget exceeded: $#{'%.4f' % @total_cost} >= $#{'%.4f' % @max_budget_usd}"
    end
  end
end
