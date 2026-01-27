class PostPerformanceOverviewController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @service = PostPerformanceOverviewService.new(current_user)
    
    # Get selected posts (default to recent posts)
    post_ids = params[:post_ids]&.split(',')
    @posts_summary = @service.get_posts_performance_summary(post_ids)
    @insights = @service.get_performance_insights(params[:days]&.to_i || 30)
  end
  
  def show
    @service = PostPerformanceOverviewService.new(current_user)
    @post_performance = @service.get_post_performance(params[:id])
    
    unless @post_performance
      redirect_to post_performance_overview_index_path, alert: 'Post not found'
      return
    end
  end
  
  def generate_report
    @service = PostPerformanceOverviewService.new(current_user)
    post_ids = params[:post_ids]&.split(',') if params[:post_ids].present?
    
    @report = @service.generate_performance_report(
      post_ids,
      params[:format] || 'json'
    )
    
    respond_to do |format|
      format.json { render json: @report }
      format.csv { 
        # CSV export logic would go here
        render plain: "CSV export not implemented yet"
      }
      format.pdf do
        # PDF generation would go here
        render plain: "PDF export not implemented yet"
      end
    end
  end
  
  def compare_posts
    @service = PostPerformanceOverviewService.new(current_user)
    
    post_ids = params[:post_ids]&.split(',')
    if post_ids.blank? || post_ids.size < 2
      redirect_to post_performance_overview_index_path, alert: 'Please select at least 2 posts to compare'
      return
    end
    
    @posts_data = @service.get_posts_performance_summary(post_ids)
    
    # Generate comparison metrics
    @comparison = generate_post_comparison(post_ids)
  end
  
  def export_data
    @service = PostPerformanceOverviewService.new(current_user)
    
    post_ids = params[:post_ids]&.split(',')
    format = params[:format] || 'csv'
    
    @data = @service.generate_performance_report(post_ids, format)
    
    case format
    when 'csv'
      respond_to do |format|
        format.csv { send_data generate_csv_data(@data), filename: "performance_report_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv" }
      end
    when 'json'
      respond_to do |format|
        format.json { render json: @data }
      end
    else
      redirect_to post_performance_overview_index_path, alert: 'Unsupported export format'
    end
  end
  
  def bulk_analytics
    @service = PostPerformanceOverviewService.new(current_user)
    
    # Filter posts based on criteria
    criteria = {
      platform: params[:platform],
      category: params[:category],
      date_range: params[:date_range] || '30',
      min_engagement: params[:min_engagement]&.to_i
    }
    
    filtered_posts = filter_posts_by_criteria(criteria)
    @analytics = @service.get_posts_performance_summary(filtered_posts.map(&:id))
  end
  
  def post_insights
    @service = PostPerformanceOverviewService.new(current_user)
    @post_performance = @service.get_post_performance(params[:id])
    
    unless @post_performance
      render json: { error: 'Post not found' }, status: :not_found
      return
    end
    
    render json: {
      performance_score: @post_performance[:performance_score],
      comparisons: @post_performance[:comparisons],
      recommendations: @post_performance[:recommendations],
      benchmarks: @post_performance[:benchmarks]
    }
  end
  
  private
  
  def generate_post_comparison(post_ids)
    posts = current_user.scheduled_posts.includes(:content, :performance_metrics)
                       .where(id: post_ids)
                       .order('scheduled_posts.posted_at DESC')
    
    comparison = {
      posts: posts.map do |post|
        metrics = post.performance_metrics
        total_engagements = metrics.sum(:likes) + metrics.sum(:comments) + metrics.sum(:shares)
        engagement_rate = metrics.sum(:views) > 0 ? (total_engagements.to_f / metrics.sum(:views) * 100) : 0
        
        {
          post: post,
          metrics: {
            total_engagements: total_engagements,
            engagement_rate: engagement_rate.round(2),
            likes: metrics.sum(:likes) || 0,
            comments: metrics.sum(:comments) || 0,
            shares: metrics.sum(:shares) || 0,
            views: metrics.sum(:views) || 0
          },
          title: post.content.title,
          platform: post.platform,
          posted_at: post.posted_at
        }
      end,
      summary: {
        total_posts: posts.count,
        best_performer: posts.max_by { |post| post.performance_metrics.sum(:likes) + post.performance_metrics.sum(:comments) + post.performance_metrics.sum(:shares) },
        worst_performer: posts.min_by { |post| post.performance_metrics.sum(:likes) + post.performance_metrics.sum(:comments) + post.performance_metrics.sum(:shares) },
        average_engagement: posts.map { |post| post.performance_metrics.sum(:likes) + post.performance_metrics.sum(:comments) + post.performance_metrics.sum(:shares) }.sum / posts.count,
        engagement_range: posts.map { |post| post.performance_metrics.sum(:likes) + post.performance_metrics.sum(:comments) + post.performance_metrics.sum(:shares) }.minmax
      }
    }
  end
  
  def filter_posts_by_criteria(criteria)
    posts = current_user.scheduled_posts.includes(:content, :performance_metrics)
    
    posts = posts.where(platform: criteria[:platform]) if criteria[:platform].present?
    posts = posts.joins(:content).where('contents.category = ?', criteria[:category]) if criteria[:category].present?
    
    if criteria[:date_range].present?
      days = criteria[:date_range].to_i.days.ago
      posts = posts.where('scheduled_posts.posted_at >= ?', days)
    end
    
    if criteria[:min_engagement].present?
      # This would need a more complex query with joins
      # For now, we'll filter in memory
      posts = posts.select do |post|
        total_engagements = post.performance_metrics.sum(:likes) + post.performance_metrics.sum(:comments) + post.performance_metrics.sum(:shares)
        total_engagements >= criteria[:min_engagement]
      end
    end
    
    posts
  end
  
  def generate_csv_data(data)
    # Simple CSV generation
    CSV.generate do |csv|
      csv << ['Generated At', data[:generated_at]]
      csv << ['User', data[:user]]
      csv << ['Period Start', data[:period][:start]]
      csv << ['Period End', data[:period][:end]]
      csv << ['Post Count', data[:period][:post_count]]
      csv << []
      csv << ['Post Title', 'Platform', 'Scheduled At', 'Posted At', 'Total Engagements', 'Engagement Rate', 'Performance Score']
      
      data[:performance_summary][:posts].each do |post|
        csv << [
          post[:title],
          post[:platform],
          post[:scheduled_at],
          post[:posted_at],
          post[:total_engagements],
          post[:engagement_rate],
          post[:performance_score]
        ]
      end
    end
  end
end