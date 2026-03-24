class ViralMetric < ApplicationRecord
  belongs_to :scheduled_post
  belongs_to :campaign, optional: true
  belongs_to :client, optional: true

  validates :engagement_rate, presence: true
  validates :detected_at, presence: true

  scope :viral_posts, -> { where(is_viral: true) }
  scope :recent, -> { where('detected_at > ?', 30.days.ago) }
  scope :by_client, ->(client_id) { where(client_id: client_id) }
  scope :by_campaign, ->(campaign_id) { where(campaign_id: campaign_id) }
  scope :top_ranked, -> { order(viral_rank: :asc).limit(10) }

  def self.engagement_rate_threshold
    0.05 # 5% engagement rate threshold for viral detection
  end

  def self.velocity_threshold
    0.5 # engagements per hour threshold
  end

  def calculate_engagement_rate
    return 0 unless scheduled_post&.performance_metric

    pm = scheduled_post.performance_metric
    total_engagements = (pm.likes || 0) + (pm.comments || 0) + (pm.shares || 0)
    impressions = pm.impressions || pm.views || 0
    return 0 if impressions == 0

    (total_engagements.to_f / impressions).round(4)
  end

  def calculate_share_velocity
    return 0 unless scheduled_post&.performance_metric && scheduled_post.published_at

    pm = scheduled_post.performance_metric
    total_engagements = (pm.likes || 0) + (pm.comments || 0) + (pm.shares || 0)
    hours_since_publish = ((Time.current - scheduled_post.published_at) / 1.hour).round(2)
    return 0 if hours_since_publish == 0

    (total_engagements.to_f / hours_since_publish).round(4)
  end

  def self.detect_viral(post)
    metric = new(scheduled_post: post)
    metric.engagement_rate = metric.calculate_engagement_rate
    metric.share_velocity = metric.calculate_share_velocity
    metric.detected_at = Time.current

    # Determine if viral based on thresholds
    metric.is_viral = metric.engagement_rate >= engagement_rate_threshold ||
                      metric.share_velocity >= velocity_threshold

    # Extract hashtags from post content
    if post.content.present?
      metric.top_hashtags = post.content.scan(/#\w+/).first(5)
    end

    metric
  end
end
