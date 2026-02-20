# frozen_string_literal: true

# ConversationOrchestrator - Unifies text chat, voice input, and tool execution
#
# All AI interactions go through this service to ensure consistent:
# - Message handling
# - Tool definitions
# - Tool execution
# - Conversation history management
#
# Usage:
#   # Streaming mode (yields chunks)
#   ConversationOrchestrator.run(
#     conversation_id: 1,
#     content: "Hello!",
#     modality: "text",
#     stream_name: "ai_chat_1"
#   ) do |chunk|
#     # Handle streaming chunk - chunk is a Hash with :delta and :conversation_id
#   end
#
#   # Blocking mode
#   response = ConversationOrchestrator.run(
#     conversation_id: 1,
#     content: "Hello!",
#     modality: "text"
#   )
class ConversationOrchestrator
  class Error < StandardError; end

  # Maximum tool iterations to prevent infinite loops
  MAX_TOOL_ITERATIONS = 5

  # Tool execution timeout (seconds)
  TOOL_TIMEOUT = 60

  # Event types for streaming
  ASSISTANT_TOKEN = 'assistant_token'
  ASSISTANT_COMPLETE = 'assistant_complete'
  ERROR = 'error'

  # Unified tool definitions (used by both text chat and voice)
  TOOL_DEFINITIONS = AiVoiceTools::TOOLS

  # Run the orchestrator
  # @param conversation_id [Integer] The conversation ID
  # @param content [String] The user message content
  # @param modality [String] How the message was sent: "text" or "voice"
  # @param system_prompt [String, nil] Optional custom system prompt
  # @param enable_tools [Boolean] Whether to enable tool execution (default: true)
  # @param user [User, nil] The user making the request (required for tools)
  # @param stream_name [String, nil] ActionCable channel for streaming events
  # @yield [Hash] Yields chunks in streaming mode: { delta: "...", conversation_id: ... }
  # @return [String] The final assistant response content
  def self.run(conversation_id:, content:, modality: "text", system_prompt: nil, enable_tools: true, user: nil, stream_name: nil, &block)
    Rails.logger.info "[ConversationOrchestrator] self.run called - conversation_id: #{conversation_id}, block_given?: #{block_given?}, stream_name: #{stream_name}"
    
    orchestrator = new(
      conversation_id: conversation_id,
      content: content,
      modality: modality,
      system_prompt: system_prompt,
      enable_tools: enable_tools,
      user: user,
      stream_name: stream_name
    )

    if block_given?
      orchestrator.run_stream(&block)
    else
      orchestrator.run_blocking
    end
  rescue => e
    Rails.logger.error "[ConversationOrchestrator] self.run failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    if orchestrator.stream_name.present?
      begin
        ActionCable.server.broadcast(orchestrator.stream_name, { error: "AI processing failed: #{e.message}" })
      rescue => broadcast_error
        Rails.logger.error "[ConversationOrchestrator] Failed to broadcast error: #{broadcast_error.message}"
      end
    end

    nil
  end

  # Instance methods
  attr_reader :conversation_id, :content, :modality, :system_prompt, :enable_tools, :user, :stream_name

  def initialize(conversation_id:, content:, modality: "text", system_prompt: nil, enable_tools: true, user: nil, stream_name: nil)
    @conversation_id = conversation_id
    @content = content
    @modality = modality
    @system_prompt = system_prompt || default_system_prompt
    @enable_tools = enable_tools && user.present?
    @user = user
    @stream_name = stream_name
    @execution_id = SecureRandom.uuid
  end

  # Streaming method - yields chunks for real-time response
  def run_stream(&block)
    raise ArgumentError, "Block required for streaming" unless block_given?

    Rails.logger.info "[ConversationOrchestrator] Starting run_stream for conversation #{conversation_id}"

    response_content = ""

    begin
      # Save user message FIRST before building history
      save_user_message

      # Load conversation history from ai_messages (now includes current message)
      history = build_message_history

      # Call OpenAI with streaming using Chat Completions API
      api_key = ENV.fetch('OPENAI_API_KEY', nil) || ENV.fetch('CLACKY_OPENAI_API_KEY', nil)
      client = OpenAI::Client.new(access_token: api_key)

      Rails.logger.info "[ConversationOrchestrator] Streaming OpenAI with #{history.size} messages, tools: #{enable_tools}"

      # First call - may return tool calls
      tool_call_result = nil
      
      client.chat(
        parameters: {
          model: "gpt-4o",
          messages: history,
          temperature: 0.7,
          tools: enable_tools ? TOOL_DEFINITIONS : [],
          stream: proc { |chunk|
            Rails.logger.info "[ConversationOrchestrator] Stream chunk keys: #{chunk.keys}, choices: #{chunk['choices']&.first&.keys}"
            
            # Handle content delta - check multiple possible formats
            delta = nil
            if chunk.dig("choices", 0, "delta", "content")
              delta = chunk["choices"][0]["delta"]["content"]
            elsif chunk.dig("choices", 0, "message", "content")
              delta = chunk["choices"][0]["message"]["content"]
            end
            
            if delta.present?
              Rails.logger.info "[ConversationOrchestrator] Content delta: #{delta[0..50]}..."
              response_content += delta
              block.call({ delta: delta, conversation_id: conversation_id })
            end

            # Check for tool calls - need to accumulate arguments
            if chunk.dig("choices", 0, "delta", "tool_calls")
              tool_calls = chunk["choices"][0]["delta"]["tool_calls"]
              tool_calls.each do |tc|
                # Store tool call for later execution
                tool_call_result ||= {}
                tool_call_result[:id] = tc[:id] if tc[:id]
                tool_call_result[:name] = tc.dig(:function, :name) if tc.dig(:function, :name)
                tool_call_result[:arguments] ||= ""
                tool_call_result[:arguments] += (tc.dig(:function, :arguments) || "")
              end
            end
          }
        }
      )

      # If tool call detected, execute it and continue conversation
      if tool_call_result && tool_call_result[:name].present?
        Rails.logger.info "[ConversationOrchestrator] Tool call detected: #{tool_call_result[:name]} with args: #{tool_call_result[:arguments]}"
        
        # Parse arguments
        args = JSON.parse(tool_call_result[:arguments]) rescue {}
        
        # Execute tool
        tool_result = execute_tool(tool_call_result[:name], args)
        save_tool_message(tool_result) if tool_result
        
        # Add tool result to messages and get final response
        history << { role: "assistant", content: response_content }
        history << {
          role: "tool",
          tool_call_id: tool_call_result[:id],
          content: tool_result.is_a?(Hash) ? tool_result[:message] || tool_result.to_json : tool_result.to_s
        }
        
        # Broadcast tool execution
        broadcast_event('tool_execution_completed', { 
          tool: tool_call_result[:name], 
          result: tool_result 
        }) if stream_name
        
        # Get final response from AI
        response_content = ""
        client.chat(
          parameters: {
            model: "gpt-4o",
            messages: history,
            temperature: 0.7,
            stream: proc { |chunk|
              delta = chunk.dig("choices", 0, "delta", "content")
              if delta.present?
                response_content += delta
                block.call({ delta: delta, conversation_id: conversation_id })
              end
            }
          }
        )
      end

      # Save final assistant response
      save_assistant_message(response_content) if response_content.present?

      # Broadcast completion if streaming
      broadcast_completion(response_content) if stream_name

      Rails.logger.info "[ConversationOrchestrator] run_stream completed successfully"

      response_content
    rescue => e
      Rails.logger.error "[ConversationOrchestrator] run_stream failed: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")

      # Notify frontend if stream_name present
      broadcast_error("AI streaming failed: #{e.message}") if stream_name
      raise
    end
  end

  # Blocking call - returns full response
  def run_blocking
    Rails.logger.info "[ConversationOrchestrator] Starting run_blocking for conversation #{conversation_id}"

    response_content = ""

    begin
      # Save user message FIRST before building history
      save_user_message

      # Load conversation history (now includes current message)
      history = build_message_history

      # Call OpenAI with Chat Completions API
      api_key = ENV.fetch('OPENAI_API_KEY', nil) || ENV.fetch('CLACKY_OPENAI_API_KEY', nil)
      client = OpenAI::Client.new(access_token: api_key)

      Rails.logger.info "[ConversationOrchestrator] Calling OpenAI with #{history.size} messages, tools: #{enable_tools}"

      response = client.chat(
        parameters: {
          model: "gpt-4o",
          messages: history,
          temperature: 0.7,
          tools: enable_tools ? TOOL_DEFINITIONS : []
        }
      )

      Rails.logger.info "[ConversationOrchestrator] OpenAI response: #{response.inspect}"

      # Extract response content
      response_content = response.dig("choices", 0, "message", "content") || ""

      # Handle tool calls if present
      if enable_tools && response.dig("choices", 0, "message", "tool_calls")
        tool_calls = response["choices"][0]["message"]["tool_calls"]
        if tool_calls.present?
          Rails.logger.info "[ConversationOrchestrator] Processing #{tool_calls.size} tool calls"
          response_content = handle_tool_calls(tool_calls, response_content)
        end
      end

      # Save assistant response
      save_assistant_message(response_content) if response_content.present?

      # Broadcast completion if streaming
      broadcast_completion(response_content) if stream_name

      Rails.logger.info "[ConversationOrchestrator] run_blocking completed successfully"

      response_content
    rescue => e
      Rails.logger.error "[ConversationOrchestrator] run_blocking failed: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      broadcast_error(e.message) if stream_name
      raise Error, "AI processing failed: #{e.message}"
    end
  end

  private

  # Default system prompt
  def default_system_prompt
    <<~PROMPT
      You are Otto, a helpful AI assistant for a marketing platform.
      Your role is to help users with marketing tasks like:
      - Creating marketing campaigns
      - Generating social media content
      - Scheduling posts
      - Analyzing performance
      - Answering marketing questions

      Be concise, friendly, and helpful. Use emojis sparingly.
      Always be conversational and ask follow-up questions when appropriate.
    PROMPT
  end

  # Find the conversation (uses AiConversation with ai_messages)
  def conversation
    @conversation ||= AiConversation.find(conversation_id)
  rescue ActiveRecord::RecordNotFound
    raise Error, "Conversation not found: #{conversation_id}"
  end

  # Build message history for OpenAI
  def build_message_history
    messages = []

    # Add system prompt
    messages << { role: "system", content: system_prompt }

    # Add conversation history from ai_messages (includes current user message since we saved it first)
    conversation.get_recent_messages(10).each do |msg|
      messages << { role: msg.role, content: msg.content }
    end

    # Note: current user message is already saved to DB before this method is called
    # so we don't need to manually add it here

    messages
  end

  # Execute tool from Chat Completions chunk format
  def execute_tool_from_chunk(tool_call)
    return { error: "No user context" } unless user

    tool_call_id = tool_call[:id]
    tool_name = tool_call.dig(:function, :name)
    args_json = tool_call.dig(:function, :arguments)

    return nil if tool_name.blank?

    args = if args_json.is_a?(String)
      JSON.parse(args_json) rescue {}
    else
      args_json || {}
    end

    Rails.logger.info "[ConversationOrchestrator] Executing tool: #{tool_name} with args: #{args.inspect}"

    handler = VoiceToolHandler.new(user: user, execution_id: @execution_id)
    result = handler.execute(tool_name, args)

    { tool_call_id: tool_call_id, tool_name: tool_name, result: result }
  rescue => e
    Rails.logger.error "[ConversationOrchestrator] Tool execution error: #{e.message}"
    { error: e.message }
  end

  # Simple execute tool by name and args (used by new run_stream code)
  def execute_tool(tool_name, args)
    return { error: "No user context" } unless user

    Rails.logger.info "[ConversationOrchestrator] Executing tool: #{tool_name} with args: #{args.inspect}"

    handler = VoiceToolHandler.new(user: user, execution_id: @execution_id)
    result = handler.execute(tool_name, args)

    { tool_call_id: nil, tool_name: tool_name, result: result }
  rescue => e
    Rails.logger.error "[ConversationOrchestrator] Tool execution error: #{e.message}"
    { error: e.message }
  end

  # Handle tool calls from blocking response
  def handle_tool_calls(tool_calls, current_content)
    tool_results = []

    tool_calls.each do |tool_call|
      begin
        tool_result = execute_tool_from_chunk(tool_call)
        tool_results << tool_result
        save_tool_message(tool_result) if tool_result
      rescue => e
        Rails.logger.error "[ConversationOrchestrator] Tool execution failed: #{e.message}"
      end
    end

    # Return original content (tool results are saved separately)
    current_content
  end

  # Save user message to conversation
  def save_user_message
    conversation.ai_messages.create!(
      role: 'user',
      content: content,
      tokens_used: estimate_tokens(content)
    )
  rescue => e
    raise Error, "Failed to save user message: #{e.message}"
  end

  # Save assistant message to conversation
  def save_assistant_message(response_content)
    return if response_content.blank?

    conversation.ai_messages.create!(
      role: 'assistant',
      content: response_content,
      tokens_used: estimate_tokens(response_content)
    )
  rescue => e
    Rails.logger.error "[ConversationOrchestrator] Failed to save assistant message: #{e.message}"
  end

  # Save tool message to conversation
  def save_tool_message(tool_result)
    return if tool_result.blank?

    content = if tool_result.is_a?(Hash)
      tool_result[:result].is_a?(Hash) ? tool_result[:result].to_json : tool_result[:result].to_s
    else
      tool_result.to_s
    end

    conversation.ai_messages.create!(
      role: 'tool',
      content: content,
      tokens_used: estimate_tokens(content)
    )
  rescue => e
    Rails.logger.error "[ConversationOrchestrator] Failed to save tool message: #{e.message}"
  end

  # Estimate token count
  def estimate_tokens(text)
    (text.to_s.length / 4.0).ceil
  end

  # Broadcast event to ActionCable - broadcasts to BOTH conversation and user-level channels
  def broadcast_event(type, payload)
    return unless stream_name

    # Build event with flat structure for frontend compatibility
    event = {
      type: type,
      conversation_id: conversation_id,
      timestamp: Time.now.to_i
    }
    
    # Merge payload at top level for frontend
    event.merge!(payload)
    
    # Also extract content for frontend compatibility
    event[:content] = payload[:content] if payload[:content]
    
    # Broadcast to conversation-specific channel
    ActionCable.server.broadcast(stream_name, event)
    
    # Also broadcast to user-level channel (voice_chat_{user_id})
    # This ensures the frontend receives the response regardless of which channel it subscribed to
    if user
      user_stream = "voice_chat_#{user.id}"
      # Always broadcast to user channel for voice modality to ensure frontend receives it
      ActionCable.server.broadcast(user_stream, event)
    end
  rescue => e
    Rails.logger.error "[ConversationOrchestrator] Broadcast error: #{e.message}"
  end

  # Broadcast completion
  def broadcast_completion(content)
    broadcast_event(ASSISTANT_COMPLETE, { content: content })
  end

  # Broadcast error
  def broadcast_error(message)
    broadcast_event(ERROR, { error: message })
  end
end
