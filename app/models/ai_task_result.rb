class AiTaskResult < ApplicationRecord
  belongs_to :user
  
  # Serialized fields
  serialize :result_data, JSON
  
  # Enums
  enum task_type: {
    content_generation: 'content_generation',
    performance_analysis: 'performance_analysis',
    trends_analysis: 'trends_analysis',
    ai_insights: 'ai_insights',
    content_optimization: 'content_optimization',
    engagement_analysis: 'engagement_analysis'
  }
  
  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_task_type, ->(type) { where(task_type: type) }
  
  # Default values
  before_validation :set_defaults, on: :create
  
  def view_result
    # Format result data for display
    case task_type
    when 'performance_analysis'
      format_performance_analysis(result_data)
    when 'trends_analysis'
      format_trends_analysis(result_data)
    when 'ai_insights'
      format_ai_insights(result_data)
    when 'content_optimization'
      format_content_optimization(result_data)
    when 'engagement_analysis'
      format_engagement_analysis(result_data)
    else
      result_data.to_s
    end
  end
  
  private
  
  def format_performance_analysis(data)
    "Performance Analysis Results:\n\n" +
    "Insights:\n" +
    data['insights']&.join("\n") || "No insights available"
  end
  
  def format_trends_analysis(data)
    "Trends Analysis Results:\n\n" +
    "Trending Topics: #{data['trending_topics'] || 'No trending topics identified'}\n" +
    "Generated Content: #{data['generated_content'] || 0} pieces"
  end
  
  def format_ai_insights(data)
    "AI Insights Results:\n\n" +
    (data['insights']&.map { |insight| "• [#{insight['type'].titleize}] #{insight['insights']}" }&.join("\n") || "No insights generated")
  end
  
  def format_content_optimization(data)
    "Content Optimization Results:\n\n" +
    "Optimized Content: #{data['optimized_count'] || 0} pieces\n" +
    "Focus: #{data['focus'] || 'General'}"
  end
  
  def format_engagement_analysis(data)
    "Engagement Analysis Results:\n\n" +
    "Platforms: #{data['platforms']}\n" +
    "Has Predictions: #{data['has_predictions'] ? 'Yes' : 'No'}"
  end
  
  def set_defaults
    self.task_type ||= :content_generation
  end
end