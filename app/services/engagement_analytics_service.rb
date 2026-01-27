class EngagementAnalyticsService
  def initialize(user = nil)
    @user = user
  end
  
  def get_engagement_metrics(date_range = 30.days.ago..Time.current)
    # Get performance metrics for user's content
    metrics = PerformanceMetric.joins(:scheduled_post)
                              .where(scheduled_posts: { user_id: @user.id })
                              .where('performance_metrics.created_at >= ?', date_range.begin)
                              .where('performance_metrics.created_at <= ?', date_range.end)
    
    # Aggregate metrics
    total_posts = metrics.count
    total_likes = metrics.sum(:likes) || 0
    total_comments = metrics.sum(:comments) || 0
    total_shares = metrics.sum(:shares) || 0
    total_views = metrics.sum(:views) || 0
    total_engagements = total_likes + total_comments + total_shares
    
    # Calculate engagement rates
    engagement_rate = total_posts > 0 ? (total_engagements.to_f / total_views * 100) : 0
    comment_rate = total_posts > 0 ? (total_comments.to_f / total_engagements * 100) : 0
    share_rate = total_posts > 0 ? (total_shares.to_f / total_engagements * 100) : 0
    
    # Get platform breakdown
    platform_breakdown = get_platform_breakdown(metrics)
    
    # Get trending content
    top_posts = get_top_performing_posts(metrics)
    
    # Get posting time insights
    time_insights = get_posting_time_insights(metrics)
    
    {
      overview: {
        total_posts: total_posts,
        total_likes: total_likes,
        total_comments: total_comments,
        total_shares: total_shares,
        total_views: total_views,
        total_engagements: total_engagements,
        engagement_rate: engagement_rate.round(2),
        comment_rate: comment_rate.round(2),
        share_rate: share_rate.round(2)
      },
      platform_breakdown: platform_breakdown,
      top_posts: top_posts,
      time_insights: time_insights,
      trend_data: get_trend_data(metrics, date_range)
    }
  end
  
  def get_best_posting_times(days = 30)
    # Analyze engagement by posting time
    metrics = PerformanceMetric.joins(:scheduled_post)
                              .where(scheduled_posts: { user_id: @user.id })
                              .where('scheduled_posts.posted_at >= ?', days.days.ago)
                              .where('scheduled_posts.posted_at <= ?', Time.current)
    
    # Group by hour and calculate average engagement
    hourly_stats = {}
    (0..23).each do |hour|
      hour_metrics = metrics.where('EXTRACT(hour FROM scheduled_posts.posted_at) = ?', hour)
      next if hour_metrics.empty?
      
      total_engagements = hour_metrics.sum(:likes) + hour_metrics.sum(:comments) + hour_metrics.sum(:shares)
      post_count = hour_metrics.count
      avg_engagement = post_count > 0 ? total_engagements.to_f / post_count : 0
      
      hourly_stats[hour] = {
        avg_engagement: avg_engagement,
        post_count: post_count,
        total_engagements: total_engagements
      }
    end
    
    # Sort by average engagement
    best_times = hourly_stats.sort_by { |hour, stats| -stats[:avg_engagement] }.first(5)
    
    {
      hourly_stats: hourly_stats,
      best_times: best_times.map { |hour, stats| { hour: hour, avg_engagement: stats[:avg_engagement] } },
      recommendations: generate_time_recommendations(best_times)
    }
  end
  
  def get_content_type_performance(days = 30)
    # Analyze performance by content type/category
    metrics = PerformanceMetric.joins(:scheduled_post => :content)
                              .where(scheduled_posts: { user_id: @user.id })
                              .where('scheduled_posts.posted_at >= ?', days.days.ago)
                              .where('scheduled_posts.posted_at <= ?', Time.current)
    
    category_stats = {}
    Content.categories.keys.each do |category|
      category_metrics = metrics.where(contents: { category: category })
      next if category_metrics.empty?
      
      total_engagements = category_metrics.sum(:likes) + category_metrics.sum(:comments) + category_metrics.sum(:shares)
      post_count = category_metrics.count
      avg_engagement = post_count > 0 ? total_engagements.to_f / post_count : 0
      
      category_stats[category] = {
        post_count: post_count,
        avg_engagement: avg_engagement,
        total_engagements: total_engagements,
        avg_likes: post_count > 0 ? category_metrics.sum(:likes).to_f / post_count : 0,
        avg_comments: post_count > 0 ? category_metrics.sum(:comments).to_f / post_count : 0,
        avg_shares: post_count > 0 ? category_metrics.sum(:shares).to_f / post_count : 0
      }
    end
    
    # Sort by average engagement
    sorted_categories = category_stats.sort_by { |category, stats| -stats[:avg_engagement] }
    
    {
      category_stats: category_stats,
      top_categories: sorted_categories.first(5),
      recommendations: generate_category_recommendations(sorted_categories)
    }
  end
  
  def get_audience_growth_insights(days = 30)
    # Analyze follower growth and engagement trends
    metrics = PerformanceMetric.joins(:scheduled_post)
                              .where(scheduled_posts: { user_id: @user.id })
                              .where('performance_metrics.created_at >= ?', days.days.ago)
                              .where('performance_metrics.created_at <= ?', Time.current)
                              .order('performance_metrics.created_at ASC')
    
    # Group by week for growth analysis
    weekly_data = {}
    weeks_ago = (days / 7).to_i
    
    weeks_ago.times do |week|
      week_start = (weeks_ago - week).weeks.ago.beginning_of_week
      week_end = week_start.end_of_week
      
      week_metrics = metrics.where('performance_metrics.created_at >= ?', week_start)
                          .where('performance_metrics.created_at <= ?', week_end)
      
      total_engagements = week_metrics.sum(:likes) + week_metrics.sum(:comments) + week_metrics.sum(:shares)
      post_count = week_metrics.count
      
      weekly_data[week_start.strftime('%Y-%m-%d')] = {
        week: "Week #{weeks_ago - week}",
        post_count: post_count,
        total_engagements: total_engagements,
        avg_engagement: post_count > 0 ? total_engagements.to_f / post_count : 0
      }
    end
    
    # Calculate growth trends
    if weekly_data.size >= 2
      recent_avg = weekly_data.values.first(2).sum { |w| w[:avg_engagement] } / 2
      older_avg = weekly_data.values.last(2).sum { |w| w[:avg_engagement] } / 2
      
      growth_rate = older_avg > 0 ? ((recent_avg - older_avg) / older_avg * 100) : 0
    else
      growth_rate = 0
    end
    
    {
      weekly_data: weekly_data,
      growth_rate: growth_rate.round(2),
      trend: growth_rate > 5 ? 'increasing' : growth_rate < -5 ? 'decreasing' : 'stable'
    }
  end
  
  def get_content_suggestions
    # Generate content suggestions based on performance data
    suggestions = []
    
    # Get best performing categories
    category_performance = get_content_type_performance
    top_category = category_performance[:top_categories].first
    
    if top_category
      suggestions << {
        type: 'category_focus',
        title: 'Focus on Your Top-Performing Category',
        description: "Your #{top_category[0]} content performs best with #{top_category[1][:avg_engagement].round(1)} average engagements. Consider creating more #{top_category[0]} content.",
        action: 'create_content',
        data: { category: top_category[0] }
      }
    end
    
    # Get best posting times
    posting_times = get_best_posting_times
    best_time = posting_times[:best_times].first
    
    if best_time
      suggestions << {
        type: 'posting_time',
        title: 'Optimal Posting Time',
        description: "Your audience is most engaged at #{best_time[:hour]}:00 with an average of #{best_time[:avg_engagement].round(1)} engagements per post.",
        action: 'schedule_post',
        data: { optimal_hour: best_time[:hour] }
      }
    end
    
    # Engagement rate suggestion
    metrics = get_engagement_metrics
    if metrics[:overview][:engagement_rate] < 2
      suggestions << {
        type: 'engagement_improvement',
        title: 'Boost Your Engagement Rate',
        description: 'Your engagement rate is below 2%. Consider asking questions, using polls, or creating more interactive content.',
        action: 'create_interactive_content',
        data: {}
      }
    end
    
    suggestions
  end
  
  private
  
  def get_platform_breakdown(metrics)
    metrics.joins(:scheduled_post)
           .group('scheduled_posts.platform')
           .sum(:likes, :comments, :shares, :views)
           .transform_keys(&:capitalize)
  end
  
  def get_top_performing_posts(metrics)
    metrics.joins(:scheduled_post => :content)
           .select('performance_metrics.*, contents.title, scheduled_posts.platform')
           .order('(likes + comments + shares) DESC')
           .limit(5)
           .map do |metric|
             {
               title: metric.content.title,
               platform: metric.platform,
               total_engagements: metric.likes + metric.comments + metric.shares,
               likes: metric.likes,
               comments: metric.comments,
               shares: metric.shares,
               engagement_rate: metric.views > 0 ? ((metric.likes + metric.comments + metric.shares).to_f / metric.views * 100).round(2) : 0
             }
           end
  end
  
  def get_posting_time_insights(metrics)
    # Analyze performance by day of week
    dow_stats = {}
    (0..6).each do |dow|
      dow_metrics = metrics.where('EXTRACT(dow FROM scheduled_posts.posted_at) = ?', dow)
      next if dow_metrics.empty?
      
      total_engagements = dow_metrics.sum(:likes) + dow_metrics.sum(:comments) + dow_metrics.sum(:shares)
      post_count = dow_metrics.count
      avg_engagement = post_count > 0 ? total_engagements.to_f / post_count : 0
      
      dow_stats[Date::DAYNAMES[dow]] = {
        avg_engagement: avg_engagement,
        post_count: post_count
      }
    end
    
    dow_stats
  end
  
  def get_trend_data(metrics, date_range)
    # Generate daily trend data
    daily_data = {}
    current_date = date_range.begin.to_date
    
    while current_date <= date_range.end.to_date
      day_metrics = metrics.where('DATE(performance_metrics.created_at) = ?', current_date)
      
      total_engagements = day_metrics.sum(:likes) + day_metrics.sum(:comments) + day_metrics.sum(:shares)
      
      daily_data[current_date.strftime('%Y-%m-%d')] = {
        engagements: total_engagements,
        posts: day_metrics.count,
        likes: day_metrics.sum(:likes) || 0,
        comments: day_metrics.sum(:comments) || 0,
        shares: day_metrics.sum(:shares) || 0
      }
      
      current_date += 1.day
    end
    
    daily_data
  end
  
  def generate_time_recommendations(best_times)
    return [] if best_times.empty?
    
    best_time = best_times.first
    
    recommendations = []
    
    if best_time[1][:avg_engagement] > 100
      recommendations << "Your audience is most active at #{best_time[0]}:00. Schedule more posts during this time."
    end
    
    if best_time[1][:post_count] < 3
      recommendations << "You're not posting enough during your optimal hours. Try posting more at #{best_time[0]}:00."
    end
    
    recommendations
  end
  
  def generate_category_recommendations(sorted_categories)
    return [] if sorted_categories.empty?
    
    recommendations = []
    
    top_category = sorted_categories.first
    worst_category = sorted_categories.last
    
    recommendations << "Your #{top_category[0]} content performs best. Consider creating more #{top_category[0]} content."
    
    if worst_category[1][:avg_engagement] < top_category[1][:avg_engagement] * 0.5
      recommendations << "Consider reducing #{worst_category[0]} content or improving your approach to this category."
    end
    
    recommendations
  end
end