# frozen_string_literal: true

# ConversationOrchestrator - ChatGPT-style conversation service
class ConversationOrchestrator < ApplicationService
  MAX_HISTORY_MESSAGES = 15
  CLAUDE_MODEL = "claude-sonnet-4-6"
  CHAT_TEMPERATURE = 0.8
  CHAT_MAX_TOKENS = 4000

  attr_reader :user, :conversation, :content, :modality, :stream_channel, :fallback_channel

  def initialize(user:, conversation_id:, content:, modality: "text", stream_channel: nil, fallback_channel: nil)
    @user = user
    @conversation = find_or_create_conversation(conversation_id)
    @content = content
    @modality = modality
    @stream_channel = stream_channel
    @fallback_channel = fallback_channel
    @assistant_response = ""
  end

  def self.process_message(**args)
    new(**args).call
  end

  def call
    Rails.logger.info "[ConversationOrchestrator] === START ==="
    Rails.logger.info "[ConversationOrchestrator] user: #{user&.id} (#{user&.email})"
    Rails.logger.info "[ConversationOrchestrator] conversation: #{conversation.id rescue 'nil'}, modality: #{modality}"

    # Save user message
    conversation.ai_messages.create!(
      role: 'user',
      content: content,
      message_type: 'text',
      metadata: { modality: modality }
    )

    # Detect intent and handle
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
    @assistant_response ||= ""

    {
      conversation_id: conversation.id,
      response: @assistant_response
    }
  rescue => e
    Rails.logger.error "[ConversationOrchestrator] Error: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")

    error_message = "I apologize, but I encountered an error processing your message. [#{e.class}]"
    begin
      conversation.ai_messages.create!(
        role: 'assistant',
        content: error_message,
        message_type: 'text'
      )
    rescue => save_error
      Rails.logger.error "[ConversationOrchestrator] Failed to save error: #{save_error.message}"
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
      conv = user.ai_conversations.find_by(id: conversation_id)
      return conv if conv
    end

    AiConversation.create!(
      user: user,
      title: "Chat #{Time.current.strftime('%b %d, %I:%M %p')}",
      session_type: 'chat',
      metadata: { created_via: modality }
    )
  end

  def detect_intent
    content_lower = content.downcase
    return :image if content_lower.include?('generate image') || content_lower.include?('create image')
    return :video if content_lower.include?('generate video') || content_lower.include?('create video')
    :chat
  end

  def handle_chat
    Rails.logger.info "[ConversationOrchestrator] Handling chat intent"

    history = build_message_history
    Rails.logger.info "[ConversationOrchestrator] Message history built - #{history.size} messages"

    if stream_channel
      stream_chat_response(history, nil)
    else
      blocking_chat_response(history, nil)
    end
  end

  def handle_image_generation
    Rails.logger.info "[ConversationOrchestrator] Handling image generation intent"

    initial_response = "I'll generate that image for you. This will take a moment..."
    broadcast_content(initial_response) if stream_channel
    conversation.ai_messages.create!(
      role: 'assistant',
      content: initial_response,
      message_type: 'text'
    )

    ImageGenerationJob.perform_later(
      conversation_id: conversation.id,
      prompt: content,
      user_id: user.id
    )

    @assistant_response = initial_response
  end

  def handle_video_generation
    Rails.logger.info "[ConversationOrchestrator] Handling video generation intent"

    initial_response = "I'll create that video for you. Video generation typically takes 1-2 minutes."
    broadcast_content(initial_response) if stream_channel
    conversation.ai_messages.create!(
      role: 'assistant',
      content: initial_response,
      message_type: 'text'
    )

    GenerateVideoJob.perform_later(
      prompt: content,
      user_id: user.id,
      conversation_id: conversation.id
    )

    @assistant_response = initial_response
  end

  def build_message_history
    return [] unless @conversation

    recent_messages = @conversation.ai_messages
      .order(created_at: :asc)
      .last(MAX_HISTORY_MESSAGES)

    base_prompt = begin
      SiteSetting.ai_system_prompt
    rescue
      "You are a helpful AI assistant for a social media marketing platform."
    end

    subscription_info = ""
    if user.subscription_plan.present?
      plan_name = user.subscription_plan.is_a?(String) ? user.subscription_plan : user.subscription_plan.name
      subscription_info = "\n\nUser Subscription: #{plan_name}"
    end

    system_message = "#{base_prompt}#{subscription_info}"

    history = [{ role: "system", content: system_message }]
    recent_messages.each do |msg|
      history << { role: msg.role, content: msg.content }
    end

    history
  end

  def stream_chat_response(history, _context)
    @assistant_response = ""

    # Create placeholder message
    ai_msg = conversation.ai_messages.create!(
      role: 'assistant',
      content: '',
      message_type: 'text'
    )

    LlmService.call(
      prompt: content,
      system: build_system_prompt(history),
      user: user,
      max_tokens: CHAT_MAX_TOKENS
    ) do |chunk|
      @assistant_response += chunk
      broadcast_content(chunk)
    end

    # Update the message with full content
    ai_msg.update!(content: @assistant_response)

    broadcast_completion
    Rails.logger.info "[ConversationOrchestrator] Chat response complete"
  end

  def blocking_chat_response(history, _context)
    system_prompt = build_system_prompt(history)

    @assistant_response = LlmService.call_blocking(
      prompt: content,
      system: system_prompt,
      user: user,
      max_tokens: CHAT_MAX_TOKENS
    )

    conversation.ai_messages.create!(
      role: 'assistant',
      content: @assistant_response,
      message_type: 'text',
      metadata: { model: CLAUDE_MODEL }
    )

    Rails.logger.info "[ConversationOrchestrator] Chat response complete"
  end

  def build_system_prompt(history)
    base = begin
      SiteSetting.ai_system_prompt
    rescue
      "You are a helpful AI assistant."
    end

    <<~PROMPT
      #{base}

      You are helping the user with their social media marketing tasks.
      Be conversational, helpful, and concise. When suggesting content,
      provide specific examples they can use immediately.
    PROMPT
  end
end
