# Campaign Analytics Service - Postforme Integration
class CampaignAnalyticsService
  def initialize(campaign)
    @campaign = campaign
    @user = campaign.user
  end

  # Get comprehensive performance summary
  def get_performance_summary(days = 30)
    scheduled_posts = @campaign.scheduled_posts.joins(:content, :social_account)
                              .where('scheduled_posts.scheduled_at >= ?', days.days.ago)
    
    {
      total_posts: scheduled_posts.count,
      published_posts: scheduled_posts.published.count,
      scheduled_posts: scheduled_posts.scheduled.count,
      failed_posts: scheduled_posts.failed.count,
      total_engagements: calculate_total_engagements(scheduled_posts),
      avg_engagement_rate: calculate_avg_engagement_rate(scheduled_posts),
      total_reach: calculate_total_reach(scheduled_posts),
      top_performing_post: get_top_performing_post(scheduled_posts),
      platform_breakdown: get_platform_breakdown(scheduled_posts),
      daily_stats: get_daily_stats(scheduled_posts, days)
    }
  end

  # Get trend data for the campaign
  def get_trends
    {
      engagement_trend: engagement_trend,
      reach_trend: reach_trend,
      content_trend: content_trend,
      best_performing_days: best_performing_days,
      improving_metrics: improving_metrics,
      declining_metrics: declining_metrics
    }
  end

  # Generate AI-powered recommendations
  def get_recommendations
    recommendations = []
    
    # Content recommendations
    if @campaign.contents.count < @campaign.content_count.to_i
      recommendations << {
        type: 'content',
        priority: 'high',
        title: 'Create More Content',
        description: "You're behind on your content goals. Create #{@campaign.content_count.to_i - @campaign.contents.count} more pieces to stay on track.",
        action: 'create_content'
      }
    end
    
    # Timing recommendations
    best_times = best_performing_days
    if best_times.any?
      recommendations << {
        type: 'timing',
        priority: 'medium',
        title: 'Optimal Posting Times',
        description: "Your posts perform best on #{best_times.first[:day]} around #{best_times.first[:hour]}:00. Schedule important content during these times.",
        action: 'reschedule'
      }
    end
    
    # Platform recommendations
    platform_breakdown = get_platform_breakdown(@campaign.scheduled_posts.published)
    best_platform = platform_breakdown.max_by { |_, data| data[:engagement_rate] }
    if best_platform
      recommendations << {
        type: 'platform',
        priority: 'medium',
        title: 'Focus on Top Platform',
        description: "#{best_platform[0]} is your best-performing platform with #{best_platform[1][:engagement_rate]}% engagement rate.",
        action: 'optimize'
      }
    end
    
    # Engagement recommendations
    avg_rate = calculate_avg_engagement_rate(@campaign.scheduled_posts.published)
    if avg_rate < 3.0
      recommendations << {
        type: 'engagement',
        priority: 'high',
        title: 'Boost Engagement',
        description: 'Your engagement rate is below average. Try adding more calls-to-action, questions, or interactive content.',
        action: 'improve'
      }
    end
    
    recommendations
  end

  # Get campaign health score
  def health_score
    score = 100
    
    # Deduct for low content creation
    content_ratio = @campaign.contents.count.to_f / [@campaign.content_count.to_i, 1].max
    score -= (1 - content_ratio) * 30 if content_ratio < 1
    
    # Deduct for failed posts
    failed_ratio = @campaign.scheduled_posts.failed.count.to_f / [@campaign.scheduled_posts.count, 1].max
    score -= failed_ratio * 20
    
    # Deduct for low engagement
    avg_rate = calculate_avg_engagement_rate(@campaign.scheduled_posts.published)
    score -= (5 - avg_rate) * 5 if avg_rate < 5
    
    [score.round(0), 0].max
  end

  private

  def calculate_total_engagements(posts)
    posts.joins(:performance_metrics).sum(:likes) +
    posts.joins(:performance_metrics).sum(:comments) +
    posts.joins(:performance_metrics).sum(:shares)
  end

  def calculate_avg_engagement_rate(posts)
    total_engagements = calculate_total_engagements(posts)
    total_views = posts.joins(:performance_metrics).sum(:views)
    return 0 if total_views == 0
    (total_engagements.to_f / total_views * 100).round(2)
  end

  def calculate_total_reach(posts)
    posts.joins(:performance_metrics).sum(:impressions) || 0
  end

  def get_top_performing_post(posts)
    top = posts.joins(:performance_metrics)
              .order(Arel.sql('(likes + comments + shares) DESC'))
              .first
    
    return nil unless top
    
    {
      title: top.content.title,
      platform: top.platform,
      engagement: top.performance_metrics.sum(:likes) + 
                  top.performance_metrics.sum(:comments) + 
                  top.performance_metrics.sum(:shares),
      url: post_performance_overview_path(top)
    }
  end

  def get_platform_breakdown(posts)
    breakdown = {}
    
    posts.joins(:social_account, :performance_metrics).find_each do |post|
      platform = post.social_account&.platform || 'unknown'
      
      breakdown[platform] ||= { post_count: 0, engagements: 0, views: 0 }
      breakdown[platform][:post_count] += 1
      breakdown[platform][:engagements] += post.performance_metrics.sum(:likes) + 
                                        post.performance_metrics.sum(:comments) + 
                                        post.performance_metrics.sum(:shares)
      breakdown[platform][:views] += post.performance_metrics.sum(:views)
    end
    
    breakdown.each do |platform, data|
      data[:engagement_rate] = data[:views] > 0 ? ((data[:engagements].to_f / data[:views]) * 100).round(2) : 0
    end
    
    breakdown
  end

  def get_daily_stats(posts, days)
    stats = {}
    
    days.times do |i|
      date = i.days.ago.to_date
      day_posts = posts.where('DATE(scheduled_posts.scheduled_at) = ?', date)
      
      stats[date.strftime('%Y-%m-%d')] = {
        date: date,
        posts: day_posts.count,
        engagements: day_posts.joins(:performance_metrics).sum(:likes) +
                    day_posts.joins(:performance_metrics).sum(:comments) +
                    day_posts.joins(:performance_metrics).sum(:shares)
      }
    end
    
    stats
  end

  def engagement_trend
    recent_avg = @campaign.scheduled_posts.published
                       .where('scheduled_posts.scheduled_at >= ?', 7.days.ago)
                       .joins(:performance_metrics)
                       .average(:engagement_rate) || 0
    
    older_avg = @campaign.scheduled_posts.published
                       .where('scheduled_posts.scheduled_at' => 14.days.ago..7.days.ago)
                       .joins(:performance_metrics)
                       .average(:engagement_rate) || 0
    
    change = older_avg > 0 ? ((recent_avg - older_avg) / older_avg * 100).round(2) : 0
    
    {
      recent_avg: recent_avg.round(2),
      older_avg: older_avg.round(2),
      change_percent: change,
      trend: change > 5 ? 'improving' : change < -5 ? 'declining' : 'stable'
    }
  end

  def reach_trend
    recent = @campaign.scheduled_posts.published
                   .where('scheduled_posts.scheduled_at >= ?', 7.days.ago)
                   .joins(:performance_metrics)
                   .sum(:impressions) || 0
    
    older = @campaign.scheduled_posts.published
                  .where('scheduled_posts.scheduled_at' => 14.days.ago..7.days.ago)
                  .joins(:performance_metrics)
                  .sum(:impressions) || 0
    
    change = older > 0 ? ((recent - older) / older.to_f * 100).round(2) : 0
    
    {
      recent: recent,
      older: older,
      change_percent: change,
      trend: change > 5 ? 'improving' : change < -5 ? 'declining' : 'stable'
    }
  end

  def content_trend
    recent_count = @campaign.contents.where('created_at >= ?', 7.days.ago).count
    older_count = @campaign.contents.where(created_at: 14.days.ago..7.days.ago).count
    
    change = older_count > 0 ? ((recent_count - older_count) / older_count.to_f * 100).round(2) : 0
    
    {
      recent_count: recent_count,
      older_count: older_count,
      change_percent: change,
      trend: change > 0 ? 'increasing' : change < 0 ? 'decreasing' : 'stable'
    }
  end

  def best_performing_days
    hourly_stats = {}
    
    (0..6).each do |day|
      day_posts = @campaign.scheduled_posts.published
                         .where('EXTRACT(dow FROM scheduled_posts.scheduled_at) = ?', day)
      
      next if day_posts.empty?
      
      engagements = day_posts.joins(:performance_metrics).sum(:likes) +
                   day_posts.joins(:performance_metrics).sum(:comments) +
                   day_posts.joins(:performance_metrics).sum(:shares)
      
      hourly_stats[day] = {
        day: Date::DAYNAMES[day],
        engagements: engagements,
        avg_engagement: engagements.to_f / day_posts.count
      }
    end
    
    hourly_stats.sort_by { |_, stats| -stats[:engagements] }.first(3).map { |day, stats| stats }
  end

  def improving_metrics
    metrics = []
    
    if engagement_trend[:trend] == 'improving'
      metrics << { name: 'Engagement Rate', trend: 'up' }
    end
    
    if reach_trend[:trend] == 'improving'
      metrics << { name: 'Reach', trend: 'up' }
    end
    
    metrics
  end

  def declining_metrics
    metrics = []
    
    if engagement_trend[:trend] == 'declining'
      metrics << { name: 'Engagement Rate', trend: 'down' }
    end
    
    if reach_trend[:trend] == 'declining'
      metrics << { name: 'Reach', trend: 'down' }
    end
    
    metrics
  end
end
