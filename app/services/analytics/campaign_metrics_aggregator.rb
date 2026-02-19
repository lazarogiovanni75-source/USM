# frozen_string_literal: true

# Analytics aggregator for campaign metrics
class Analytics::CampaignMetricsAggregator
  # Aggregate all metrics for a campaign
  def self.call(campaign)
    new(campaign).aggregate
  end

  def initialize(campaign)
    @campaign = campaign
    @user = campaign.user
  end

  def aggregate
    posts = campaign_posts
    metrics = aggregate_metrics(posts)
    performance = analyze_performance(posts, metrics)
    
    {
      campaign_id: campaign.id,
      total_posts: posts.count,
      published_posts: posts.where(status: 'published').count,
      total_impressions: metrics[:total_impressions],
      total_engagement: metrics[:total_engagement],
      avg_engagement_rate: metrics[:avg_engagement_rate],
      top_posts: performance[:top_posts],
      worst_posts: performance[:worst_posts],
      hashtag_performance: performance[:hashtag_performance],
      platform_breakdown: performance[:platform_breakdown],
      period_start: metrics[:period_start],
      period_end: metrics[:period_end]
    }
  end

  private

  attr_reader :campaign, :user

  def campaign_posts
    # Get all posts associated with this campaign
    if campaign.respond_to?(:contents) && campaign.contents.any?
      campaign.contents
    elsif user.present?
      ScheduledPost.where(user_id: user.id)
                   .where('created_at >= ?', 7.days.ago)
    else
      ScheduledPost.none
    end
  end

  def aggregate_metrics(posts)
    post_metrics = PostMetric.where(post_type: 'ScheduledPost')
                            .where(post_id: posts.select(:id))
                            .where('collected_at >= ?', 7.days.ago)

    impressions = post_metrics.sum(:impressions)
    likes = post_metrics.sum(:likes)
    comments = post_metrics.sum(:comments)
    shares = post_metrics.sum(:shares)
    saves = post_metrics.sum(:saves)
    clicks = post_metrics.sum(:clicks)

    total_engagement = likes + comments + shares + saves
    
    {
      total_impressions: impressions,
      total_likes: likes,
      total_comments: comments,
      total_shares: shares,
      total_saves: saves,
      total_clicks: clicks,
      total_engagement: total_engagement,
      avg_engagement_rate: impressions.positive? ? (total_engagement.to_f / impressions * 100).round(2) : 0,
      period_start: post_metrics.minimum(:collected_at),
      period_end: post_metrics.maximum(:collected_at)
    }
  end

  def analyze_performance(posts, metrics)
    # Get top performing posts
    post_metrics = PostMetric.where(post_type: 'ScheduledPost')
                            .where(post_id: posts.select(:id))
                            .where('collected_at >= ?', 7.days.ago)
                            .order(engagement_rate: :desc)
                            .limit(5)

    top_posts = post_metrics.map do |pm|
      {
        post_id: pm.post_id,
        engagement_rate: pm.engagement_rate,
        impressions: pm.impressions,
        likes: pm.likes,
        comments: pm.comments
      }
    end

    worst_posts = PostMetric.where(post_type: 'ScheduledPost')
                           .where(post_id: posts.select(:id))
                           .where('collected_at >= ?', 7.days.ago)
                           .order(engagement_rate: :asc)
                           .limit(5)
                           .map do |pm|
      {
        post_id: pm.post_id,
        engagement_rate: pm.engagement_rate,
        impressions: pm.impressions
      }
    end

    # Analyze hashtag performance
    hashtag_performance = analyze_hashtags(posts)

    # Platform breakdown
    platform_breakdown = post_metrics.group(:platform)
                                     .select('platform, SUM(impressions) as impressions, AVG(engagement_rate) as avg_engagement')
                                     .map do |row|
      {
        platform: row.platform,
        impressions: row.impressions.to_i,
        avg_engagement_rate: row.avg_engagement.to_f.round(2)
      }
    end

    {
      top_posts: top_posts,
      worst_posts: worst_posts,
      hashtag_performance: hashtag_performance,
      platform_breakdown: platform_breakdown
    }
  end

  def analyze_hashtags(posts)
    # Extract and analyze hashtags from post content
    hashtag_counts = Hash.new(0)
    hashtag_engagement = Hash.new { |h, k| h[k] = { count: 0, engagement: 0 } }

    posts.where(status: 'published').each do |post|
      hashtags = extract_hashtags(post.content.to_s)
      metrics = PostMetric.find_by(post_type: 'ScheduledPost', post_id: post.id)
      
      hashtags.each do |tag|
        hashtag_counts[tag] += 1
        if metrics
          hashtag_engagement[tag][:count] += 1
          hashtag_engagement[tag][:engagement] += metrics.likes.to_i + metrics.comments.to_i + metrics.shares.to_i
        end
      end
    end

    hashtag_counts.map do |tag, count|
      {
        tag: tag,
        post_count: count,
        avg_engagement: count.positive? ? (hashtag_engagement[tag][:engagement].to_f / count).round(2) : 0
      }
    end.sort_by { |h| -h[:avg_engagement] }.first(10)
  end

  def extract_hashtags(text)
    text.scan(/#(\w+)/).flatten
  end
end
