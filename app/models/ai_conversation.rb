class AiConversation < ApplicationRecord
  belongs_to :user
  
  has_many :ai_messages, dependent: :destroy
  
  validates :title, presence: true
  validates :session_type, presence: true
  
  default_scope { order(updated_at: :desc) }
  
  # Memory and context tracking
  serialize :context, Hash
  serialize :memory_summary, Hash
  serialize :session_metadata, Hash
  
  # Memory retention settings
  MEMORY_RETENTION_DAYS = 30
  MAX_CONTEXT_MESSAGES = 20
  MAX_MEMORY_TOKENS = 4000
  
  before_save :update_memory_summary
  before_save :prune_old_messages
  
  # Memory management methods
  def add_to_memory(key, value)
    memory_summary ||= {}
    memory_summary[key] = value
    save
  end
  
  def get_from_memory(key)
    memory_summary&.dig(key)
  end
  
  def update_context(new_context)
    context ||= {}
    context.merge!(new_context)
    context['updated_at'] = Time.current
    save
  end
  
  def get_recent_messages(limit = MAX_CONTEXT_MESSAGES)
    ai_messages.order(created_at: :desc).limit(limit).reverse
  end
  
  def conversation_length
    ai_messages.count
  end
  
  def tokens_used
    ai_messages.sum(:tokens_used)
  end
  
  def memory_health
    {
      total_messages: conversation_length,
      tokens_used: tokens_used,
      last_activity: updated_at,
      context_keys: context&.keys || [],
      memory_keys: memory_summary&.keys || []
    }
  end
  
  def archive_conversation
    update!(archived: true, archived_at: Time.current)
  end
  
  def restore_conversation
    update!(archived: false, archived_at: nil)
  end
  
  # Auto-expire old conversations
  def self.cleanup_expired
    where('updated_at < ?', MEMORY_RETENTION_DAYS.days.ago).destroy_all
  end
  
  private
  
  def update_memory_summary
    # Generate memory summary from recent messages
    recent_messages = get_recent_messages(10)
    user_messages = recent_messages.select { |m| m.role == 'user' }
    
    if user_messages.any?
      memory_summary ||= {}
      memory_summary['conversation_topics'] = extract_topics(user_messages.map(&:content))
      memory_summary['user_preferences'] = extract_preferences(user_messages.map(&:content))
      memory_summary['last_updated'] = Time.current
    end
  end
  
  def prune_old_messages
    # Keep only the most recent messages within token limits
    messages = ai_messages.order(created_at: :desc)
    total_tokens = messages.sum(:tokens_used)
    
    if total_tokens > MAX_MEMORY_TOKENS
      # Remove oldest messages until under token limit
      messages_to_keep = []
      running_token_count = 0
      
      messages.each do |message|
        if running_token_count + message.tokens_used <= MAX_MEMORY_TOKENS
          messages_to_keep.unshift(message) # Add to beginning to maintain order
          running_token_count += message.tokens_used
        else
          break
        end
      end
      
      # Remove messages not in keep list
      (ai_messages - messages_to_keep).each(&:destroy)
    end
  end
  
  def extract_topics(messages)
    # Simple topic extraction - could be enhanced with NLP
    topics = []
    message_text = messages.join(' ').downcase
    
    # Look for common keywords
    topic_keywords = {
      'social media' => ['social media', 'twitter', 'facebook', 'instagram', 'linkedin'],
      'content creation' => ['content', 'blog', 'post', 'article', 'writing'],
      'marketing' => ['marketing', 'campaign', 'promotion', 'advertising'],
      'business' => ['business', 'company', 'brand', 'customer'],
      'ai' => ['ai', 'artificial intelligence', 'chat', 'assistant']
    }
    
    topic_keywords.each do |topic, keywords|
      if keywords.any? { |keyword| message_text.include?(keyword) }
        topics << topic
      end
    end
    
    topics.uniq
  end
  
  def extract_preferences(messages)
    # Extract user preferences from conversation
    preferences = {}
    message_text = messages.join(' ').downcase
    
    # Tone preferences
    if message_text.include?('professional') || message_text.include?('formal')
      preferences['tone'] = 'professional'
    elsif message_text.include?('casual') || message_text.include?('friendly')
      preferences['tone'] = 'casual'
    end
    
    # Length preferences
    if message_text.include?('brief') || message_text.include?('short')
      preferences['length'] = 'brief'
    elsif message_text.include?('detailed') || message_text.include?('long')
      preferences['length'] = 'detailed'
    end
    
    preferences
  end
end