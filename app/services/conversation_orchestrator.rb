# frozen_string_literal: true

# ConversationOrchestrator - ChatGPT-style conversation service
#
# Responsibilities:
# - Maintain conversation memory (last 20-30 messages)
# - Stream responses progressively
# - Save all messages (never overwrite)
# - Determine intent (chat vs media generation)
# - Route to correct service
# - Handle voice and text identically
#
# Usage:
#   ConversationOrchestrator.process_message(
#     user: current_user,
#     conversation_id: 123,
#     content: "Hello!",
#     modality: "text", # or "voice"
#     stream_channel: "ai_chat_123"
#   )
class ConversationOrchestrator < ApplicationService
  # Constants
  MAX_HISTORY_MESSAGES = 15
  # Claude Model Configuration - use current Claude Sonnet 4 model
  CLAUDE_MODEL = "claude-sonnet-4-6"
  CHAT_TEMPERATURE = 0.8
  CHAT_MAX_TOKENS = 4000
  
  # Enable tools by default for chat
  DEFAULT_TOOLS_ENABLED = true
  
  attr_reader :user, :conversation, :content, :modality, :stream_channel, :fallback_channel, :tools_enabled

  def initialize(user:, conversation_id:, content:, modality: "text", stream_channel: nil, fallback_channel: nil, tools_enabled: nil)
    @user = user
    @conversation = find_or_create_conversation(conversation_id)
    @content = content
    @modality = modality
    @stream_channel = stream_channel
    @fallback_channel = fallback_channel
    @assistant_response = ""
    @tools_enabled = tools_enabled.nil? ? DEFAULT_TOOLS_ENABLED : tools_enabled
  end

  def self.process_message(**args)
    new(**args).call
  end

  def call
    Rails.logger.info "[ConversationOrchestrator] Processing message - conversation: #{conversation.id}, modality: #{modality}, stream: #{stream_channel.present?}"
    
    # Step 1: Save user message
    save_user_message
    
    # Step 2: Determine intent
    intent = detect_intent
    Rails.logger.info "[ConversationOrchestrator] Detected intent: #{intent}"
    
    # Step 3: Route based on intent
    case intent
    when :image
      handle_image_generation
    when :video
      handle_video_generation
    else
      handle_chat
    end
    
    # Step 4: Update conversation timestamp
    conversation.touch
    
    # Return result hash
    {
      conversation_id: conversation.id,
      response: @assistant_response
    }
  rescue => e
    Rails.logger.error "[ConversationOrchestrator] Error: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    
    error_message = "I apologize, but I encountered an error processing your message. Please try again."
    save_assistant_message(error_message)
    broadcast_error(error_message) if stream_channel
    
    {
      conversation_id: conversation.id,
      response: error_message
    }
  end

  private
def convert_tools_to_anthropic_format(tools)
  return nil if tools.nil?
  tools.map do |tool|
    func = tool[:function] || tool["function"]
    params = func[:parameters] || func["parameters"] || {}
    {
      name: func[:name] || func["name"],
      description: func[:description] || func["description"],
      input_schema: params
    }
  end
end
  def find_or_create_conversation(conversation_id)
    if conversation_id.present?
      user.ai_conversations.find_by(id: conversation_id) || create_new_conversation
    else
      create_new_conversation
    end
  end

  def create_new_conversation
    user.ai_conversations.create!(
      title: "Chat #{Time.current.strftime('%b %d, %I:%M %p')}",
      session_type: 'chat',
      metadata: { created_via: modality }
    )
  end

  def save_user_message
    conversation.ai_messages.create!(
      role: 'user',
      content: content,
      message_type: 'text',
      metadata: { modality: modality, created_at: Time.current }
    )
    
    Rails.logger.info "[ConversationOrchestrator] User message saved - conversation: #{conversation.id}"
  end

  def save_assistant_message(content)
    conversation.ai_messages.create!(
      role: 'assistant',
      content: content,
      message_type: 'text',
      metadata: { model: CLAUDE_MODEL, created_at: Time.current }
    )
    
    Rails.logger.info "[ConversationOrchestrator] Assistant message saved - conversation: #{conversation.id}, length: #{content.length}"
  end

  def detect_intent
    # Don't auto-detect intents - let the AI decide based on system prompt
    # This ensures the AI follows rules to ask questions before generating
    # The system prompt already has: "Always ask necessary information BEFORE generating content, images, videos, or campaigns"
    :chat
  end

  def handle_chat
    Rails.logger.info "[ConversationOrchestrator] Handling chat intent"
    
    # Build message history
    history = build_message_history
    
    Rails.logger.info "[ConversationOrchestrator] Message history built - #{history.size} messages"
    log_message_array(history)
    
    # Get tools if enabled
    raw_tools = @tools_enabled ? AiToolDefinitions.for_user(user) : nil
tools = convert_tools_to_anthropic_format(raw_tools)
    
    if tools.present?
      Rails.logger.info "[ConversationOrchestrator] Tools enabled: #{tools.size} available"
    end
    
    # Stream response from OpenAI
    if stream_channel
      stream_chat_response(history, tools)
    else
      blocking_chat_response(history, tools)
    end
  end

  def handle_image_generation
    Rails.logger.info "[ConversationOrchestrator] Handling image generation intent"
    
    # Respond conversationally first
    initial_response = "I'll generate that image for you. This will take a moment..."
    broadcast_content(initial_response) if stream_channel
    save_assistant_message(initial_response)
    
    # Trigger async image generation
    ImageGenerationJob.perform_later(
      conversation_id: conversation.id,
      prompt: content,
      user_id: user.id
    )
    
    @assistant_response = initial_response
  end

  def handle_video_generation
    Rails.logger.info "[ConversationOrchestrator] Handling video generation intent"
    
    # Respond conversationally first
    initial_response = "I'll create that video for you. Video generation typically takes 1-2 minutes, I'll notify you when it's ready."
    broadcast_content(initial_response) if stream_channel
    save_assistant_message(initial_response)
    
    # Trigger async video generation
    GenerateVideoJob.perform_later(
      prompt: content,
      user_id: user.id,
      conversation_id: conversation.id
    )
    
    @assistant_response = initial_response
  end

  def build_message_history
    # Fetch last N messages ordered by creation time
    recent_messages = conversation.ai_messages
      .order(created_at: :asc)
      .last(MAX_HISTORY_MESSAGES)
    
    # Build messages array for OpenAI
    # Use admin-defined system prompt from SiteSettings with user context
    base_prompt = SiteSetting.ai_system_prompt
    
    # Add user-specific subscription info
    if user
      plan = user.subscription_plan || 'Starter'
      plan_data = SubscriptionPlan.find_by(name: plan)
      credits = plan_data&.credits || 40
      
      user_context = <<~CONTEXT

## CURRENT USER CONTEXT
- User: #{user.name || user.email}
- Subscription Plan: #{plan}
- Monthly Credits: #{credits}

REMEMBER: You must enforce the #{plan} plan limits for this user!
CONTEXT
      
      system_prompt = base_prompt + user_context
    else
      system_prompt = base_prompt
    end
    
    @system_prompt = system_prompt
messages = []
    
    recent_messages.each do |msg|
      # Skip tool messages without valid metadata
      if msg.role == 'tool'
        tool_call_id = msg.metadata&.dig(:tool_call_id)
        tool_name = msg.metadata&.dig(:tool_name)
        
        # Only include tool messages with valid tool_call_id and name
        if tool_call_id.present? && tool_name.present?
          messages << {
            role: "tool",
            tool_call_id: tool_call_id,
            name: tool_name,
            content: msg.content || ""
          }
        end
      else
        # Skip messages without content
        if msg.content.present?
          messages << {
            role: msg.role,
            content: msg.content
          }
        end
      end
    end
    
    messages
  end

  def stream_chat_response(history, tools = nil)
    Rails.logger.info "[ConversationOrchestrator] Streaming chat response"
    
    # Log the exact message array being sent to OpenAI
    Rails.logger.info "[ConversationOrchestrator] Chat message array: #{history.to_json}"
    Rails.logger.info "[ConversationOrchestrator] Calling Claude model: #{CLAUDE_MODEL}, temperature: #{CHAT_TEMPERATURE}, max_tokens: #{CHAT_MAX_TOKENS}"
    
    api_key = ENV['ANTHROPIC_API_KEY'].presence || ENV['API_KEY_ANTHROPIC'].presence
    unless api_key
      error_msg = "Anthropic API key not configured"
      Rails.logger.error "[ConversationOrchestrator] #{error_msg}"
      broadcast_error(error_msg)
      return error_msg
    end
    
    client = Anthropic::Client.new(api_key: api_key)
    
    @assistant_response = ""
    
    # Build API parameters
    api_params = {
      model: CLAUDE_MODEL,
      system: history.find { |m| m[:role] == "system" }&.dig(:content) || "",
messages: history.reject { |m| m[:role] == "system" },
      temperature: CHAT_TEMPERATURE,
      max_tokens: CHAT_MAX_TOKENS
    }
    api_params[:tools] = tools if tools.present?
    
    # Track tool calls if tools are enabled
    tool_calls_buffer = {}
    has_tool_calls = false
    
    client.messages.stream(
  **api_params,
  stream: proc { |chunk, _bytesize|
        stream: proc { |chunk, _bytesize|
          Rails.logger.debug "[ConversationOrchestrator] Stream chunk received"
          
          # Handle content delta (Anthropic format: chunk.delta.text)
          delta = chunk.delta&.text
          
          if delta.present?
            @assistant_response += delta
            broadcast_content(delta)
          end
          
          # Handle tool use deltas (Anthropic format: chunk.delta.partial_tool_use)
          if tools.present? && chunk.delta&.partial_tool_use
            tc = chunk.delta.partial_tool_use
            idx = tc.id&.hash || tool_calls_buffer.size
            tool_calls_buffer[idx] ||= { "id" => tc.id || "", "function" => { "name" => "", "arguments" => "" } }
            tool_calls_buffer[idx]["id"] = tc.id if tc.id
            tool_calls_buffer[idx]["function"]["name"] += tc.name.to_s if tc.name
            tool_calls_buffer[idx]["function"]["arguments"] += tc.input.to_s if tc.input
            has_tool_calls = true
          end
        }
      )
      
      Rails.logger.info "[ConversationOrchestrator] Streaming complete - total length: #{@assistant_response.length}"
      
      # Handle tool calls if present
      if has_tool_calls && tool_calls_buffer.present?
        tool_calls = tool_calls_buffer.values
        Rails.logger.info "[ConversationOrchestrator] Tool calls detected: #{tool_calls.size}"
        
        # Execute tools and continue conversation
        final_response = handle_tool_calls_and_continue(history, tool_calls, :stream)
        return final_response
      end
      
      # Save complete response
      save_assistant_message(@assistant_response)
      
      # Broadcast completion
      broadcast_completion
      
      @assistant_response
    rescue => e
      Rails.logger.error "[ConversationOrchestrator] Streaming error: #{e.message}"
      error_msg = "I encountered an error while generating the response. Please try again."
      broadcast_error(error_msg)
      save_assistant_message(error_msg)
      error_msg
    end
  end

  def blocking_chat_response(history, tools = nil)
    Rails.logger.info "[ConversationOrchestrator] Blocking chat response"
    
    # Log the exact message array being sent to OpenAI
    Rails.logger.info "[ConversationOrchestrator] Chat message array: #{history.to_json}"
    Rails.logger.info "[ConversationOrchestrator] Calling OpenAI model: #{CHAT_MODEL}, temperature: #{CHAT_TEMPERATURE}, max_tokens: #{CHAT_MAX_TOKENS}"
    
    api_key = ENV['ANTHROPIC_API_KEY'].presence || ENV['API_KEY_ANTHROPIC'].presence
    unless api_key
      error_msg = "Anthropic API key not configured"
      Rails.logger.error "[ConversationOrchestrator] #{error_msg}"
      return error_msg
    end
    
    client = Anthropic::Client.new(api_key: api_key)
    
    begin
      response = client.messages.create(
  max_tokens: CHAT_MAX_TOKENS,
  model: CLAUDE_MODEL,
  system: history.find { |m| m[:role] == "system" }&.dig(:content) || "",
  messages: history.reject { |m| m[:role] == "system" },
  temperature: CHAT_TEMPERATURE,
  tools: tools.presence
      )
      # Check for tool uses in response (Anthropic format)
      message = response
      tool_uses = message.content.select { |c| c.type == "tool_use" }
      
      if tool_uses.present? && tool_uses.any?
        Rails.logger.info "[ConversationOrchestrator] Tool calls detected: #{tool_uses.size}"
        
        # Save the assistant's initial response if content exists
        text_content = message.content.find { |c| c.type == "text" }
        content = text_content&.text
        if content.present?
          @assistant_response = content
          save_assistant_message(content)
          broadcast_content(content) if stream_channel
        end
        
        # Convert Anthropic tool_use format to OpenAI-like format for compatibility
        tool_calls = tool_uses.map do |tc|
  {
    "id" => tc.id,
    "name" => tc.name,
    "input" => tc.input
  }
        end
        
        # Execute tools and continue conversation
        final_response = handle_tool_calls_and_continue(history, tool_calls, :blocking)
        return final_response
      end
      
      # Get text content
      text_content = message.content.find { |c| c.type == "text" }
      @assistant_response = text_content&.text || ""
      
      Rails.logger.info "[ConversationOrchestrator] Response received - length: #{@assistant_response.length}"
      
      # Save response
      save_assistant_message(@assistant_response)
      
      @assistant_response
    rescue => e
      Rails.logger.error "[ConversationOrchestrator] Blocking error: #{e.message}"
      error_msg = "I encountered an error while generating the response. Please try again."
      save_assistant_message(error_msg)
      error_msg
    end
  end

  def broadcast_content(delta)
    return unless stream_channel
    
    # Broadcast to primary channel
    ActionCable.server.broadcast(stream_channel, {
      type: 'content_delta',
      delta: delta,
      conversation_id: conversation.id
    })
    
    # Also broadcast to fallback channel if different
    if fallback_channel && fallback_channel != stream_channel
      ActionCable.server.broadcast(fallback_channel, {
        type: 'content_delta',
        delta: delta,
        conversation_id: conversation.id
      })
    end
  end

  def broadcast_completion
    return unless stream_channel
    
    ActionCable.server.broadcast(stream_channel, {
      type: 'completion',
      conversation_id: conversation.id,
      full_content: @assistant_response
    })
    
    # Also broadcast to fallback channel if different
    if fallback_channel && fallback_channel != stream_channel
      ActionCable.server.broadcast(fallback_channel, {
        type: 'completion',
        conversation_id: conversation.id,
        full_content: @assistant_response
      })
    end
  end

  def broadcast_error(message)
    return unless stream_channel
    
    ActionCable.server.broadcast(stream_channel, {
      type: 'error',
      error: message,
      conversation_id: conversation.id
    })
    
    # Also broadcast to fallback channel if different
    if fallback_channel && fallback_channel != stream_channel
      ActionCable.server.broadcast(fallback_channel, {
        type: 'error',
        error: message,
        conversation_id: conversation.id
      })
    end
  end

  def log_message_array(messages)
    Rails.logger.info "[ConversationOrchestrator] Message array sent to Claude:"
    messages.each_with_index do |msg, idx|
      content_preview = msg[:content].to_s[0..100]
      Rails.logger.info "  [#{idx}] role=#{msg[:role]}, content=#{content_preview}..."
    end
    Rails.logger.info "[ConversationOrchestrator] Model: #{CLAUDE_MODEL}, Temperature: #{CHAT_TEMPERATURE}, Max tokens: #{CHAT_MAX_TOKENS}"
  end
  
  # Handle tool calls, execute them, and continue conversation
  def handle_tool_calls_and_continue(history, tool_calls, mode)
    Rails.logger.info "[ConversationOrchestrator] Handling #{tool_calls.size} tool calls"
    
    # Add assistant message with tool calls to history
    history_after_tool_call = history.dup
    history_after_tool_call << {
      role: "assistant",
      content: @assistant_response || "",
      tool_calls: tool_calls
    }
    
    # Execute each tool and collect results
    tool_results = []
    tool_calls.each do |tool_call|
      tool_id = tool_call["id"]
      function_name = tool_call["name"] || tool_call.dig("function", "name")
arguments_json = tool_call["input"]&.to_json || tool_call.dig("function", "arguments")
      
      Rails.logger.info "[ConversationOrchestrator] Executing tool: #{function_name} with args: #{arguments_json}"
      
      # Check if HIGH risk tool - require confirmation before executing
      risk_level = AiToolDefinitions.risk_level(function_name)
      if risk_level == :high
        Rails.logger.info "[ConversationOrchestrator] HIGH risk tool #{function_name} - requires user confirmation"
        
        # Broadcast confirmation request to frontend
        broadcast_tool_confirmed(function_name, { requires_confirmation: true, message: "This action requires your confirmation" }) if stream_channel
        
        # Add error to history instead of executing
        error_result = { error: "This action (#{function_name}) requires user confirmation before execution." }
        save_tool_message(function_name, error_result, tool_id)
        history_after_tool_call << {
          role: "tool",
          tool_call_id: tool_id,
          name: function_name,
          content: error_result.to_json
        }
        tool_results << { tool: function_name, result: error_result, success: false }
        next
      end
      
      begin
        # Parse arguments and convert string keys to symbols for Ruby keyword arguments
        # Handle empty or malformed JSON
        raw_arguments = begin
          JSON.parse(arguments_json) rescue {}
        end
        
        # Check if arguments_json was empty or invalid
        if arguments_json.blank? || raw_arguments.empty?
          Rails.logger.warn "[ConversationOrchestrator] Empty or invalid arguments for tool: #{function_name}"
          error_result = { error: "No arguments provided for #{function_name}" }
          save_tool_message(function_name, error_result, tool_id)
          history_after_tool_call << {
            role: "tool",
            tool_call_id: tool_id,
            name: function_name,
            content: error_result.to_json
          }
          tool_results << { tool: function_name, result: error_result, success: false }
          next
        end
        
        # Convert string keys to symbols using recursive approach
        arguments = convert_keys_to_symbols(raw_arguments)
        
        Rails.logger.info "[ConversationOrchestrator] Parsed arguments: #{arguments.inspect}"
        
        # Validate required arguments exist
        required_args = required_tool_arguments(function_name)
        missing_args = required_args - arguments.keys.map(&:to_sym)
        if missing_args.any?
          Rails.logger.warn "[ConversationOrchestrator] Missing required arguments: #{missing_args.inspect}"
          error_result = { error: "Missing required arguments: #{missing_args.join(', ')}" }
          save_tool_message(function_name, error_result, tool_id)
          history_after_tool_call << {
            role: "tool",
            tool_call_id: tool_id,
            name: function_name,
            content: error_result.to_json
          }
          tool_results << { tool: function_name, result: error_result, success: false }
          next
        end
        
        # Execute tool using Ai::ToolExecutor
        result = Ai::ToolExecutor.call(
          function_name,
          arguments,
          user: user
        )
        
        # Save tool message to conversation
        save_tool_message(function_name, result, tool_id)
        
        # Add tool result to history
        history_after_tool_call << {
          role: "tool",
          tool_call_id: tool_id,
          name: function_name,
          content: result.to_json
        }
        
        tool_results << { tool: function_name, result: result, success: true }
        
        # Broadcast tool execution to frontend
        broadcast_tool_result(function_name, result) if stream_channel
        
      rescue => e
        Rails.logger.error "[ConversationOrchestrator] Tool execution failed: #{e.message}"
        
        error_result = { error: e.message }
        
        # Save tool error
        save_tool_message(function_name, error_result, tool_id)
        
        history_after_tool_call << {
          role: "tool",
          tool_call_id: tool_id,
          name: function_name,
          content: error_result.to_json
        }
        
        tool_results << { tool: function_name, result: error_result, success: false }
      end
    end
    
    # Continue conversation with tool results
    Rails.logger.info "[ConversationOrchestrator] Continuing conversation with tool results"
    
    if mode == :stream
      continue_streaming(history_after_tool_call)
    else
      continue_blocking(history_after_tool_call)
    end
  end
  
  # Continue with streaming after tool execution
  def continue_streaming(history)
    # Filter and validate messages before sending to OpenAI
    valid_messages = history.filter do |msg|
      msg.is_a?(Hash) && msg[:role].present?
    end.map do |msg|
      filtered = msg.dup
      # Remove nil values
      filtered.each { |k, v| filtered[k] = nil if v.nil? }
      filtered
    end
    
    Rails.logger.info "[ConversationOrchestrator] Continuing streaming with #{valid_messages.size} messages"
    Rails.logger.info "[ConversationOrchestrator] Validated message history: #{valid_messages.to_json[0..500]}..."
    
    api_key = ENV.fetch('ANTHROPIC_API_KEY')
    client = Anthropic::Client.new(api_key: api_key)
    
    @assistant_response = ""
    
    client.messages.stream(
      model: CLAUDE_MODEL,
      messages: valid_messages,
      temperature: CHAT_TEMPERATURE,
      max_tokens: CHAT_MAX_TOKENS,
      stream: proc { |chunk, _bytesize|
        # Handle content delta (Anthropic format)
        delta = chunk.delta&.text
        
        if delta.present?
          @assistant_response += delta
          broadcast_content(delta)
        end
      }
    )
    
    save_assistant_message(@assistant_response)
    broadcast_completion
    
    @assistant_response
  rescue Anthropic::Errors::Error => e
    Rails.logger.error "[ConversationOrchestrator] Anthropic API error: #{e.message}"
    error_msg = "Error communicating with AI: #{e.message}"
    save_assistant_message(error_msg)
    error_msg
  rescue => e
    Rails.logger.error "[ConversationOrchestrator] Continue streaming error: #{e.message}"
    Rails.logger.error "[ConversationOrchestrator] Backtrace: #{e.backtrace.first(5).join("\n")}"
    error_msg = "Error processing tool results. Please try again."
    save_assistant_message(error_msg)
    error_msg
  end
  
  # Continue with blocking call after tool execution
  def continue_blocking(history)
    api_key = ENV.fetch('ANTHROPIC_API_KEY')
    client = Anthropic::Client.new(api_key: api_key)
    
    response = client.messages.create(
      model: CLAUDE_MODEL,
      messages: history,
      temperature: CHAT_TEMPERATURE,
      max_tokens: CHAT_MAX_TOKENS
    )
    
    # Get text content (Anthropic format)
    text_content = response.content.find { |c| c.type == "text" }
    @assistant_response = text_content&.text || ""
    save_assistant_message(@assistant_response)
    
    @assistant_response
  rescue => e
    Rails.logger.error "[ConversationOrchestrator] Continue blocking error: #{e.message}"
    error_msg = "Error processing tool results. Please try again."
    save_assistant_message(error_msg)
    error_msg
  end
  
  def save_tool_message(tool_name, result, tool_call_id = nil)
    conversation.ai_messages.create!(
      role: 'tool',
      content: result.is_a?(Hash) ? result.to_json : result.to_s,
      message_type: 'text',
      metadata: { tool_name: tool_name, tool_call_id: tool_call_id, created_at: Time.current }
    )
  end
  
  def broadcast_tool_result(tool_name, result)
    return unless stream_channel
    
    ActionCable.server.broadcast(stream_channel, {
      type: 'tool_result',
      tool_name: tool_name,
      result: result,
      conversation_id: conversation.id
    })
    
    # Also broadcast to fallback channel if different
    if fallback_channel && fallback_channel != stream_channel
      ActionCable.server.broadcast(fallback_channel, {
        type: 'tool_result',
        tool_name: tool_name,
        result: result,
        conversation_id: conversation.id
      })
    end
  end
  
  # Get required arguments for a tool
  def required_tool_arguments(tool_name)
    case tool_name.to_s
    when 'generate_image'
      [:prompt]
    when 'generate_video'
      [:prompt]
    when 'create_post'
      [:content]
    when 'schedule_post'
      [:content, :scheduled_at]
    when 'publish_post'
      [:content]
    else
      []
    end
  end
  
  # Recursively convert string keys to symbol keys
  def convert_keys_to_symbols(hash)
    hash.each_with_object({}) do |(key, value), result|
      new_key = key.is_a?(String) ? key.to_sym : key
      result[new_key] = value.is_a?(Hash) ? convert_keys_to_symbols(value) : value
    end
  end
end
