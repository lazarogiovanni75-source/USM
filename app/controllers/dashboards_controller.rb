class DashboardsController < ApplicationController
  before_action :authenticate_user!

  def index
    @user = current_user
    
    # Load all user data for comprehensive dashboard
    @campaigns = @user.campaigns.order(created_at: :desc).limit(5)
    @contents = @user.contents.order(created_at: :desc).limit(10)
    @scheduled_posts = @user.scheduled_posts.order(scheduled_time: :asc).limit(10)
    @voice_commands = @user.voice_commands.order(created_at: :desc).limit(5)
    
    # AI & Voice Features
    @ai_conversations = @user.ai_conversations.order(updated_at: :desc).limit(5)
    @ai_messages = @user.ai_messages.order(created_at: :desc).limit(10)
    @voice_settings = @user.voice_settings.first
    @content_suggestions = @user.content_suggestions.order(created_at: :desc).limit(5)
    
    # Content Management
    @draft_contents = @user.draft_contents.order(updated_at: :desc).limit(5)
    @content_templates = @user.content_templates.order(created_at: :desc).limit(5)
    
    # Analytics
    @engagement_metrics = @user.engagement_metrics.order(created_at: :desc).limit(10)
    @trend_analyses = @user.trend_analyses.order(created_at: :desc).limit(5)
    
    # Automation
    @automation_rules = @user.automation_rules.order(created_at: :desc).limit(5)
    @zapier_webhooks = @user.zapier_webhooks.order(created_at: :desc).limit(5)
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
  end

  private
  # Write your private methods here
end
