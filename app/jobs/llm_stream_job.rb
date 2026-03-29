class LlmStreamJob < ApplicationJob
  queue_as :llm

  # Retry strategy configuration
  retry_on Net::ReadTimeout, wait: 5.seconds, attempts: 3
  retry_on LlmService::TimeoutError, wait: 5.seconds, attempts: 3
  retry_on LlmService::ApiError, wait: 10.seconds, attempts: 2

  # Streaming LLM responses via ActionCable
  # Usage:
  #   LlmStreamJob.perform_later(stream_name: 'analysis_123', prompt: "Hello")
  #   LlmStreamJob.perform_later(stream_name: 'chat_456', prompt: "...", tools: [...], tool_handler: ...)
  #
  # CRITICAL: ALL broadcasts MUST have 'type' field (auto-routes to client handler)
  # - type: 'chunk' → client calls handleChunk(data)
  # - type: 'complete' → client calls handleComplete(data)
  # - type: 'tool_call' → (optional) client calls handleToolCall(data)
  #
  # ⚠️  DO NOT rescue exceptions here!
  # ApplicationJob handles all exceptions globally and reports them automatically.
  # If you catch exceptions here, they will be "swallowed" and not reported.
  #
  # Example 1: Basic streaming
  #   def perform(stream_name:, prompt:, system: nil, **options)
  #     full_content = ""
  #
  #     LlmService.call(prompt: prompt, system: system, **options) do |chunk|
  #       full_content += chunk
  #       ActionCable.server.broadcast(stream_name, {
  #         type: 'chunk',
  #         chunk: chunk
  #       })
  #     end
  #
  #     ActionCable.server.broadcast(stream_name, {
  #       type: 'complete',
  #       content: full_content
  #     })
  #   end
  #
  # Example 2: With tool calling (tools/tool_handler passed in **options)
  #   def perform(stream_name:, prompt:, system: nil, **options)
  #     # Wrap tool_handler to broadcast tool calls
  #     original_handler = options[:tool_handler]
  #     options[:tool_handler] = ->(name, args) {
  #       ActionCable.server.broadcast(stream_name, {
  #         type: 'tool_call',
  #         tool_name: name,
  #         arguments: args
  #       })
  #       original_handler.call(name, args)
  #     } if original_handler
  #
  #     full_content = ""
  #     LlmService.call(prompt: prompt, system: system, **options) do |chunk|
  #       full_content += chunk
  #       ActionCable.server.broadcast(stream_name, { type: 'chunk', chunk: chunk })
  #     end
  #
  #     ActionCable.server.broadcast(stream_name, { type: 'complete', content: full_content })
  #   end
  def perform(stream_name:, prompt:, system: nil, user_id: nil, **options)
    full_content = ""

    begin
      # Get user for brand voice injection
      user = user_id ? User.find_by(id: user_id) : nil

      LlmService.call(prompt: prompt, system: system, user: user, **options) do |chunk|
        full_content += chunk
        ActionCable.server.broadcast(stream_name, {
          type: 'chunk',
          chunk: chunk
        })
      end

      ActionCable.server.broadcast(stream_name, {
        type: 'complete',
        content: full_content
      })
    rescue StandardError => e
      ActionCable.server.broadcast(stream_name, {
        type: 'error',
        error: e.message
      })
      raise
    end
  end
end
