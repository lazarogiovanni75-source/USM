# frozen_string_literal: true

# VoiceConversationService - Manages voice chat conversations with memory and context
# Provides conversation history for streaming LLM responses
class VoiceConversationService
  DEFAULT_SYSTEM_PROMPT = <<~PROMPT
    You are Pilot, a helpful AI voice assistant for a marketing platform.
    Your role is to:
    1. Listen to what the user says
    2. Understand their intent naturally
    3. Help them with marketing tasks like:
       - Creating marketing campaigns
       - Generating social media content 
       - Scheduling posts
       - Analyzing performance
       - Answering marketing questions
    
    IMPORTANT - Take action, don't just ask questions:
    - When a user requests a task (like creating a campaign, video, content), ALWAYS use the available tools to complete it
    - Don't ask endless follow-up questions - if you have enough information to proceed, DO IT
    - Use the create_campaign tool to create campaigns
    - Use the generate_video tool to generate videos
    - Use the generate_content tool to create content
    - Use the schedule_post tool to schedule posts
    
    Only ask ONE quick clarifying question if you're truly missing critical information.
    Otherwise, take action and execute the user's request using tools.
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
