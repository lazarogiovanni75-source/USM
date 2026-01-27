class AiChatController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @conversations = current_user.ai_conversations.order(updated_at: :desc).limit(10)
    @current_conversation = @conversations.first
    @messages = @current_conversation&.ai_messages || []
  end
  
  def show
    @conversation = current_user.ai_conversations.find(params[:id])
    @messages = @conversation.ai_messages.order(created_at: :asc)
  end
  
  def create
    @conversation = current_user.ai_conversations.create!(
      title: "Chat #{Time.current.strftime('%H:%M')}",
      session_type: 'chat',
      metadata: {}
    )
    
    render json: { 
      success: true, 
      conversation_id: @conversation.id,
      message: "New conversation created" 
    }
  end
  
  def send_message
    conversation_id = params[:conversation_id]
    message_content = params[:message]
    additional_context = params[:context] || {}
    
    @conversation = current_user.ai_conversations.find(conversation_id)
    
    # Use enhanced conversation memory service
    ai_response = ConversationMemoryService.call_ai_with_memory(
      @conversation, 
      message_content, 
      additional_context
    )
    
    # Save the complete exchange with memory tracking
    user_message = @conversation.ai_messages.create!(
      role: 'user',
      content: message_content,
      message_type: 'text',
      metadata: {
        context_provided: additional_context.any?,
        memory_updated: true
      }
    )
    
    ai_message = @conversation.ai_messages.create!(
      role: 'assistant',
      content: ai_response[:content],
      message_type: 'text',
      tokens_used: ai_response[:tokens_used] || 0,
      metadata: {
        confidence: ai_response[:confidence] || 0.0,
        model_used: ai_response[:model] || 'default',
        memory_context_applied: true
      }
    )
    
    # Get conversation insights
    insights = ConversationMemoryService.analyze_conversation(@conversation)
    
    render json: {
      success: true,
      user_message: {
        id: user_message.id,
        role: user_message.role,
        content: user_message.content,
        created_at: user_message.created_at
      },
      ai_message: {
        id: ai_message.id,
        role: ai_message.role,
        content: ai_message.content,
        created_at: ai_message.created_at,
        tokens_used: ai_message.tokens_used
      },
      conversation_insights: insights,
      memory_status: {
        topics: @conversation.get_from_memory('conversation_topics') || [],
        preferences: @conversation.get_from_memory('user_preferences') || {},
        health: @conversation.memory_health
      }
    }
  end
  
  def suggest_content
    topic = params[:topic]
    content_type = params[:content_type] || 'post'
    platform = params[:platform] || 'general'
    
    # Call Railway backend for AI content suggestions
    response = call_railway_ai_api(
      "Generate a #{content_type} for #{platform} about: #{topic}. Be creative and engaging.",
      [],
      { content_type: content_type, platform: platform }
    )
    
    # Save suggestion to database
    suggestion = current_user.content_suggestions.create!(
      content_type: content_type,
      topic: topic,
      suggestion: response[:content],
      confidence: response[:confidence] || 0.85,
      status: 'generated'
    )
    
    render json: {
      success: true,
      suggestion: {
        id: suggestion.id,
        content: suggestion.suggestion,
        confidence: suggestion.confidence,
        content_type: suggestion.content_type
      }
    }
  end
  
  private
  
  def call_railway_ai_api(prompt, previous_messages, context = {})
    begin
      # Call Railway backend API
      response = RestClient.post(
        "#{ENV['RAILWAY_BACKEND_URL']}/api/ai/chat",
        {
          message: prompt,
          conversation: previous_messages.map { |m| { role: m.role, content: m.content } },
          context: context,
          user_id: current_user.id
        },
        {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{ENV['RAILWAY_API_KEY']}"
        }
      )
      
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