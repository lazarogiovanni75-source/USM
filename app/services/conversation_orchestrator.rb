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
    Rails.logger.info "[ConversationOrchestrator] conversation: #{conversation.id rescue 'nil'}, modality: #{modality}"
    
    conversation_id = save_user_message_raw
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
    
    touch_conversation
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
      save_assistant_message_raw(error_message, conversation&.id)
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

  def conn
    ActiveRecord::Base.connection
  end

  def find_or_create_conversation(conversation_id)
    if conversation_id.present?
      conv = user.ai_conversations.find_by(id: conversation_id)
      return conv if conv
    end
    create_new_conversation_raw
  end

  def create_new_conversation_raw
    now = Time.current
    title = "Chat #{now.strftime('%b %d, %I:%M %p')}"
    metadata_json = { created_via: modality }.to_json
    
    result = conn.execute(<<~SQL)
      INSERT INTO ai_conversations (user_id, title, session_type, metadata, 
        context, memory_summary, session_metadata, archived, created_at, updated_at)
      VALUES (#{user.id}, #{conn.quote(title)}, 'chat', #{conn.quote(metadata_json)}, 
        '{}', '{}', '{}', false, '#{now.utc.strftime('%Y-%m-%d %H:%M:%S')}', 
        '#{now.utc.strftime('%Y-%m-%d %H:%M:%S')}')
      RETURNING id
    SQL
    
    conversation_id = result.first['id']
    AiConversation.find(conversation_id)
  rescue => e
    Rails.logger.error "[ConversationOrchestrator] create_new_conversation_raw failed: #{e.message}"
    raise e
  end

  def save_user_message_raw
    now = Time.current
    metadata_json = { modality: modality, created_at: now }.to_json
    conversation_id = @conversation.id
    
    result = conn.execute(<<~SQL)
      INSERT INTO ai_messages (ai_conversation_id, role, content, message_type, 
        metadata, tokens_used, created_at, updated_at)
      VALUES (#{conversation_id}, 'user', #{conn.quote(content)}, 'text', 
        #{conn.quote(metadata_json)}, #{content.length / 4}, 
        '#{now.utc.strftime('%Y-%m-%d %H:%M:%S')}', '#{now.utc.strftime('%Y-%m-%d %H:%M:%S')}')
      RETURNING id
    SQL
    
    Rails.logger.info "[ConversationOrchestrator] User message saved - conversation: #{conversation_id}"
    conversation_id
  rescue => e
    Rails.logger.error "[ConversationOrchestrator] save_user_message_raw failed: #{e.message}"
    raise e
  end

  def save_assistant_message_raw(content_str, conversation_id)
    return unless conversation_id
    now = Time.current
    metadata_json = { model: CLAUDE_MODEL, created_at: now }.to_json
    tokens = (content_str.length / 4.0).ceil
    
    conn.execute(<<~SQL)
      INSERT INTO ai_messages (ai_conversation_id, role, content, message_type, 
        metadata, tokens_used, created_at, updated_at)
      VALUES (#{conversation_id}, 'assistant', #{conn.quote(content_str)}, 'text', 
        #{conn.quote(metadata_json)}, #{tokens}, 
        '#{now.utc.strftime('%Y-%m-%d %H:%M:%S')}', '#{now.utc.strftime('%Y-%m-%d %H:%M:%S')}')
    SQL
    
    Rails.logger.info "[ConversationOrchestrator] Assistant message saved - conversation: #{conversation_id}"
  rescue => e
    Rails.logger.error "[ConversationOrchestrator] save_assistant_message_raw failed: #{e.message}"
  end

  def touch_conversation
    return unless @conversation&.id
    now = Time.current
    conn.execute(<<~SQL)
      UPDATE ai_conversations SET updated_at = '#{now.utc.strftime('%Y-%m-%d %H:%M:%S')}' 
      WHERE id = #{@conversation.id}
    SQL
  rescue => e
    Rails.logger.error "[ConversationOrchestrator] touch_conversation failed: #{e.message}"
  end

  def detect_intent
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
    save_assistant_message_raw(initial_response, @conversation.id)
    
    ImageGenerationJob.perform_later(
      conversation_id: @conversation.id,
      prompt: content,
      user_id: user.id
    )
    
    @assistant_response = initial_response
  end

  def handle_video_generation
    Rails.logger.info "[ConversationOrchestrator] Handling video generation intent"
    
    initial_response = "I'll create that video for you. Video generation typically takes 1-2 minutes."
    broadcast_content(initial_response) if stream_channel
    save_assistant_message_raw(initial_response, @conversation.id)
    
    GenerateVideoJob.perform_later(
      prompt: content,
      user_id: user.id,
      conversation_id: @conversation.id
    )
    
    @assistant_response = initial_response
  end

  def build_message_history
    return [] unless @conversation&.id
    
    recent_messages = conn.execute(<<~SQL)
      SELECT role, content FROM ai_messages 
      WHERE ai_conversation_id = #{@conversation.id}
      ORDER BY created_at ASC
      LIMIT #{MAX_HISTORY_MESSAGES}
    SQL
    
    base_prompt = begin
      SiteSetting.ai_system_prompt
    rescue
      "You are a helpful AI assistant."
    end
    
    subscription_info = ""
    if user.subscription_plan.present?
      plan_name = user.subscription_plan.is_a?(String) ? user.subscription_plan : user.subscription_plan.name
      subscription_info = "\n\nUser Subscription: #{plan_name}"
    end
    
    user_info = "\n\nUser: #{user.email}"
    
    @system_prompt = base_prompt + subscription_info + user_info
    
    messages = []
    
    recent_messages.each do |row|
      messages << {
        role: row['role'].to_sym,
        content: row['content']
      }
    end
    
    messages
  end

  def stream_chat_response(history, tools)
    full_response = ""
    
    LlmService.stream(anthropic_messages: history, model: CLAUDE_MODEL) do |chunk|
      full_response += chunk
      broadcast_content(chunk)
    end
    
    save_assistant_message_raw(full_response, @conversation.id)
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
    save_assistant_message_raw(response_content, @conversation.id)
    @assistant_response = response_content
  end
end
