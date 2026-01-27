class EngagementAnalyticsController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @analytics_service = EngagementAnalyticsService.new(current_user)
    @date_range = params[:date_range] || '30'
    @days = @date_range.to_i.days.ago..Time.current
    
    @analytics = @analytics_service.get_engagement_metrics(@days)
    @best_posting_times = @analytics_service.get_best_posting_times(@date_range.to_i)
    @content_performance = @analytics_service.get_content_type_performance(@date_range.to_i)
    @audience_growth = @analytics_service.get_audience_growth_insights(@date_range.to_i)
    @content_suggestions = @analytics_service.get_content_suggestions
  end
  
  def overview
    @analytics_service = EngagementAnalyticsService.new(current_user)
    @days = params[:days]&.to_i || 30
    
    @analytics = @analytics_service.get_engagement_metrics(@days.days.ago..Time.current)
  end
  
  def posting_times
    @analytics_service = EngagementAnalyticsService.new(current_user)
    @days = params[:days]&.to_i || 30
    
    @posting_times = @analytics_service.get_best_posting_times(@days)
  end
  
  def content_performance
    @analytics_service = EngagementAnalyticsService.new(current_user)
    @days = params[:days]&.to_i || 30
    
    @content_performance = @analytics_service.get_content_type_performance(@days)
  end
  
  def audience_growth
    @analytics_service = EngagementAnalyticsService.new(current_user)
    @days = params[:days]&.to_i || 30
    
    @audience_growth = @analytics_service.get_audience_growth_insights(@days)
  end
  
  def suggestions
    @analytics_service = EngagementAnalyticsService.new(current_user)
    @suggestions = @analytics_service.get_content_suggestions
  end
  
  def export_data
    @analytics_service = EngagementAnalyticsService.new(current_user)
    @days = params[:days]&.to_i || 30
    @format = params[:format] || 'csv'
    
    @analytics = @analytics_service.get_engagement_metrics(@days.days.ago..Time.current)
    
    case @format
    when 'csv'
      @csv_output = @analytics.to_csv
      send_data @csv_output, filename: "engagement_analytics_#{Date.current}.csv"
    else
      redirect_to engagement_analytics_index_path, alert: 'Invalid export format'
    end
  end
  
  def compare_periods
    @analytics_service = EngagementAnalyticsService.new(current_user)
    @period1_days = params[:period1_days]&.to_i || 30
    @period2_days = params[:period2_days]&.to_i || 30
    
    period1_start = @period1_days.days.ago
    period2_start = (@period1_days + @period2_days).days.ago
    period2_end = @period1_days.days.ago
    
    analytics1 = @analytics_service.get_engagement_metrics(period1_start..Time.current)
    analytics2 = @analytics_service.get_engagement_metrics(period2_start..period2_end)
    
    # Calculate percentage changes
    @comparison = {
      period1: analytics1[:overview],
      period2: analytics2[:overview],
      changes: {
        total_posts: calculate_percentage_change(analytics1[:overview][:total_posts], analytics2[:overview][:total_posts]),
        total_engagements: calculate_percentage_change(analytics1[:overview][:total_engagements], analytics2[:overview][:total_engagements]),
        engagement_rate: calculate_percentage_change(analytics1[:overview][:engagement_rate], analytics2[:overview][:engagement_rate]),
        avg_likes: calculate_percentage_change(analytics1[:overview][:total_likes] / [analytics1[:overview][:total_posts], 1].max, analytics2[:overview][:total_likes] / [analytics2[:overview][:total_posts], 1].max)
      }
    }
  end
  
  private
  
  def calculate_percentage_change(current, previous)
    return 0 if previous.nil? || previous == 0
    ((current - previous) / previous * 100).round(2)
  end
end