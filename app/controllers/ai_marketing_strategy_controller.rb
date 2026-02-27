# frozen_string_literal: true

# Controller for AI Marketing Strategy Analyzer
class AiMarketingStrategyController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @analyzer = MarketingStrategyAnalyzerService.new(current_user)
    @insights = @analyzer.quick_insights
  end
  
  def analyze
    @analyzer = MarketingStrategyAnalyzerService.new(current_user)
    time_range = params[:time_range] || 'month'
    
    @analysis = @analyzer.analyze_and_recommend(time_range)
    
    # Use Turbo Stream for partial updates
    render "analyze.turbo_stream.erb"
  end
  
  def generate_report
    @analyzer = MarketingStrategyAnalyzerService.new(current_user)
    focus_area = params[:focus_area] || 'comprehensive'
    
    @report = @analyzer.generate_strategy_report(focus_area)
    
    # Use Turbo Stream for partial updates
    render "generate_report.turbo_stream.erb"
  end
  
  def ask_ai
    question = params[:question]
    
    # Use existing AI chat infrastructure
    conversation = current_user.ai_conversations.last_or_create!(
      title: "Marketing Strategy Q&A",
      session_type: 'marketing_strategy',
      metadata: { context: 'marketing_strategy' }
    )
    
    response = ConversationMemoryService.call_ai_with_memory(
      conversation,
      question,
      { context_type: 'marketing_strategy' }
    )
    
    @answer = response[:content]
    
    # Render Turbo Stream for partial updates
    render "ask_ai.turbo_stream.erb"
  end
  
  def history
    @analyzer = MarketingStrategyAnalyzerService.new(current_user)
    @histories = @analyzer.get_history(limit: 20)
  end
  
  def trend
    @analyzer = MarketingStrategyAnalyzerService.new(current_user)
    @trend = @analyzer.get_trend
    
    # Render HTML directly - Turbo Drive will handle the page navigation
    render "trend.html.erb"
  end
  
  def execute
    @analyzer = MarketingStrategyAnalyzerService.new(current_user)
    focus_area = params[:focus_area] || 'comprehensive'
    
    # Generate strategy report
    report = @analyzer.generate_strategy_report(focus_area)
    
    # Save to history
    @analyzer.save_to_history(focus_area: focus_area, generated_by: 'manual')
    
    # Execute recommendations - create scheduled posts
    if report[:content_ideas].present?
      @created_posts = @analyzer.execute_recommendations(
        content_ideas: report[:content_ideas],
        schedule_options: { start_time: 1.day.from_now, interval_days: 1 }
      )
    else
      @created_posts = []
    end
    
    @report = report
    
    render "execute.turbo_stream.erb"
  end
end
