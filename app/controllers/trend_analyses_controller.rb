class TrendAnalysesController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @trend_service = TrendDetectionService.new(current_user)
    @trends = @trend_service.detect_all_trends
    @insights = @trend_service.generate_insights(@trends)
  end

  def show
    @trend_service = TrendDetectionService.new(current_user)
    @trends = @trend_service.detect_all_trends
    
    case params[:type]
    when 'content'
      @trend_data = @trends[:content_trends]
    when 'engagement'
      @trend_data = @trends[:engagement_trends]
    when 'platform'
      @trend_data = @trends[:platform_trends]
    when 'timing'
      @trend_data = @trends[:timing_trends]
    when 'sentiment'
      @trend_data = @trends[:sentiment_trends]
    when 'topic'
      @trend_data = @trends[:topic_trends]
    else
      @trend_data = @trends
    end
  end

  def analyze_period
    @trend_service = TrendDetectionService.new(current_user)
    @trends = @trend_service.detect_all_trends
    @insights = @trend_service.generate_insights(@trends)
    
    # Allow custom date range
    if params[:start_date] && params[:end_date]
      @trend_service.instance_variable_set(:@analysis_days, 
        (Date.parse(params[:end_date]) - Date.parse(params[:start_date])).to_i)
      @trends = @trend_service.detect_all_trends
    end
    
    render :index
  end

  def export_trends
    @trend_service = TrendDetectionService.new(current_user)
    @trends = @trend_service.detect_all_trends
    @csv_data = generate_trends_csv(@trends)
    send_data @csv_data, filename: "trend_analysis_#{Date.current}.csv"
  end

  private

  def generate_trends_csv(trends)
    CSV.generate do |csv|
      csv << ['Trend Type', 'Item', 'Current Value', 'Previous Value', 'Change %', 'Direction']
      
      trends.each do |trend_type, trend_data|
        next unless trend_data.is_a?(Array)
        
        trend_data.each do |item|
          csv << [
            trend_type.to_s.humanize,
            item[:content_type] || item[:platform] || item[:keyword] || item[:hour]&.to_s || item[:date]&.to_s || 'N/A',
            item[:current_count] || item[:current_engagement] || item[:recent_frequency] || item[:avg_engagement] || item[:sentiment_score] || 'N/A',
            item[:previous_count] || item[:previous_engagement] || item[:previous_frequency] || item[:previous_sentiment] || 'N/A',
            item[:change_percent] || 'N/A',
            item[:trend_direction] || 'N/A'
          ]
        end
      end
    end
  end
end