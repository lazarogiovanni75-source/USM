class PostPerformanceOverviewService
  def initialize(user = nil)
    @user = user
  end
  
  def get_post_performance(post_id)
    post = ScheduledPost.includes(:content, :performance_metrics).find_by(id: post_id, user_id: @user.id)
    return nil unless post
    
    metrics = post.performance_metrics
    total_engagements = metrics.sum(:likes) + metrics.sum(:comments) + metrics.sum(:shares)
    engagement_rate = metrics.sum(:views) > 0 ? (total_engagements.to_f / metrics.sum(:views) * 100) : 0
    
    performance_score = calculate_performance_score(post, total_engagements, engagement_rate)
    comparisons = get_post_comparisons(post, total_engagements, engagement_rate)
    recommendations = get_post_recommendations(post, total_engagements, engagement_rate)
    timeline_data = get_post_timeline_data(metrics)
    
    {
      post: post,
      metrics: {
        likes: metrics.sum(:likes) || 0,
        comments: metrics.sum(:comments) || 0,
        shares: metrics.sum(:shares) || 0,
        views: metrics.sum(:views) || 0,
        clicks: metrics.sum(:clicks) || 0,
        reach: metrics.sum(:reach) || 0,
        impressions: metrics.sum(:impressions) || 0,
        total_engagements: total_engagements,
        engagement_rate: engagement_rate.round(2)
      },
      performance_score: performance_score,
      comparisons: comparisons,
      recommendations: recommendations,
      timeline_data: timeline_data,
      benchmarks: get_platform_benchmarks(post.platform)
    }
  end
  
  def get_posts_performance_summary(post_ids = nil)
    posts = @user.scheduled_posts.includes(:content, :performance_metrics)
    posts = posts.where(id: post_ids) if post_ids.present?
    
    performance_data = posts.map do |post|
      metrics = post.performance_metrics
      total_engagements = metrics.sum(:likes) + metrics.sum(:comments) + metrics.sum(:shares)
      engagement_rate = metrics.sum(:views) > 0 ? (total_engagements.to_f / metrics.sum(:views) * 100) : 0
      
      {
        post_id: post.id,
        title: post.content.title,
        platform: post.platform,
        scheduled_at: post.scheduled_at,
        posted_at: post.posted_at,
        status: post.status,
        total_engagements: total_engagements,
        engagement_rate: engagement_rate.round(2),
        performance_score: calculate_performance_score(post, total_engagements, engagement_rate)
      }
    end
    
    {
      posts: performance_data,
      summary: calculate_posts_summary(performance_data),
      top_performers: performance_data.sort_by { |p| -p[:performance_score] }.first(5),
      underperformers: performance_data.sort_by { |p| p[:performance_score] }.first(5)
    }
  end
  
  def get_performance_insights(days = 30)
    posts = @user.scheduled_posts.includes(:content, :performance_metrics)
                  .where('scheduled_posts.posted_at >= ?', days.days.ago)
                  .where('scheduled_posts.posted_at <= ?', Time.current)
    
    insights = []
    
    # Platform performance insights
    platform_stats = posts.group(:platform).map do |platform, platform_posts|
      total_engagements = platform_posts.sum { |post| post.performance_metrics.sum(:likes) + post.performance_metrics.sum(:comments) + post.performance_metrics.sum(:shares) }
      avg_engagement_rate = platform_posts.sum { |post| post.performance_metrics.sum(:views) > 0 ? (post.performance_metrics.sum(:likes) + post.performance_metrics.sum(:comments) + post.performance_metrics.sum(:shares)).to_f / post.performance_metrics.sum(:views) * 100 : 0 } / platform_posts.count
      
      {
        platform: platform,
        post_count: platform_posts.count,
        total_engagements: total_engagements,
        avg_engagement_rate: avg_engagement_rate.round(2)
      }
   _platform = platform_stats end
    
    best.max_by { |stats| stats[:avg_engagement_rate] }
    worst_platform = platform_stats.min_by { |stats| stats[:avg_engagement_rate] }
    
    if best_platform && worst_platform
      if best_platform[:avg_engagement_rate] > worst_platform[:avg_engagement_rate] * 2
        insights << {
          type: 'platform_opportunity',
          title: 'Platform Performance Gap',
          description: "#{best_platform[:platform].capitalize} performs #{((best_platform[:avg_engagement_rate] / worst_platform[:avg_engagement_rate] - 1) * 100).round(1)}% better than #{worst_platform[:platform].capitalize}. Consider focusing more on #{best_platform[:platform]}.",
          action: 'focus_platform',
          data: { best_platform: best_platform, worst_platform: worst_platform }
        }
      end
    end
    
    # Content type insights
    content_stats = posts.joins(:content).group('contents.category').map do |category, category_posts|
      total_engagements = category_posts.sum { |post| post.performance_metrics.sum(:likes) + post.performance_metrics.sum(:comments) + post.performance_metrics.sum(:shares) }
      avg_engagement_rate = category_posts.sum { |post| post.performance_metrics.sum(:views) > 0 ? (post.performance_metrics.sum(:likes) + post.performance_metrics.sum(:comments) + post.performance_metrics.sum(:shares)).to_f / post.performance_metrics.sum(:views) * 100 : 0 } / category_posts.count
      
      {
        category: category,
        post_count: category_posts.count,
        total_engagements: total_engagements,
        avg_engagement_rate: avg_engagement_rate.round(2)
      }
    end
    
    best_content_type = content_stats.max_by { |stats| stats[:avg_engagement_rate] }
    if best_content_type && best_content_type[:post_count] < 5
      insights << {
        type: 'content_opportunity',
        title: 'Underutilized High-Performing Content',
        description: "#{best_content_type[:category].capitalize} content has high engagement (#{best_content_type[:avg_engagement_rate]}%) but you're not posting much. Consider creating more #{best_content_type[:category]} content.",
        action: 'create_content',
        data: { category: best_content_type[:category] }
      }
    end
    
    # Timing insights
    timing_insights = get_timing_insights(posts)
    insights.concat(timing_insights)
    
    insights
  end
  
  def generate_performance_report(post_ids = nil, format = 'json')
    posts = @user.scheduled_posts.includes(:content, :performance_metrics)
    posts = posts.where(id: post_ids) if post_ids.present?
    
    report_data = {
      generated_at: Time.current,
      user: @user.email,
      period: {
        start: posts.minimum(:posted_at),
        end: posts.maximum(:posted_at),
        post_count: posts.count
      },
      performance_summary: get_posts_performance_summary(post_ids),
      insights: get_performance_insights(30),
      recommendations: generate_report_recommendations(posts)
    }
    
    case format
    when 'json'
      report_data
    when 'html'
      # Generate HTML report (would be implemented in a separate template)
      report_data
    else
      raise "Unsupported format: #{format}"
    end
  end
  
  private
  
  def calculate_performance_score(post, total_engagements, engagement_rate)
    # Performance score based on multiple factors
    base_score = 0
    
    # Engagement rate weight (40%)
    if engagement_rate > 5
      base_score += 40
    elsif engagement_rate > 2
      base_score += 30
    elsif engagement_rate > 1
      base_score += 20
    else
      base_score += 10
    end
    
    # Total engagement weight (30%)
    if total_engagements > 1000
      base_score += 30
    elsif total_engagements > 500
      base_score += 25
    elsif total_engagements > 100
      base_score += 20
    else
      base_score += 10
    end
    
    # Platform performance weight (20%)
    platform_avg = get_platform_average_engagement(post.platform)
    if total_engagements > platform_avg * 1.5
      base_score += 20
    elsif total_engagements > platform_avg
      base_score += 15
    else
      base_score += 10
    end
    
    # Timing weight (10%)
    optimal_hour = 10 # 10 AM is generally good
    post_hour = post.posted_at&.hour || 12
    time_diff = (post_hour - optimal_hour).abs
    
    if time_diff <= 2
      base_score += 10
    elsif time_diff <= 4
      base_score += 7
    else
      base_score += 5
    end
    
    [base_score, 100].min
  end
  
  def get_post_comparisons(post, total_engagements, engagement_rate)
    comparisons = {}
    
    # Compare with user's average
    user_avg_engagement = @user.scheduled_posts.joins(:performance_metrics)
                               .sum('likes + comments + shares')
    user_post_count = @user.scheduled_posts.count
    user_avg_per_post = user_post_count > 0 ? user_avg_engagement.to_f / user_post_count : 0
    
    comparisons[:user_average] = {
      engagement_vs_user: total_engagements > user_avg_per_post ? 'above' : 'below',
      engagement_difference: (total_engagements - user_avg_per_post).round(1),
      engagement_percentage: user_avg_per_post > 0 ? ((total_engagements / user_avg_per_post - 1) * 100).round(1) : 0
    }
    
    # Compare with platform average
    platform_avg = get_platform_average_engagement(post.platform)
    comparisons[:platform_average] = {
      engagement_vs_platform: total_engagements > platform_avg ? 'above' : 'below',
      engagement_difference: (total_engagements - platform_avg).round(1),
      engagement_percentage: platform_avg > 0 ? ((total_engagements / platform_avg - 1) * 100).round(1) : 0
    }
    
    # Compare with similar posts
    similar_posts = @user.scheduled_posts.joins(:content)
                        .where('contents.category = ?', post.content.category)
                        .where('scheduled_posts.platform = ?', post.platform)
                        .includes(:performance_metrics)
    
    if similar_posts.count > 1
      similar_avg = similar_posts.sum { |p| p.performance_metrics.sum(:likes) + p.performance_metrics.sum(:comments) + p.performance_metrics.sum(:shares) }.to_f / similar_posts.count
      
      comparisons[:similar_posts] = {
        engagement_vs_similar: total_engagements > similar_avg ? 'above' : 'below',
        engagement_difference: (total_engagements - similar_avg).round(1),
        engagement_percentage: similar_avg > 0 ? ((total_engagements / similar_avg - 1) * 100).round(1) : 0
      }
    end
    
    comparisons
  end
  
  def get_post_recommendations(post, total_engagements, engagement_rate)
    recommendations = []
    
    if engagement_rate < 1
      recommendations << {
        type: 'engagement_improvement',
        title: 'Low Engagement Rate',
        description: 'Your engagement rate is below 1%. Consider adding more interactive elements like questions, polls, or calls-to-action.',
        priority: 'high'
      }
    end
    
    if total_engagements < get_platform_average_engagement(post.platform) * 0.5
      recommendations << {
        type: 'reach_improvement',
        title: 'Below Average Reach',
        description: 'Your post is performing below the platform average. Consider optimizing your posting time or improving your content strategy.',
        priority: 'medium'
      }
    end
    
    # Timing recommendations
    optimal_hour = 10
    post_hour = post.posted_at&.hour || 12
    if (post_hour - optimal_hour).abs > 4
      recommendations << {
        type: 'timing_optimization',
        title: 'Timing Optimization',
        description: "Consider posting around 10 AM for better engagement. Your post was published at #{post_hour}:00.",
        priority: 'low'
      }
    end
    
    recommendations
  end
  
  def get_post_timeline_data(metrics)
    # This would typically come from actual timeline data
    # For now, we'll simulate some data points
    data_points = []
    days_ago = 7
    
    days_ago.times do |i|
      date = i.days.ago.to_date
      data_points << {
        date: date,
        likes: rand(50..200),
        comments: rand(10..50),
        shares: rand(5..25),
        views: rand(500..2000)
      }
    end
    
    data_points
  end
  
  def get_platform_benchmarks(platform)
    # Industry benchmarks by platform
    benchmarks = {
      instagram: {
        avg_engagement_rate: 2.5,
        avg_likes_per_post: 1500,
        avg_comments_per_post: 75,
        optimal_posting_times: [9, 10, 11, 14, 15, 17, 18, 19]
      },
      twitter: {
        avg_engagement_rate: 1.2,
        avg_likes_per_post: 100,
        avg_comments_per_post: 25,
        optimal_posting_times: [9, 10, 11, 13, 15, 17, 18, 19]
      },
      linkedin: {
        avg_engagement_rate: 4.2,
        avg_likes_per_post: 300,
        avg_comments_per_post: 40,
        optimal_posting_times: [8, 9, 10, 11, 12, 13, 14, 15]
      },
      facebook: {
        avg_engagement_rate: 3.1,
        avg_likes_per_post: 800,
        avg_comments_per_post: 50,
        optimal_posting_times: [9, 10, 11, 13, 14, 15, 16, 17]
      }
    }
    
    benchmarks[platform.to_sym] || benchmarks[:instagram]
  end
  
  def get_platform_average_engagement(platform)
    avg_engagement = {
      instagram: 150,
      twitter: 75,
      linkedin: 200,
      facebook: 300,
      tiktok: 500
    }
    
    avg_engagement[platform.to_sym] || 150
  end
  
  def calculate_posts_summary(posts_data)
    return {} if posts_data.empty?
    
    total_posts = posts_data.count
    total_engagements = posts_data.sum { |p| p[:total_engagements] }
    avg_engagement_rate = posts_data.sum { |p| p[:engagement_rate] } / total_posts
    avg_performance_score = posts_data.sum { |p| p[:performance_score] } / total_posts
    
    {
      total_posts: total_posts,
      total_engagements: total_engagements,
      avg_engagement_rate: avg_engagement_rate.round(2),
      avg_performance_score: avg_performance_score.round(1),
      top_platform: posts_data.group_by { |p| p[:platform] }.max_by { |platform, posts| posts.sum { |p| p[:total_engagements] } }&.first,
      best_performing_day: get_best_performing_day(posts_data)
    }
  end
  
  def get_best_performing_day(posts_data)
    # Group by day of week and find best
    day_performance = posts_data.group_by { |p| p[:posted_at]&.strftime('%A') }
                              .transform_values { |posts| posts.sum { |p| p[:total_engagements] } }
    
    day_performance.max_by { |day, engagements| engagements }&.first
  end
  
  def get_timing_insights(posts)
    insights = []
    
    # Analyze posting times
    timing_data = posts.group_by { |post| post.posted_at&.hour }
    timing_stats = timing_data.transform_values do |posts_at_hour|
      total_engagements = posts_at_hour.sum { |post| post.performance_metrics.sum(:likes) + post.performance_metrics.sum(:comments) + post.performance_metrics.sum(:shares) }
      posts_at_hour.count > 0 ? total_engagements.to_f / posts_at_hour.count : 0
    end
    
    best_hour = timing_stats.max_by { |hour, avg| avg }
    worst_hour = timing_stats.min_by { |hour, avg| avg }
    
    if best_hour && worst_hour && best_hour[1] > worst_hour[1] * 2
      insights << {
        type: 'timing_opportunity',
        title: 'Optimal Posting Time',
        description: "Posts at #{best_hour[0]}:00 perform #{((best_hour[1] / worst_hour[1] - 1) * 100).round(1)}% better than at #{worst_hour[0]}:00. Consider scheduling more posts during optimal hours.",
        action: 'optimize_schedule',
        data: { best_hour: best_hour[0], worst_hour: worst_hour[0] }
      }
    end
    
    insights
  end
  
  def generate_report_recommendations(posts)
    recommendations = []
    
    if posts.count < 10
      recommendations << {
        type: 'data_collection',
        title: 'Collect More Data',
        description: 'You need at least 10 posts for meaningful analytics. Continue posting to get better insights.',
        priority: 'medium'
      }
    end
    
    platform_distribution = posts.group(:platform).count
    if platform_distribution.size == 1
      recommendations << {
        type: 'platform_diversification',
        title: 'Platform Diversification',
        description: 'You\'re only posting on one platform. Consider expanding to other platforms for better reach.',
        priority: 'low'
      }
    end
    
    recommendations
  end
end