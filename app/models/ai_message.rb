# frozen_string_literal: true

class AiMessage < ApplicationRecord
  belongs_to :ai_conversation
  
  validates :role, presence: true, inclusion: { in: %w[user assistant system tool] }
  validates :content, presence: true
  
  # Memory and context tracking
  MESSAGE_TYPES = %w[text image file link code].freeze
  validates :message_type, inclusion: { in: MESSAGE_TYPES }, allow_nil: true
  
  before_save :estimate_tokens
  before_validation :set_default_metadata
  
  # Override create to use raw SQL - bypasses any Rails validation issues
  def self.create!(**attributes)
    now = Time.current
    ai_conversation_id = attributes[:ai_conversation_id] || attributes[:ai_conversation]&.id
    role = attributes[:role]
    content = attributes[:content]
    message_type = attributes[:message_type] || 'text'
    metadata = attributes[:metadata] || {}
    tokens_used = attributes[:tokens_used] || (content.length / 4.0).ceil
    
    sql = <<~SQL
      INSERT INTO ai_messages (ai_conversation_id, role, content, message_type, 
        metadata, tokens_used, created_at, updated_at)
      VALUES (#{ai_conversation_id}, #{ActiveRecord::Base.connection.quote(role)}, 
        #{ActiveRecord::Base.connection.quote(content)}, 
        #{ActiveRecord::Base.connection.quote(message_type)}, 
        #{ActiveRecord::Base.connection.quote(metadata.to_json)}, 
        #{tokens_used}, 
        '#{now.utc.strftime('%Y-%m-%d %H:%M:%S')}', 
        '#{now.utc.strftime('%Y-%m-%d %H:%M:%S')}')
      RETURNING id
    SQL
    
    id = ActiveRecord::Base.connection.execute(sql).first['id']
    find(id)
  rescue => e
    Rails.logger.error "[AiMessage.create!] Raw SQL failed: #{e.message}"
    raise e
  end
  
  # Override save to use raw SQL
  def save(**options)
    now = Time.current
    updates = []
    updates << "content = #{ActiveRecord::Base.connection.quote(content)}" if respond_to?(:content)
    updates << "role = #{ActiveRecord::Base.connection.quote(role)}" if respond_to?(:role)
    updates << "tokens_used = #{tokens_used}" if respond_to?(:tokens_used)
    updates << "updated_at = '#{now.utc.strftime('%Y-%m-%d %H:%M:%S')}'"
    
    sql = "UPDATE ai_messages SET #{updates.join(', ')} WHERE id = #{id}"
    ActiveRecord::Base.connection.execute(sql)
    true
  rescue => e
    Rails.logger.error "[AiMessage.save] Raw SQL failed: #{e.message}"
    false
  end
  
  # Token estimation
  def estimate_tokens
    return if tokens_used.present?
    self.tokens_used = (content.length / 4.0).ceil
  end
  
  def set_default_metadata
    self.metadata ||= {}
  end
  
  def is_user_message?
    role == 'user'
  end
  
  def is_ai_message?
    role == 'assistant'
  end
  
  def is_system_message?
    role == 'system'
  end
  
  def previous_message
    ai_conversation.ai_messages.where('created_at < ?', created_at).order(created_at: :desc).first
  end
  
  def next_message
    ai_conversation.ai_messages.where('created_at > ?', created_at).order(created_at: :asc).first
  end
  
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
  
  def self.search(query)
    where('content ILIKE ?', "%#{query}%")
  end
  
  def self.by_role(role)
    where(role: role)
  end
  
  def self.in_time_range(start_time, end_time)
    where(created_at: start_time..end_time)
  end
  
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
  
  def self.build_memory_context(conversation)
    context = {
      conversation_summary: conversation.memory_summary || {},
      recent_topics: conversation.get_from_memory('conversation_topics') || [],
      user_preferences: conversation.get_from_memory('user_preferences') || {},
      conversation_length: conversation.conversation_length,
      last_activity: conversation.updated_at
    }
    
    context[:recent_messages] = build_conversation_context(conversation, 5)
    context
  end
end
