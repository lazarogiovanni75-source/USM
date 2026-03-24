# frozen_string_literal: true

# Service for fetching and analyzing post performance data
# Uses Postforme API for data and Claude for AI-generated insights
class PostformeAnalyticsService
  PLATFORM_COLORS = {
    'instagram' => 'from-purple-500 to-pink-500',
    'facebook' => 'from-blue-600 to-blue-700',
    'tiktok' => 'from-pink-500 to-gray-900',
    'x' => 'from-gray-800 to-black',
    'twitter' => 'from-gray-800 to-black',
    'linkedin' => 'from-blue-500 to-blue-600',
    'youtube' => 'from-red-600 to-red-700',
    'threads' => 'from-gray-600 to-gray-800',
    'bluesky' => 'from-blue-400 to-blue-500',
    'pinterest' => 'from-red-500 to-orange-500'
  }.freeze

  def initialize(user)
    @user = user
    @days = 30
  end

  def dashboard_data(days: 30)
    @days = days
    {
      summary: summary_stats,
      platform_breakdown: platform_breakdown,
      top_performers: top_performing_posts,
      performance_trends: performance_trends,
      best_posting_times: best_posting_times,
      content_insights: content_insights,
      charts: chart_data
    }
  end

  def summary_stats
    posts = published_posts
    total_engagement = posts.sum { |p| p.post_analytics_data&.total_engagement || 0 }
    total_impressions = posts.sum { |p| p.post_analytics_data&.impressions || 0 }
    total_likes = posts.sum { |p| p.post_analytics_data&.likes || 0 }
    total_comments = posts.sum { |p| p.post_analytics_data&.comments || 0 }
    total_shares = posts.sum { |p| p.post_analytics_data&.shares || 0 }

    avg_engagement_rate = total_impressions > 0 ? ((total_engagement.to_f / total_impressions) * 100).round(2) : 0

    {
      total_posts: posts.count,
      total_engagement: total_engagement,
      total_impressions: total_impressions,
      total_likes: total_likes,
      total_comments: total_comments,
      total_shares: total_shares,
      avg_engagement_rate: avg_engagement_rate,
      total_reach: posts.sum { |p| p.post_analytics_data&.reach || 0 },
      total_clicks: posts.sum { |p| p.post_analytics_data&.clicks || 0 }
    }
  end

  def platform_breakdown
    posts = published_posts.group_by { |p| p.platform || 'other' }

    posts.map do |platform, platform_posts|
      engagement = platform_posts.sum { |p| p.post_analytics_data&.total_engagement || 0 }
      impressions = platform_posts.sum { |p| p.post_analytics_data&.impressions || 0 }
      likes = platform_posts.sum { |p| p.post_analytics_data&.likes || 0 }
      comments = platform_posts.sum { |p| p.post_analytics_data&.comments || 0 }
      shares = platform_posts.sum { |p| p.post_analytics_data&.shares || 0 }

      {
        platform: platform,
        display_name: platform.capitalize,
        color_class: PLATFORM_COLORS[platform] || 'from-gray-500 to-gray-600',
        icon: platform_icon(platform),
        post_count: platform_posts.count,
        total_engagement: engagement,
        total_impressions: impressions,
        total_likes: likes,
        total_comments: comments,
        total_shares: shares,
        engagement_rate: impressions > 0 ? ((engagement.to_f / impressions) * 100).round(2) : 0,
        avg_per_post: platform_posts.count > 0 ? (engagement / platform_posts.count).round(1) : 0
      }
    end.sort_by { |p| -p[:total_engagement] }
  end

  def top_performing_posts(limit: 10)
    posts = published_posts
            .joins(:post_analytic)
            .order('post_analytics.engagement_rate DESC')
            .limit(limit)

    posts.map { |post| format_post_data(post) }
  end

  def performance_trends
    posts = published_posts.order(posted_at: :asc)
    return [] if posts.empty?

    # Group by day
    daily_data = posts.group_by { |p| p.posted_at&.to_date || p.created_at.to_date }

    daily_data.map do |date, day_posts|
      engagement = day_posts.sum { |p| p.post_analytics_data&.total_engagement || 0 }
      impressions = day_posts.sum { |p| p.post_analytics_data&.impressions || 0 }
      likes = day_posts.sum { |p| p.post_analytics_data&.likes || 0 }
      comments = day_posts.sum { |p| p.post_analytics_data&.comments || 0 }
      shares = day_posts.sum { |p| p.post_analytics_data&.shares || 0 }

      {
        date: date.iso8601,
        label: date.strftime('%b %d'),
        posts: day_posts.count,
        engagement: engagement,
        impressions: impressions,
        likes: likes,
        comments: comments,
        shares: shares,
        engagement_rate: impressions > 0 ? ((engagement.to_f / impressions) * 100).round(2) : 0
      }
    end.sort_by { |d| d[:date] }
  end

  def best_posting_times
    posts = published_posts.where.not(posted_at: nil)
    return [] if posts.empty?

    # Group by hour
    hourly_data = posts.group_by { |p| p.posted_at.hour }

    hourly_data.map do |hour, hour_posts|
      engagement = hour_posts.sum { |p| p.post_analytics_data&.total_engagement || 0 }
      impressions = hour_posts.sum { |p| p.post_analytics_data&.impressions || 0 }

      {
        hour: hour,
        label: format_hour(hour),
        post_count: hour_posts.count,
        total_engagement: engagement,
        avg_engagement: hour_posts.count > 0 ? (engagement / hour_posts.count).round(1) : 0,
        engagement_rate: impressions > 0 ? ((engagement.to_f / impressions) * 100).round(2) : 0
      }
    end.sort_by { |h| -h[:avg_engagement] }
  end

  def content_insights
    posts = published_posts.joins(:content)
    return [] if posts.empty?

    insights = []

    # Content type analysis
    category_data = posts.group_by { |p| p.content&.category || 'uncategorized' }
    best_category = category_data.max_by do |_, cat_posts|
      cat_posts.sum { |p| p.post_analytics_data&.total_engagement || 0 }
    end

    if best_category
      insights << {
        type: 'content_type',
        title: 'Best Performing Content',
        description: "#{best_category[0].capitalize} content generates the highest engagement.",
        recommendation: "Consider creating more #{best_category[0]} content to boost engagement."
      }
    end

    # Platform insights
    platform_data = posts.group_by { |p| p.platform }
    best_platform = platform_data.max_by do |_, plat_posts|
      avg_engagement(plat_posts)
    end

    if best_platform && best_platform[1].count >= 3
      worst_platform = platform_data.min_by do |_, plat_posts|
        avg_engagement(plat_posts)
      end

      if worst_platform && worst_platform[1].count >= 3
        ratio = avg_engagement(best_platform[1]) / [avg_engagement(worst_platform[1]), 1].max
        if ratio > 1.5
          insights << {
            type: 'platform',
            title: 'Platform Performance Gap',
            description: "#{best_platform[0].capitalize} outperforms #{worst_platform[0].capitalize} by #{(ratio * 100 - 100).round(0)}%.",
            recommendation: "Focus more on #{best_platform[0]} content for better results."
          }
        end
      end
    end

    # Optimal posting time
    best_times = best_posting_times.first(3)
    if best_times.any?
      insights << {
        type: 'timing',
        title: 'Optimal Posting Times',
        description: "Your best performing posts are typically published around #{best_times.map { |t| t[:label] }.join(', ')}.",
        recommendation: "Schedule more posts during these time slots for higher engagement."
      }
    end

    insights
  end

  def chart_data
    trends = performance_trends

    {
      engagement_over_time: {
        labels: trends.pluck(:label),
        data: trends.pluck(:engagement)
      },
      impressions_over_time: {
        labels: trends.pluck(:label),
        data: trends.pluck(:impressions)
      },
      platform_comparison: {
        labels: platform_breakdown.pluck(:display_name),
        engagement_data: platform_breakdown.pluck(:total_engagement),
        posts_data: platform_breakdown.pluck(:post_count)
      },
      hourly_performance: {
        labels: (0..23).map { |h| format_hour(h) },
        data: best_posting_times.sort_by { |h| h[:hour] }.pluck(:avg_engagement)
      }
    }
  end

  def ai_insights
    return nil unless ENV['ANTHROPIC_API_KEY'].present?

    prompt = build_ai_insight_prompt
    client = ClaudeService.new(max_budget_usd: 0.05)

    response = client.messages(
      messages: [{ role: "user", content: prompt }],
      system: "You are a social media analytics expert. Analyze the provided data and provide actionable insights in a clear, concise format.",
      temperature: 0.7
    )

    response['content']
  rescue => e
    Rails.logger.error "[PostformeAnalyticsService] AI insights error: #{e.message}"
    nil
  end

  private

  attr_reader :user

  def published_posts
    @published_posts ||= user.scheduled_posts
                             .published
                             .where('posted_at >= ?', @days.days.ago)
                             .includes(:content, :post_analytic, :postforme_analytic)
  end

  def format_post_data(post)
    analytics = post.post_analytics_data

    {
      id: post.id,
      title: post.content&.title || 'Untitled',
      platform: post.platform,
      platform_icon: platform_icon(post.platform),
      platform_color: PLATFORM_COLORS[post.platform] || 'from-gray-500 to-gray-600',
      posted_at: post.posted_at&.strftime('%b %d, %Y'),
      posted_at_iso: post.posted_at&.iso8601,
      thumbnail: post.content&.media_url,
      metrics: {
        likes: analytics&.likes || 0,
        comments: analytics&.comments || 0,
        shares: analytics&.shares || 0,
        saves: analytics&.saves || 0,
        impressions: analytics&.impressions || 0,
        reach: analytics&.reach || 0,
        clicks: analytics&.clicks || 0,
        total_engagement: analytics&.total_engagement || 0,
        engagement_rate: analytics&.engagement_rate || 0
      },
      performance_score: analytics&.performance_score || 0,
      engagement_breakdown: {
        likes_pct: calculate_percentage(analytics&.likes || 0, analytics&.total_engagement || 0),
        comments_pct: calculate_percentage(analytics&.comments || 0, analytics&.total_engagement || 0),
        shares_pct: calculate_percentage(analytics&.shares || 0, analytics&.total_engagement || 0)
      }
    }
  end

  def calculate_percentage(value, total)
    return 0 if total.zero?
    ((value.to_f / total) * 100).round(1)
  end

  def avg_engagement(posts)
    total = posts.sum { |p| p.post_analytics_data&.total_engagement || 0 }
    posts.count > 0 ? (total.to_f / posts.count) : 0
  end

  def platform_icon(platform)
    case platform
    when 'instagram' then 'camera'
    when 'facebook' then 'thumbs-up'
    when 'tiktok' then 'music'
    when 'x', 'twitter' then 'repeat'
    when 'linkedin' then 'briefcase'
    when 'youtube' then 'play'
    when 'threads' then 'message-circle'
    when 'bluesky' then 'cloud'
    when 'pinterest' then 'map-pin'
    else 'share-2'
    end
  end

  def format_hour(hour)
    if hour == 0
      '12 AM'
    elsif hour < 12
      "#{hour} AM"
    elsif hour == 12
      '12 PM'
    else
      "#{hour - 12} PM"
    end
  end

  def build_ai_insight_prompt
    summary = summary_stats
    platforms = platform_breakdown
    trends = performance_trends.last(7)
    best_times = best_posting_times.first(3)

    <<~PROMPT
      Analyze this social media performance data and provide 3-5 actionable insights:

      SUMMARY:
      - Total Posts: #{summary[:total_posts]}
      - Total Engagement: #{summary[:total_engagement]}
      - Total Impressions: #{summary[:total_impressions]}
      - Average Engagement Rate: #{summary[:avg_engagement_rate]}%

      PLATFORM BREAKDOWN:
      #{platforms.map { |p| "- #{p[:display_name]}: #{p[:total_engagement]} engagements, #{p[:engagement_rate]}% rate" }.join("\n")}

      RECENT TRENDS (Last 7 days):
      #{trends.map { |t| "- #{t[:label]}: #{t[:engagement]} engagements" }.join("\n")}

      BEST POSTING TIMES:
      #{best_times.map { |t| "- #{t[:label]}: #{t[:avg_engagement]} avg engagement" }.join("\n")}

      Provide:
      1. Key performance insights
      2. Content recommendations
      3. Platform strategy suggestions
      4. Optimal posting schedule recommendations
    PROMPT
  end
end
