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
    
    # Return HTML fragment for Turbo Stream update
    render partial: "ai_answer", locals: { answer: response[:content] }
  end
end
