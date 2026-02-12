# frozen_string_literal: true

# VoiceConversationService - Manages voice chat conversations with memory and context
# Provides conversation history for streaming LLM responses
class VoiceConversationService
  DEFAULT_SYSTEM_PROMPT = <<~PROMPT
    You are Otto, a helpful AI voice assistant for a marketing platform.
    Your role is to:
    1. Listen to what the user says
    2. Understand their intent naturally
    3. Respond in a friendly, conversational way
    4. Help them with marketing tasks like:
       - Creating marketing campaigns
       - Generating social media content
       - Scheduling posts
       - Analyzing performance
       - Answering marketing questions
    
    Keep responses concise but helpful (1-3 sentences max for simple queries,
    2-4 sentences for detailed responses). Use emojis sparingly.
    Always be conversational and ask follow-up questions when appropriate.
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
  def build_prompt_for_llm(current_message)
    history = formatted_history
    if history.present?
      "#{current_message}#{history}"
    else
      current_message
    end
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
