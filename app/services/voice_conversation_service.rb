# frozen_string_literal: true

# VoiceConversationService - Manages voice chat conversations with memory and context
# Provides conversation history for streaming LLM responses
class VoiceConversationService
  DEFAULT_SYSTEM_PROMPT = <<~PROMPT
    You're Pilot, a helpful AI assistant for a marketing platform.
    You talk to users like you're a knowledgeable friend helping them manage their social media.

    Your approach:
    - Listen to what the user wants
    - Understand their intent naturally
    - Help them get things done without dragging out the conversation
    - When a user asks for something like a campaign, post, or video, just do it
    - Only ask one quick question if you're genuinely missing something important

    When taking action, use your tools: create campaigns, generate content, schedule posts, check how things are performing, save your work, and let the user know what's happening.
  PROMPT

  attr_reader :conversation, :user

  def initialize(user:, conversation_id: nil)
    @user = user
    @conversation = find_or_create_conversation(conversation_id)
  end

  def add_user_message(content)
    conversation.ai_messages.create!(
      role: 'user',
      content: content,
      tokens_used: estimate_tokens(content)
    )
  end

  def add_assistant_message(content)
    conversation.ai_messages.create!(
      role: 'assistant',
      content: content,
      tokens_used: estimate_tokens(content)
    )
  end

  def conversation_messages
    conversation.get_recent_messages(10)
  end

  # Format conversation history for LLM prompt
  def formatted_history
    messages = conversation_messages
    return nil if messages.empty?

    history_text = messages.map do |msg|
      role = msg.role == 'user' ? 'User' : 'Assistant'
      "#{role}: #{msg.content}"
    end.join("\n")

    "\nConversation History:\n#{history_text}"
  end

  def system_prompt
    DEFAULT_SYSTEM_PROMPT
  end

  # Build the full prompt with conversation context
  # NOTE: ConversationOrchestrator.build_message_history already loads history from database,
  # so we just return the current message here. The history is NOT appended to the prompt.
  def build_prompt_for_llm(current_message)
    current_message
  end

  def self.conversation_channel(user_id, conversation_id)
    "voice_chat_#{user_id}_#{conversation_id}"
  end

  private

  def find_or_create_conversation(conversation_id)
    return AiConversation.find_by(id: conversation_id, user: user) if conversation_id.present?

    AiConversation.create!(
      user: user,
      title: "Voice Chat #{Time.current.strftime('%Y-%m-%d %H:%M')}",
      session_type: 'voice_chat',
      context: {},
      memory_summary: {}
    )
  end

  def estimate_tokens(text)
    (text.length / 4.0).ceil
  end
end
