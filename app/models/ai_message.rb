class AiMessage < ApplicationRecord
  belongs_to :ai_conversation
  
  validates :role, presence: true, inclusion: { in: %w[user assistant system tool] }
  validates :content, presence: true
  
  default_scope { order(created_at: :asc) }
  
  # Memory and context tracking
  serialize :metadata, Hash
  
  # Message types for better organization
  MESSAGE_TYPES = %w[text image file link code].freeze
  validates :message_type, inclusion: { in: MESSAGE_TYPES }, allow_nil: true
  
  before_save :estimate_tokens
  
  # Token estimation (rough approximation)
  def estimate_tokens
    return if tokens_used.present?
    
    # Rough estimation: 1 token ≈ 4 characters for English text
    # This is a simplification - actual tokenization varies
    self.tokens_used = (content.length / 4.0).ceil
  end
  
  # Context helpers
  def is_user_message?
    role == 'user'
  end
  
  def is_ai_message?
    role == 'assistant'
  end
  
  def is_system_message?
    role == 'system'
  end
  
  # Message relationships
  def previous_message
    ai_conversation.ai_messages.where('created_at < ?', created_at).order(created_at: :desc).first
  end
  
  def next_message
    ai_conversation.ai_messages.where('created_at > ?', created_at).order(created_at: :asc).first
  end
  
  # Message editing and management
  def update_content(new_content)
    update!(content: new_content, tokens_used: (new_content.length / 4.0).ceil)
  end
  
  def reply_to(message_content, ai_response_content)
    ai_conversation.ai_messages.create!(
      role: 'user',
      content: message_content,
      message_type: 'text',
      tokens_used: (message_content.length / 4.0).ceil
    )
    
    ai_conversation.ai_messages.create!(
      role: 'assistant',
      content: ai_response_content,
      message_type: 'text',
      tokens_used: (ai_response_content.length / 4.0).ceil
    )
  end
  
  # Search and filtering
  def self.search(query)
    where('content ILIKE ?', "%#{query}%")
  end
  
  def self.by_role(role)
    where(role: role)
  end
  
  def self.in_time_range(start_time, end_time)
    where(created_at: start_time..end_time)
  end
  
  # Conversation context building
  def self.build_conversation_context(conversation, limit = 10)
    recent_messages = conversation.ai_messages
      .order(created_at: :desc)
      .limit(limit)
      .reverse
    
    recent_messages.map do |message|
      {
        role: message.role,
        content: message.content,
        timestamp: message.created_at,
        message_type: message.message_type || 'text'
      }
    end
  end
  
  # Memory context for AI prompts
  def self.build_memory_context(conversation)
    context = {
      conversation_summary: conversation.memory_summary || {},
      recent_topics: conversation.get_from_memory('conversation_topics') || [],
      user_preferences: conversation.get_from_memory('user_preferences') || {},
      conversation_length: conversation.conversation_length,
      last_activity: conversation.updated_at
    }
    
    # Add recent conversation history
    context[:recent_messages] = build_conversation_context(conversation, 5)
    
    context
  end
end