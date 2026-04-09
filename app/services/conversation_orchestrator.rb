# frozen_string_literal: true

# ConversationOrchestrator - ChatGPT-style conversation service
class ConversationOrchestrator < ApplicationService
  MAX_HISTORY_MESSAGES = 15
  CLAUDE_MODEL = "claude-sonnet-4-6"
  CHAT_TEMPERATURE = 0.8
  CHAT_MAX_TOKENS = 4000
  DEFAULT_TOOLS_ENABLED = false
  
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
    Rails.logger.info "[ConversationOrchestrator] === START ==="
    Rails.logger.info "[ConversationOrchestrator] user: #{user&.id} (#{user&.email})"
    Rails.logger.info "[ConversationOrchestrator] conversation: #{conversation.id}, modality: #{modality}, stream: #{stream_channel.present?}"
    
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
    Rails.logger.error "[ConversationOrchestrator] Error: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    
    error_message = "I apologize, but I encountered an error processing your message. [#{e.class}: #{e.message}]"
    begin
      save_assistant_message(error_message)
    rescue => save_error
      Rails.logger.error "[ConversationOrchestrator] Failed to save error message: #{save_error.message}"
    end
    broadcast_error(error_message) if stream_channel
    
    {
      conversation_id: conversation&.id,
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
    # Use model's raw SQL create method
    AiConversation.create!(
      user: user,
      title: "Chat #{Time.current.strftime('%b %d, %I:%M %p')}",
      session_type: 'chat',
      metadata: { created_via: modality }
    )
  end

  def save_user_message
    # Use model's raw SQL create method
    AiMessage.create!(
      ai_conversation: conversation,
      role: 'user',
      content: content,
      message_type: 'text',
      metadata: { modality: modality, created_at: Time.current }
    )
    Rails.logger.info "[ConversationOrchestrator] User message saved - conversation: #{conversation.id}"
  end

  def save_assistant_message(content)
    # Use model's raw SQL create method
    AiMessage.create!(
      ai_conversation: conversation,
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

Available tools you can use:
#{tool_list}

When you want to use a tool, respond with a tool use block in your response.
INSTRUCTIONS
  end

  def stream_chat_response(history, tools)
    full_response = ""
    
    LlmService.stream anthropic_messages: history, model: CLAUDE_MODEL do |chunk|
      full_response += chunk
      broadcast_content(chunk)
    end
    
    save_assistant_message(full_response)
    broadcast_completion
    @assistant_response = full_response
  rescue => e
    Rails.logger.error "[ConversationOrchestrator] Stream error: #{e.message}"
    broadcast_error("Stream failed: #{e.message}")
    raise
  end

  def blocking_chat_response(history, tools)
    response = LlmService.complete(
      messages: history,
      model: CLAUDE_MODEL,
      max_tokens: CHAT_MAX_TOKENS,
      temperature: CHAT_TEMPERATURE,
      tools: tools
    )
    
    response_content = response.dig(:content) || response[:text] || ""
    
    if response[:stop_reason] == 'tool_use'
      Rails.logger.info "[ConversationOrchestrator] Tool use detected"
      handle_tool_calls(response[:content], history)
    else
      save_assistant_message(response_content)
      @assistant_response = response_content
    end
  end

  def handle_tool_calls(tool_calls, history)
    tool_calls.each do |tool_call|
      executor = AiToolExecutor.new(user: user)
      result = executor.execute(tool_call)
      save_assistant_message("[Tool #{tool_call[:name]}: #{result}]")
    end
  end
end
