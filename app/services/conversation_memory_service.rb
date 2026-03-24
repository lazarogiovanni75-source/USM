class ConversationMemoryService
  include ActionView::Helpers::TextHelper
  require 'net/http'
  require 'json'
  require 'uri'
  
  # Memory context configuration
  MAX_CONTEXT_TOKENS = 4000
  MAX_RECENT_MESSAGES = 10
  MEMORY_RETENTION_HOURS = 24
  
  class << self
    # Main method to build conversation context for AI
    def build_context(conversation, include_memory: true, include_summary: true)
      context = {
        conversation_id: conversation.id,
        session_type: conversation.session_type,
        timestamp: Time.current
      }
      
      # Add conversation metadata
      if conversation.context.present?
        context[:session_context] = conversation.context
      end
      
      # Add memory summary if enabled
      if include_memory && conversation.memory_summary.present?
        context[:memory_summary] = conversation.memory_summary
      end
      
      # Add recent conversation history
      recent_messages = conversation.get_recent_messages(MAX_RECENT_MESSAGES)
      context[:recent_conversation] = build_message_context(recent_messages)
      
      # Add topic tracking
      topics = conversation.get_from_memory('conversation_topics')
      context[:current_topics] = topics if topics.present?
      
      # Add user preferences
      preferences = conversation.get_from_memory('user_preferences')
      context[:user_preferences] = preferences if preferences.present?
      
      context
    end
    
    # Enhanced AI API call with conversation memory
    def call_ai_with_memory(conversation, user_message, additional_context = {})
      # Build comprehensive context
      memory_context = build_context(conversation)
      
      # Prepare the complete prompt context
      prompt_context = {
        memory_context: memory_context,
        current_message: {
          content: user_message,
          timestamp: Time.current,
          conversation_length: conversation.conversation_length
        },
        additional_context: additional_context
      }
      
      # Call the Railway AI API with enhanced context
      ai_response = call_railway_ai_api(prompt_context, conversation)
      
      # Update conversation memory with new information
      update_conversation_memory(conversation, user_message, ai_response)
      
      ai_response
    end
    
    # Update conversation memory after each exchange
    def update_conversation_memory(conversation, user_message, ai_response)
      # Extract topics from the new exchange
      new_topics = extract_topics([user_message])
      
      # Update topics in memory
      existing_topics = conversation.get_from_memory('conversation_topics') || []
      updated_topics = (existing_topics + new_topics).uniq
      conversation.add_to_memory('conversation_topics', updated_topics)
      
      # Update user preferences based on message analysis
      preferences = conversation.get_from_memory('user_preferences') || {}
      new_preferences = extract_preferences([user_message])
      preferences.merge!(new_preferences)
      conversation.add_to_memory('user_preferences', preferences)
      
      # Update session context
      session_context = conversation.context || {}
      session_context['last_message_time'] = Time.current
      session_context['total_interactions'] = conversation.conversation_length
      conversation.update_context(session_context)
      
      # Store important information for future reference
      store_important_info(conversation, user_message, ai_response)
    end
    
    # Store important information that should be remembered
    def store_important_info(conversation, user_message, ai_response)
      important_patterns = {
        'user_name' => /my name is (\w+)/i,
        'company' => /i work (?:at|for) (\w+)/i,
        'goals' => /(?:i want|i need|my goal is) (.+?)(?:\.|$)/i,
        'interests' => /interested in (.+?)(?:\.|$)/i,
        'preferences' => /(?:i prefer|i like|my favorite) (.+?)(?:\.|$)/i
      }
      
      important_info = conversation.get_from_memory('important_info') || {}
      
      important_patterns.each do |key, pattern|
        if user_message =~ pattern
          match_data = user_message.match(pattern)
          important_info[key] = match_data[1].strip if match_data && match_data[1]
        end
      end
      
      conversation.add_to_memory('important_info', important_info) if important_info.any?
    end
    
    # Get conversation insights and analytics
    def analyze_conversation(conversation)
      messages = conversation.ai_messages
      
      analysis = {
        conversation_length: messages.count,
        total_tokens: conversation.tokens_used,
        user_message_count: messages.where(role: 'user').count,
        ai_message_count: messages.where(role: 'assistant').count,
        topics: conversation.get_from_memory('conversation_topics') || [],
        user_preferences: conversation.get_from_memory('user_preferences') || {},
        important_info: conversation.get_from_memory('important_info') || {},
        engagement_score: calculate_engagement_score(messages),
        memory_health: conversation.memory_health
      }
      
      # Add temporal analysis
      if messages.count > 1
        first_message = messages.order(created_at: :asc).first
        last_message = messages.order(created_at: :asc).last
        analysis[:duration_minutes] = ((last_message.created_at - first_message.created_at) / 60.0).round(2)
        analysis[:average_response_time] = calculate_average_response_time(messages)
      end
      
      analysis
    end
    
    # Memory cleanup and optimization
    def optimize_conversation_memory(conversation)
      # Prune old messages if conversation is too long
      if conversation.tokens_used > MAX_CONTEXT_TOKENS
        messages_to_keep = conversation.ai_messages
          .order(created_at: :desc)
          .limit(MAX_RECENT_MESSAGES * 2)  # Keep some buffer
        
        # Archive old messages but keep summary
        old_messages = conversation.ai_messages - messages_to_keep
        old_messages.each do |message|
          message.update(archived: true, archived_at: Time.current) if message.respond_to?(:archived)
        end
        
        # Update memory summary with compressed information
        compress_conversation_summary(conversation, old_messages)
      end
      
      # Clean up expired temporary data
      cleanup_temporary_data(conversation)
    end
    
    private
    
    def build_message_context(messages)
      messages.map do |message|
        {
          role: message.role,
          content: message.content.truncate(500), # Truncate long messages
          timestamp: message.created_at,
          tokens: message.tokens_used
        }
      end
    end
    
    def extract_topics(messages)
      topics = []
      # Handle both string and message object arrays
      if messages.is_a?(Array) && messages.first.is_a?(String)
        message_text = messages.join(' ').downcase
      else
        message_text = messages.map { |m| m.respond_to?(:content) ? m.content : m.to_s }.join(' ').downcase
      end
      
      # Enhanced topic extraction with more patterns
      topic_patterns = {
        'social media' => ['social media', 'twitter', 'facebook', 'instagram', 'linkedin', 'tiktok', 'youtube'],
        'content creation' => ['content', 'blog', 'post', 'article', 'writing', 'copy', 'caption'],
        'marketing' => ['marketing', 'campaign', 'promotion', 'advertising', 'brand', 'branding'],
        'business' => ['business', 'company', 'startup', 'entrepreneur', 'sales', 'revenue'],
        'ai technology' => ['ai', 'artificial intelligence', 'chat', 'assistant', 'automation', 'machine learning'],
        'video content' => ['video', 'youtube', 'tiktok', 'reel', 'shorts', 'video marketing'],
        'email marketing' => ['email', 'newsletter', 'email campaign', 'mailchimp'],
        'seo' => ['seo', 'search engine', 'google', 'ranking', 'keywords'],
        'analytics' => ['analytics', 'metrics', 'data', 'performance', 'tracking']
      }
      
      topic_patterns.each do |topic, keywords|
        if keywords.any? { |keyword| message_text.include?(keyword) }
          topics << topic
        end
      end
      
      topics.uniq
    end
    
    def extract_preferences(messages)
      preferences = {}
      # Handle both string and message object arrays
      if messages.is_a?(Array) && messages.first.is_a?(String)
        message_text = messages.join(' ').downcase
      else
        message_text = messages.map { |m| m.respond_to?(:content) ? m.content : m.to_s }.join(' ').downcase
      end
      
      # Tone preferences
      if message_text.match?(/(?:professional|formal|business|corporate)/)
        preferences[:tone] = 'professional'
      elsif message_text.match?(/(?:casual|friendly|relaxed|informal)/)
        preferences[:tone] = 'casual'
      elsif message_text.match?(/(?:creative|innovative|artistic|imaginative)/)
        preferences[:tone] = 'creative'
      end
      
      # Length preferences
      if message_text.match?(/(?:brief|short|concise|quick)/)
        preferences[:length] = 'brief'
      elsif message_text.match?(/(?:detailed|comprehensive|thorough|extensive)/)
        preferences[:length] = 'detailed'
      end
      
      # Style preferences
      if message_text.match?(/(?:humorous|funny|joking|witty)/)
        preferences[:style] = 'humorous'
      elsif message_text.match?(/(?:serious|formal|academic)/)
        preferences[:style] = 'serious'
      end
      
      preferences
    end
    
    def calculate_engagement_score(messages)
      return 0 if messages.count < 2
      
      user_messages = messages.where(role: 'user')
      ai_messages = messages.where(role: 'assistant')
      
      # Factors for engagement score
      factors = {
        message_count: [messages.count / 10.0, 1.0].min, # Normalize to max 1.0
        conversation_depth: [user_messages.average(:tokens_used).to_f / 50.0, 1.0].min, # Longer messages = more engagement
        back_and_forth: [ai_messages.count.to_f / user_messages.count.to_f, 2.0].min, # Ratio of AI responses
        time_spread: messages.count > 1 ? 1.0 : 0.5 # Consistent conversation vs one-off
      }
      
      (factors.values.sum / factors.keys.count * 100).round(2)
    end
    
    def calculate_average_response_time(messages)
      user_messages = messages.where(role: 'user').order(created_at: :asc)
      return 0 if user_messages.count < 2
      
      total_time = 0
      pairs_count = 0
      
      user_messages.each_with_index do |user_msg, index|
        next if index == 0
        
        previous_user_msg = user_messages[index - 1]
        ai_response = messages.where(role: 'assistant')
          .where('created_at > ? AND created_at < ?', previous_user_msg.created_at, user_msg.created_at)
          .first
        
        if ai_response
          total_time += (ai_response.created_at - previous_user_msg.created_at)
          pairs_count += 1
        end
      end
      
      pairs_count > 0 ? (total_time / pairs_count).round(2) : 0
    end
    
    def compress_conversation_summary(conversation, old_messages)
      # Create a compressed summary of old messages for memory retention
      summary = {
        compressed_at: Time.current,
        original_message_count: old_messages.count,
        key_topics: conversation.get_from_memory('conversation_topics') || [],
        important_points: conversation.get_from_memory('important_info') || {},
        summary_text: generate_conversation_summary(old_messages)
      }
      
      conversation.add_to_memory('compressed_history', summary)
    end
    
    def generate_conversation_summary(messages)
      user_messages = messages.where(role: 'user').map(&:content).join(' ')
      truncate(user_messages, length: 500, separator: ' ')
    end
    
    def cleanup_temporary_data(conversation)
      # Remove temporary context data that's older than retention period
      context = conversation.context || {}
      context.delete_if { |key, value| key.end_with?('_temp') && value.is_a?(Time) && value < MEMORY_RETENTION_HOURS.hours.ago }
      conversation.update_context(context) if context.changed?
    end
    
    def call_railway_ai_api(prompt_context, conversation)
      begin
        uri = URI.parse("#{ENV['RAILWAY_BACKEND_URL']}/api/ai/chat")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        
        request = Net::HTTP::Post.new(uri.request_uri)
        request['Content-Type'] = 'application/json'
        request['Authorization'] = "Bearer #{ENV['RAILWAY_API_KEY']}"
        request.body = {
          prompt_context: prompt_context,
          conversation_id: conversation.id,
          user_id: conversation.user_id
        }.to_json
        
        response = http.request(request)
        JSON.parse(response.body)
      rescue => e
        Rails.logger.error "Railway AI API Error: #{e.message}"
        {
          content: "I apologize, but I'm having trouble connecting to the AI service right now. Please try again in a moment.",
          tokens_used: 0,
          confidence: 0.0
        }
      end
    end
  end
end