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
  SYSTEM_PROMPT = "You are a natural conversational AI assistant. Respond clearly and conversationally. Do not sound robotic."
  MAX_HISTORY_MESSAGES = 30
  CHAT_MODEL = "gpt-4o"
  CHAT_TEMPERATURE = 0.8
  CHAT_MAX_TOKENS = 4000
  
  # Intent keywords for routing
  IMAGE_KEYWORDS = %w[image photo picture generate create make draw design]
  VIDEO_KEYWORDS = %w[video clip footage generate create make film]
  
  attr_reader :user, :conversation, :content, :modality, :stream_channel

  def initialize(user:, conversation_id:, content:, modality: "text", stream_channel: nil)
    @user = user
    @conversation = find_or_create_conversation(conversation_id)
    @content = content
    @modality = modality
    @stream_channel = stream_channel
    @assistant_response = ""
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
      metadata: { model: CHAT_MODEL, created_at: Time.current }
    )
    
    Rails.logger.info "[ConversationOrchestrator] Assistant message saved - conversation: #{conversation.id}, length: #{content.length}"
  end

  def save_tool_message(tool_name, result)
    conversation.ai_messages.create!(
      role: 'tool',
      content: "Tool: #{tool_name}\nResult: #{result.is_a?(Hash) ? result.to_json : result}",
      message_type: 'text',
      metadata: { tool_name: tool_name, created_at: Time.current }
    )
  end

  def detect_intent
    content_lower = content.downcase
    
    # Check for image keywords
    if IMAGE_KEYWORDS.any? { |kw| content_lower.include?(kw) } && 
       (content_lower.include?('image') || content_lower.include?('photo') || content_lower.include?('picture'))
      return :image
    end
    
    # Check for video keywords
    if VIDEO_KEYWORDS.any? { |kw| content_lower.include?(kw) } && 
       content_lower.include?('video')
      return :video
    end
    
    :chat
  end

  def handle_chat
    Rails.logger.info "[ConversationOrchestrator] Handling chat intent"
    
    # Build message history
    history = build_message_history
    
    Rails.logger.info "[ConversationOrchestrator] Message history built - #{history.size} messages"
    log_message_array(history)
    
    # Stream response from OpenAI
    if stream_channel
      stream_chat_response(history)
    else
      blocking_chat_response(history)
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
    messages = [{ role: "system", content: SYSTEM_PROMPT }]
    
    recent_messages.each do |msg|
      # Skip tool messages for now (can be enhanced later)
      next if msg.role == 'tool'
      
      messages << {
        role: msg.role,
        content: msg.content
      }
    end
    
    messages
  end

  def stream_chat_response(history)
    Rails.logger.info "[ConversationOrchestrator] Streaming chat response"
    
    api_key = ENV.fetch('OPENAI_API_KEY') { ENV.fetch('CLACKY_OPENAI_API_KEY', nil) }
    unless api_key
      error_msg = "OpenAI API key not configured"
      Rails.logger.error "[ConversationOrchestrator] #{error_msg}"
      broadcast_error(error_msg)
      return error_msg
    end
    
    client = OpenAI::Client.new(access_token: api_key)
    
    @assistant_response = ""
    
    begin
      client.chat(
        parameters: {
          model: CHAT_MODEL,
          messages: history,
          temperature: CHAT_TEMPERATURE,
          max_tokens: CHAT_MAX_TOKENS,
          stream: proc { |chunk, _bytesize|
            Rails.logger.debug "[ConversationOrchestrator] Stream chunk received"
            
            delta = chunk.dig("choices", 0, "delta", "content")
            
            if delta.present?
              @assistant_response += delta
              broadcast_content(delta)
            end
          }
        }
      )
      
      Rails.logger.info "[ConversationOrchestrator] Streaming complete - total length: #{@assistant_response.length}"
      
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

  def blocking_chat_response(history)
    Rails.logger.info "[ConversationOrchestrator] Blocking chat response"
    
    api_key = ENV.fetch('OPENAI_API_KEY') { ENV.fetch('CLACKY_OPENAI_API_KEY', nil) }
    unless api_key
      error_msg = "OpenAI API key not configured"
      Rails.logger.error "[ConversationOrchestrator] #{error_msg}"
      return error_msg
    end
    
    client = OpenAI::Client.new(access_token: api_key)
    
    begin
      response = client.chat(
        parameters: {
          model: CHAT_MODEL,
          messages: history,
          temperature: CHAT_TEMPERATURE,
          max_tokens: CHAT_MAX_TOKENS
        }
      )
      
      @assistant_response = response.dig("choices", 0, "message", "content") || ""
      
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
    
    ActionCable.server.broadcast(stream_channel, {
      type: 'content_delta',
      delta: delta,
      conversation_id: conversation.id
    })
  end

  def broadcast_completion
    return unless stream_channel
    
    ActionCable.server.broadcast(stream_channel, {
      type: 'completion',
      conversation_id: conversation.id,
      full_content: @assistant_response
    })
  end

  def broadcast_error(message)
    return unless stream_channel
    
    ActionCable.server.broadcast(stream_channel, {
      type: 'error',
      error: message,
      conversation_id: conversation.id
    })
  end

  def log_message_array(messages)
    Rails.logger.info "[ConversationOrchestrator] Message array sent to OpenAI:"
    messages.each_with_index do |msg, idx|
      content_preview = msg[:content].to_s[0..100]
      Rails.logger.info "  [#{idx}] role=#{msg[:role]}, content=#{content_preview}..."
    end
    Rails.logger.info "[ConversationOrchestrator] Model: #{CHAT_MODEL}, Temperature: #{CHAT_TEMPERATURE}, Max tokens: #{CHAT_MAX_TOKENS}"
  end
end
