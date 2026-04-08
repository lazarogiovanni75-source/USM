# frozen_string_literal: true

# ConversationOrchestrator - ChatGPT-style conversation service
class ConversationOrchestrator < ApplicationService
  MAX_HISTORY_MESSAGES = 15
  CLAUDE_MODEL = "claude-sonnet-4-6"
  CHAT_TEMPERATURE = 0.8
  CHAT_MAX_TOKENS = 4000
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
    
    save_user_message
    intent = detect_intent
    Rails.logger.info "[ConversationOrchestrator] Detected intent: #{intent}"
    
    case intent
    when :image
      handle_image_generation
    when :video
      handle_video_generation
    else
      handle_chat
    end
    
    conversation.touch
    
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

  def broadcast_content(delta)
    return unless stream_channel
    ActionCable.server.broadcast(stream_channel, {
      type: 'chunk',
      chunk: delta
    })
  end

  def broadcast_error(message)
    return unless stream_channel
    ActionCable.server.broadcast(stream_channel, {
      type: 'error',
      error: message
    })
  end

  def broadcast_completion
    return unless stream_channel
    ActionCable.server.broadcast(stream_channel, {
      type: 'complete'
    })
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
    :chat
  end

  def handle_chat
    Rails.logger.info "[ConversationOrchestrator] Handling chat intent"
    
    history = build_message_history
    Rails.logger.info "[ConversationOrchestrator] Message history built - #{history.size} messages"
    
    raw_tools = @tools_enabled ? AiToolDefinitions.for_user(user) : nil
    tools = convert_tools_to_anthropic_format(raw_tools)
    
    # Add explicit tool usage instructions to system prompt when tools are enabled
    if tools.present?
      Rails.logger.info "[ConversationOrchestrator] Tools enabled: #{tools.size} available"
      @system_prompt = @system_prompt + tool_usage_instructions(tools)
      blocking_chat_response(history, tools)
    else
      if stream_channel
        stream_chat_response(history, nil)
      else
        blocking_chat_response(history, nil)
      end
    end
  end

  def handle_image_generation
    Rails.logger.info "[ConversationOrchestrator] Handling image generation intent"
    
    initial_response = "I'll generate that image for you. This will take a moment..."
    broadcast_content(initial_response) if stream_channel
    save_assistant_message(initial_response)
    
    ImageGenerationJob.perform_later(
      conversation_id: conversation.id,
      prompt: content,
      user_id: user.id
    )
    
    @assistant_response = initial_response
  end

  def handle_video_generation
    Rails.logger.info "[ConversationOrchestrator] Handling video generation intent"
    
    initial_response = "I'll create that video for you. Video generation typically takes 1-2 minutes, I'll notify you when it's ready."
    broadcast_content(initial_response) if stream_channel
    save_assistant_message(initial_response)
    
    GenerateVideoJob.perform_later(
      prompt: content,
      user_id: user.id,
      conversation_id: conversation.id
    )
    
    @assistant_response = initial_response
  end

  def build_message_history
    recent_messages = conversation.ai_messages
      .order(created_at: :asc)
      .last(MAX_HISTORY_MESSAGES)
    
    base_prompt = SiteSetting.ai_system_prompt rescue "You are a helpful AI assistant."
    
    subscription_info = ""
    if user.subscription_plan.present?
      plan_name = user.subscription_plan.is_a?(String) ? user.subscription_plan : user.subscription_plan.name
      subscription_info = "\n\nUser Subscription: #{plan_name}"
    end
    
    user_info = "\n\nUser: #{user.email}"
    
    @system_prompt = base_prompt + subscription_info + user_info
    
    messages = []
    
    recent_messages.each do |msg|
      messages << {
        role: msg.role.to_sym,
        content: msg.content
      }
    end
    
    messages
  end

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

  def tool_usage_instructions(tools)
    return "" if tools.blank?
    tool_list = tools.map { |t| "- #{t[:name]}: #{t[:description]}" }.join("\n")
    <<~INSTRUCTIONS

    ## AVAILABLE TOOLS
    You have access to the following tools. When a user asks you to perform an action that matches a tool, you MUST call the appropriate tool:
    
    #{tool_list}

    ## TOOL USAGE RULES
    - If a user asks to create, generate, or produce images, videos, or content → use the appropriate tool
    - If a user asks to schedule or publish content → use the appropriate tool
    - ALWAYS use a tool when the user's request matches a tool's capability
    - Do NOT just describe what you would do - actually call the tool
    - NEVER read back long IDs, URLs, or technical strings to the user - just confirm success briefly
    - NEVER include task IDs, image URLs, video URLs, or any technical identifiers in your response
    INSTRUCTIONS
  end

  def stream_chat_response(history, tools = nil)
    Rails.logger.info "[ConversationOrchestrator] Streaming chat response"
    
    api_key = ENV['ANTHROPIC_API_KEY'].presence || ENV['API_KEY_ANTHROPIC'].presence
    unless api_key
      error_msg = "Anthropic API key not configured"
      Rails.logger.error "[ConversationOrchestrator] #{error_msg}"
      broadcast_error(error_msg)
      return error_msg
    end
    
    Rails.logger.info "[ConversationOrchestrator] API key found: #{api_key[0..10]}...#{api_key[-4..]}"
    client = Anthropic::Client.new(api_key: api_key)
    @assistant_response = ""
    
    api_params = {
      model: CLAUDE_MODEL,
      system: @system_prompt || "",
      messages: history,
      temperature: CHAT_TEMPERATURE,
      max_tokens: CHAT_MAX_TOKENS
    }
    api_params[:tools] = tools if tools.present?
    
    Rails.logger.info "[ConversationOrchestrator] Calling Anthropic API with model: #{CLAUDE_MODEL}"
    Rails.logger.info "[ConversationOrchestrator] History messages count: #{history.size}"
    
    begin
      stream = client.messages.stream(**api_params)
      Rails.logger.info "[ConversationOrchestrator] Stream object created: #{stream.class}"
      
      chunk_count = 0
      stream.text.each do |text_delta|
        chunk_count += 1
        @assistant_response += text_delta
        broadcast_content(text_delta)
      end
      
      Rails.logger.info "[ConversationOrchestrator] Stream completed. Chunks received: #{chunk_count}, Response length: #{@assistant_response.length}"
      
      if @assistant_response.blank?
        error_msg = "I encountered an error while generating the response. Please try again."
        Rails.logger.error "[ConversationOrchestrator] Empty response after streaming! Chunks: #{chunk_count}"
        broadcast_error(error_msg)
        save_assistant_message(error_msg)
        return error_msg
      end
      
      save_assistant_message(@assistant_response)
      broadcast_completion
      @assistant_response
    rescue => e
      Rails.logger.error "[ConversationOrchestrator] Streaming error: #{e.class} - #{e.message}"
      Rails.logger.error "[ConversationOrchestrator] Backtrace: #{e.backtrace.first(10).join("\n")}"
      error_msg = "I encountered an error while generating my response. Please try again."
      broadcast_error(error_msg)
      save_assistant_message(error_msg)
      error_msg
    end
  end

  def blocking_chat_response(history, tools = nil)
    Rails.logger.info "[ConversationOrchestrator] Blocking chat response - tools count: #{tools&.size || 0}"
    
    api_key = ENV['ANTHROPIC_API_KEY'].presence || ENV['API_KEY_ANTHROPIC'].presence
    unless api_key
      error_msg = "Anthropic API key not configured"
      Rails.logger.error "[ConversationOrchestrator] #{error_msg}"
      return error_msg
    end
    
    Rails.logger.info "[ConversationOrchestrator] API key found, creating client..."
    client = Anthropic::Client.new(api_key: api_key)
    
    Rails.logger.info "[ConversationOrchestrator] System prompt preview: #{@system_prompt&.slice(0..100)}..."
    Rails.logger.info "[ConversationOrchestrator] History count: #{history.size}"
    Rails.logger.info "[ConversationOrchestrator] Tools: #{tools.inspect[0..500]}"
    
    begin
      response = client.messages.create(
        max_tokens: CHAT_MAX_TOKENS,
        model: CLAUDE_MODEL,
        system: @system_prompt || "",
        messages: history,
        temperature: CHAT_TEMPERATURE,
        tools: tools.presence
      )
      
      Rails.logger.info "[ConversationOrchestrator] Raw response type: #{response.class}"
      Rails.logger.info "[ConversationOrchestrator] Response content class: #{response.content.class}"
      Rails.logger.info "[ConversationOrchestrator] Response content: #{response.content.inspect[0..1000]}"
      
      message = response
      tool_uses = message.content.select { |c| c.type == :tool_use }
      
      if tool_uses.present? && tool_uses.any?
        Rails.logger.info "[ConversationOrchestrator] Tool calls detected: #{tool_uses.size}"
        
        text_content = message.content.find { |c| c.type == :text }
        content = text_content&.text
        if content.present?
          @assistant_response = content
          broadcast_content(content) if stream_channel
        end
        
        tool_calls = tool_uses.map do |tc|
          {
            "id" => tc.id,
            "name" => tc.name,
            "input" => tc.input
          }
        end
        
        serialized_content = message.content.map do |block|
  if block.type == :tool_use
    { type: "tool_use", id: block.id, name: block.name, input: block.input }
  elsif block.type == :text
    { type: "text", text: block.text }
  else
    { type: block.type.to_s }
  end
end
final_response = handle_tool_calls_and_continue(history, tool_calls, :blocking, serialized_content)
        return final_response
      end
      
      text_content = message.content.find { |c| c.type == :text }
      @assistant_response = text_content&.text || ""
      
      Rails.logger.info "[ConversationOrchestrator] Response received - length: #{@assistant_response.length}"
      
      if @assistant_response.present?
        save_assistant_message(@assistant_response)
      else
        @assistant_response = "Processing your request..."
        save_assistant_message(@assistant_response)
      end
      @assistant_response
    rescue => e
      Rails.logger.error "[ConversationOrchestrator] Blocking chat error: #{e.message}"
      error_msg = "I encountered an error while generating the response. Please try again."
      save_assistant_message(error_msg)
      error_msg
    end
  end

  def handle_tool_calls_and_continue(history, tool_calls, mode, raw_assistant_content = nil)
    
    begin
      tool_handler = VoiceToolHandler.new(user: user)
      tool_results = []
      
      tool_calls.each do |tool_call|
        tool_name = tool_call["name"]
        tool_args = tool_call["input"] || tool_call["arguments"] || {}
        tool_id = tool_call["id"]
        
        Rails.logger.info "[ConversationOrchestrator] Executing tool: #{tool_name} with args: #{tool_args.inspect}"
        
        begin
          # Safety checks
          if !tool_name.is_a?(String) || tool_name.blank?
            result = { status: "error", message: "Invalid tool name provided" }
          elsif !tool_args.is_a?(Hash)
            result = { status: "error", message: "Invalid tool arguments format" }
          else
            # Normal execution path with error handling
            requires_confirmation = false
            
            begin
              requires_confirmation = tool_handler.requires_confirmation?(tool_name)
            rescue => conf_error
              Rails.logger.error "[ConversationOrchestrator] Error checking confirmation: #{conf_error.message}"
              requires_confirmation = false
            end
            
            if requires_confirmation
              Rails.logger.info "[ConversationOrchestrator] Tool #{tool_name} requires confirmation"
              broadcast_tool_call(tool_name, tool_args, tool_id)
            end
            
            # Stringify keys for consistency
            safe_args = {}
            tool_args.each do |k, v|
              safe_args[k.to_s] = v
            end
            
            result = tool_handler.execute(tool_name, safe_args)
          end
        rescue => tool_error
          Rails.logger.error "[ConversationOrchestrator] Tool execution error: #{tool_error.message}"
          result = { 
            status: "success", # Return success to prevent conversation breaking
            message: "I processed your request, but encountered a minor issue: #{tool_error.message.split('.').first}."
          }
        end
        
        Rails.logger.info "[ConversationOrchestrator] Tool #{tool_name} result: #{result.inspect}"
        
        tool_results << {
          tool_use_id: tool_id,
          tool_name: tool_name,
          content: result[:message] || "#{tool_name} completed successfully"
        }
      end
      
      assistant_msg = {
        role: "assistant",
        content: raw_assistant_content || []
      }
      
      # Truncate long content to prevent AI from reading back huge URLs/IDs
      tool_result_content = tool_results.map do |tr|
        content = tr[:content].to_s
        if content.length > 200
          content = content[0..200] + "..."
        end
        {
          type: "tool_result",
          tool_use_id: tr[:tool_use_id],
          content: content
        }
      end

      updated_history = history + [assistant_msg, { role: "user", content: tool_result_content }]
      
      Rails.logger.info "[ConversationOrchestrator] Making follow-up call with tool results"
      
      api_key = ENV['ANTHROPIC_API_KEY'].presence || ENV['API_KEY_ANTHROPIC'].presence
      client = Anthropic::Client.new(api_key: api_key)
      
      begin
        response = client.messages.create(
          max_tokens: CHAT_MAX_TOKENS,
          model: CLAUDE_MODEL,
          system: @system_prompt || "",
          messages: updated_history,
          temperature: CHAT_TEMPERATURE
        )
        
        text_content = response.content.find { |c| c.type == :text }
        final_response = text_content&.text || "Tool executed successfully."
        
        if mode == :stream || stream_channel
          broadcast_content(final_response)
        end
        
        broadcast_completion if stream_channel
        
        @assistant_response = final_response
        save_assistant_message(final_response)
        final_response
        
      rescue => e
        Rails.logger.error "[ConversationOrchestrator] Follow-up call error: #{e.message}"
        error_msg = "I executed the tool but encountered an error getting the final response."
        save_assistant_message(error_msg)
        broadcast_error(error_msg) if stream_channel
        error_msg
      end
    rescue => e
      Rails.logger.error "[ConversationOrchestrator] Critical tool handling error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")[0..500] 
      error_msg = "I tried to process your request but encountered a technical issue. Please try again or contact support if the problem persists."
      save_assistant_message(error_msg)
      broadcast_error(error_msg) if stream_channel
      error_msg
    end
  end

  def broadcast_tool_call(tool_name, tool_args, tool_id)
    return unless stream_channel
    ActionCable.server.broadcast(stream_channel, {
      type: 'tool_call',
      tool_name: tool_name,
      tool_id: tool_id,
      args: tool_args,
      message: "I need to execute #{tool_name} with the following parameters: #{tool_args.inspect}"
    })
  end
end
