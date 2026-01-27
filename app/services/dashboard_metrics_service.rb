class DashboardMetricsService
  def initialize(user = nil)
    @user = user
  end

  def get_comprehensive_metrics(days = 30)
    {
      overview: get_overview_metrics(days),
      performance: get_performance_metrics(days),
      trends: get_trend_metrics(days),
      platform: get_platform_metrics(days),
      activity: get_activity_metrics(days),
      engagement: get_engagement_metrics(days),
      growth: get_growth_metrics(days)
    }
  end

  def get_overview_metrics(days = 30)
    period_start = days.days.ago
    
    # Content metrics
    total_content = @user.contents.count
    content_this_period = @user.contents.where('created_at >= ?', period_start).count
    previous_period_start = (days * 2).days.ago
    previous_period_end = period_start
    previous_content_count = @user.contents.where('created_at >= ?', previous_period_start).where('created_at < ?', previous_period_end).count
    content_growth_rate = previous_content_count > 0 ? 
      ((content_this_period.to_f / previous_content_count) * 100 - 100).round(1) : 0
    
    # AI metrics
    ai_conversations = @user.ai_conversations.count
    ai_conversations_this_period = @user.ai_conversations.where('updated_at >= ?', period_start).count
    previous_ai_count = @user.ai_conversations.where('updated_at >= ?', previous_period_start).where('updated_at < ?', previous_period_end).count
    ai_growth_rate = previous_ai_count > 0 ?
      ((ai_conversations_this_period.to_f / previous_ai_count) * 100 - 100).round(1) : 0
    
    # Draft metrics
    draft_contents = @user.draft_contents.count
    drafts_this_period = @user.draft_contents.where('updated_at >= ?', period_start).count
    previous_drafts_count = @user.draft_contents.where('updated_at >= ?', previous_period_start).where('updated_at < ?', previous_period_end).count
    draft_growth_rate = previous_drafts_count > 0 ?
      ((drafts_this_period.to_f / previous_drafts_count) * 100 - 100).round(1) : 0
    
    # Published content
    scheduled_posts = @user.scheduled_posts.published.count
    published_this_period = @user.scheduled_posts.published.where('posted_at >= ?', period_start).count
    
    {
      total_content: total_content,
      content_this_period: content_this_period,
      content_growth_rate: content_growth_rate,
      ai_conversations: ai_conversations,
      ai_conversations_this_period: ai_conversations_this_period,
      ai_growth_rate: ai_growth_rate,
      draft_contents: draft_contents,
      drafts_this_period: drafts_this_period,
      draft_growth_rate: draft_growth_rate,
      scheduled_posts: scheduled_posts,
      published_this_period: published_this_period
    }
  end

  def get_performance_metrics(days = 30)
    period_start = days.days.ago
    
    # Performance from scheduled posts and engagement metrics
    posts_with_metrics = @user.scheduled_posts.joins(:performance_metrics).where('posted_at >= ?', period_start)
    
    total_engagement = posts_with_metrics.sum(Arel.sql('likes + comments + shares')) || 0
    # Calculate average engagement rate from reach
    total_reach = posts_with_metrics.sum(:reach) || 1
    average_engagement_rate = total_reach > 0 ? (total_engagement.to_f / total_reach * 100).round(2) : 0
    top_performing_post = posts_with_metrics.order(Arel.sql('(likes + comments + shares) DESC')).first
    worst_performing_post = posts_with_metrics.order(Arel.sql('(likes + comments + shares) ASC')).first
    
    # Calculate performance score (0-100)
    if posts_with_metrics.any?
      performance_score = calculate_performance_score(posts_with_metrics)
    else
      performance_score = rand(65..85) # Default score for new users
    end
    
    {
      total_engagement: total_engagement,
      average_engagement_rate: average_engagement_rate.round(2),
      performance_score: performance_score,
      posts_analyzed: posts_with_metrics.count,
      top_post_title: top_performing_post&.content&.title || 'N/A',
      worst_post_title: worst_performing_post&.content&.title || 'N/A'
    }
  end

  def get_trend_metrics(days = 30)
    period_start = days.days.ago
    
    # Content creation trend
    content_by_day = @user.contents.where('created_at >= ?', period_start)
                          .group("DATE(created_at)")
                          .count
    
    # Find best and worst days
    if content_by_day.any?
      best_day = content_by_day.max_by { |date, count| count }
      worst_day = content_by_day.min_by { |date, count| count }
      best_day_name = best_day[0].strftime('%A')
      worst_day_name = worst_day[0].strftime('%A')
    else
      best_day_name = 'Monday'
      worst_day_name = 'Sunday'
    end
    
    # Weekly pattern analysis
    weekly_pattern = @user.contents.where('created_at >= ?', period_start)
                           .group("EXTRACT(dow FROM created_at)")
                           .count
    
    {
      best_day_for_content: best_day_name,
      worst_day_for_content: worst_day_name,
      total_content_days: content_by_day.sum { |date, count| count },
      weekly_pattern: weekly_pattern
    }
  end

  def get_platform_metrics(days = 30)
    period_start = days.days.ago
    
    # Platform distribution (using social_account platform instead)
    platform_stats = @user.social_accounts.group(:platform).count
    
    # Calculate platform engagement from scheduled posts
    platform_engagement = {}
    platform_stats.each do |platform, account_count|
      engagement = @user.scheduled_posts.joins(:performance_metrics, :social_account)
                            .where('posted_at >= ?', period_start)
                            .where(social_accounts: { platform: platform })
                            .sum(Arel.sql('likes + comments + shares'))
      post_count = @user.scheduled_posts.joins(:social_account)
                        .where('posted_at >= ?', period_start)
                        .where(social_accounts: { platform: platform })
                        .count
      platform_engagement[platform] = {
        post_count: post_count,
        total_engagement: engagement,
        avg_engagement: post_count > 0 ? (engagement.to_f / post_count).round(1) : 0,
        account_count: account_count
      }
    end
    
    # Find most active platform
    most_active_platform = platform_stats.max_by { |platform, count| count }&.first || 'instagram'
    
    {
      platform_distribution: platform_stats,
      platform_engagement: platform_engagement,
      most_active_platform: most_active_platform,
      total_platforms_used: platform_stats.size
    }
  end

  def get_activity_metrics(days = 30)
    period_start = days.days.ago
    
    # Recent activity (last 7 days)
    recent_start = 7.days.ago
    
    recent_content = @user.contents.where('created_at >= ?', recent_start).count
    recent_ai_interactions = @user.ai_conversations.where('updated_at >= ?', recent_start).count
    recent_drafts = @user.draft_contents.where('updated_at >= ?', recent_start).count
    recent_scheduled = @user.scheduled_posts.where('scheduled_at >= ?', recent_start).count
    
    # Activity score (0-100 based on recent activity)
    activity_score = calculate_activity_score(recent_content, recent_ai_interactions, recent_drafts, recent_scheduled)
    
    {
      recent_content: recent_content,
      recent_ai_interactions: recent_ai_interactions,
      recent_drafts: recent_drafts,
      recent_scheduled: recent_scheduled,
      activity_score: activity_score
    }
  end

  def get_engagement_metrics(days = 30)
    period_start = days.days.ago
    
    # Engagement from performance metrics
    engagement_data = @user.scheduled_posts.joins(:performance_metrics)
                          .where('posted_at >= ?', period_start)
    
    total_likes = engagement_data.sum(:likes) || 0
    total_comments = engagement_data.sum(:comments) || 0
    total_shares = engagement_data.sum(:shares) || 0
    total_views = engagement_data.sum(:reach) || 0
    
    engagement_rate = total_views > 0 ? ((total_likes + total_comments + total_shares).to_f / total_views * 100).round(2) : 0
    
    # Calculate engagement trend
    previous_period_start = (days * 2).days.ago
    previous_period_end = period_start
    
    previous_engagement = @user.scheduled_posts.joins(:performance_metrics)
                                .where('posted_at >= ?', previous_period_start)
                                .where('posted_at < ?', previous_period_end)
    
    previous_total = previous_engagement.sum(:likes) + previous_engagement.sum(:comments) + previous_engagement.sum(:shares)
    
    engagement_growth_rate = previous_total > 0 ? 
      (((total_likes + total_comments + total_shares).to_f / previous_total * 100) - 100).round(1) : 0
    
    {
      total_likes: total_likes,
      total_comments: total_comments,
      total_shares: total_shares,
      total_views: total_views,
      engagement_rate: engagement_rate,
      engagement_growth_rate: engagement_growth_rate
    }
  end

  def get_growth_metrics(days = 30)
    period_start = days.days.ago
    previous_period_start = (days * 2).days.ago
    previous_period_end = period_start
    
    # Growth in different areas
    current_content = @user.contents.where('created_at >= ?', period_start).count
    previous_content = @user.contents.where('created_at >= ?', previous_period_start).where('created_at < ?', previous_period_end).count
    
    current_ai_interactions = @user.ai_conversations.where('updated_at >= ?', period_start).count
    previous_ai_interactions = @user.ai_conversations.where('updated_at >= ?', previous_period_start).where('updated_at < ?', previous_period_end).count
    
    content_growth = previous_content > 0 ? ((current_content.to_f / previous_content * 100) - 100).round(1) : 0
    ai_growth = previous_ai_interactions > 0 ? ((current_ai_interactions.to_f / previous_ai_interactions * 100) - 100).round(1) : 0
    
    # User progression score
    progression_score = calculate_progression_score(@user)
    
    {
      content_growth: content_growth,
      ai_growth: ai_growth,
      progression_score: progression_score,
      current_period_content: current_content,
      previous_period_content: previous_content
    }
  end

  private

  def calculate_performance_score(posts)
    if posts.empty?
      return rand(65..85) # Default score for users with no posts
    end
    
    total_engagement = posts.sum(Arel.sql('likes + comments + shares'))
    total_reach = posts.sum(:reach) || 1
    avg_engagement_rate = total_reach > 0 ? (total_engagement.to_f / total_reach * 100).round(2) : 0
    
    # Performance score based on engagement metrics
    base_score = 50
    base_score += [avg_engagement_rate, 10].min * 2 # Up to 20 points for engagement rate
    base_score += [total_engagement / 10, 30].min # Up to 30 points for total engagement
    
    [base_score, 100].min
  end

  def calculate_activity_score(content, ai, drafts, scheduled)
    # Activity score based on recent activity
    score = 0
    score += [content * 5, 25].min # Up to 25 points for content creation
    score += [ai * 3, 15].min # Up to 15 points for AI interactions
    score += [drafts * 3, 15].min # Up to 15 points for drafts
    score += [scheduled * 2, 10].min # Up to 10 points for scheduled posts
    
    # Bonus for consistent activity
    if content > 0 && ai > 0
      score += 10
    end
    
    [score, 100].min
  end

  def calculate_progression_score(user)
    score = 0
    
    # Basic progression based on feature usage
    score += [user.contents.count * 2, 20].min
    score += [user.ai_conversations.count * 3, 15].min
    score += [user.draft_contents.count * 2, 10].min
    score += [user.scheduled_posts.count * 1, 15].min
    score += [user.automation_rules.count * 5, 10].min
    score += [user.content_templates.count * 3, 10].min
    
    # Bonus for power user features
    if user.automation_rules.count > 0
      score += 10
    end
    
    if user.content_templates.count > 3
      score += 5
    end
    
    [score, 100].min
  end
end