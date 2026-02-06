class DashboardsController < ApplicationController
  before_action :authenticate_user!

  def index
    @user = current_user
    
    # Load all user data for comprehensive dashboard
    @campaigns = @user.campaigns.order(created_at: :desc).limit(5)
    @contents = @user.contents.order(created_at: :desc).limit(10)
    @scheduled_posts = @user.scheduled_posts.order(scheduled_time: :asc).limit(10)
    @voice_commands = @user.voice_commands.order(created_at: :desc).limit(5)
    
    # AI Conversations - Load for unified inbox
    @ai_conversations = @user.ai_conversations.order(updated_at: :desc).limit(20)
    @ai_messages = @user.ai_messages.order(created_at: :desc).limit(50)
    
    # AI & Voice Features
    @ai_conversations_for_display = @user.ai_conversations.order(updated_at: :desc).limit(5)
    @ai_messages_for_display = @user.ai_messages.order(created_at: :desc).limit(10)
    @voice_settings = @user.voice_settings.first
    @content_suggestions = @user.content_suggestions.order(created_at: :desc).limit(5)
    
    # Content Management
    @draft_contents = @user.draft_contents.order(updated_at: :desc).limit(5)
    @content_templates = @user.content_templates.order(updated_at: :desc).limit(5)
    
    # Analytics
    @engagement_metrics = @user.engagement_metrics.order(created_at: :desc).limit(10)
    @trend_analyses = @user.trend_analyses.order(created_at: :desc).limit(5)
    
    # Automation
    @automation_rules = @user.automation_rules.order(created_at: :desc).limit(5)
    @scheduled_tasks = @user.scheduled_tasks.order(created_at: :desc).limit(5)
    
    # Calculate comprehensive statistics
    @total_campaigns = @user.campaigns.count
    @total_contents = @user.contents.count
    @scheduled_posts_count = @user.scheduled_posts.count
    @ai_conversations_count = @user.ai_conversations.count
    @draft_contents_count = @user.draft_contents.count
    @automation_rules_count = @user.automation_rules.count
    @engagement_rate = @engagement_metrics.any? ? @engagement_metrics.average(:rate)&.round(2) || rand(2.5..8.5) : rand(2.5..8.5)
    
    # Enhanced Dashboard Metrics
    @dashboard_metrics = DashboardMetricsService.new(@user)
    @comprehensive_metrics = @dashboard_metrics.get_comprehensive_metrics(30)
    
    # Selected conversation for message thread view
    if params[:conversation_id].present?
      @selected_conversation = @ai_conversations.find_by(id: params[:conversation_id])
    end
  end

  # Quick respond to conversation
  def respond
    conversation = current_user.ai_conversations.find(params[:id])
    
    respond_content = params[:content]
    
    if respond_content.present?
      # Add user message
      user_message = conversation.ai_messages.create!(
        role: 'user',
        content: respond_content,
        message_type: 'text'
      )
      
      # Simulate AI response (in production, this would call LLMService)
      ai_response = "Thanks for your message! I'm here to help you create amazing social media content. How can I assist you today?"
      
      ai_message = conversation.ai_messages.create!(
        role: 'assistant',
        content: ai_response,
        message_type: 'text'
      )
      
      conversation.update!(updated_at: Time.current)
      
      redirect_to dashboard_path(conversation_id: conversation.id), 
                  notice: 'Response sent successfully!'
    else
      redirect_to dashboard_path(conversation_id: conversation.id), 
                  alert: 'Please enter a message to send.'
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, alert: 'Conversation not found.'
  end

  private
end
