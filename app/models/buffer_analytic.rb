# frozen_string_literal: true

# Buffer Analytics model for storing post performance data
class BufferAnalytic < ApplicationRecord
  belongs_to :scheduled_post

  # Scopes for filtering
  scope :recent, -> { order(synced_at: :desc) }
  scope :by_platform, ->(platform) { joins(scheduled_post: :social_account).where(social_accounts: { platform: platform }) }
  scope :high_engagement, -> { where('engagement > ?', 100) }
  scope :with_clicks, -> { where('clicks > ?', 0) }

  # Class methods for aggregation
  class << self
    def total_clicks
      sum(:clicks)
    end

    def total_impressions
      sum(:impressions)
    end

    def total_engagement
      sum(:engagement)
    end

    def average_engagement_rate
      total = total_impressions
      return 0 if total.zero?

      (total_engagement.to_f / total * 100).round(2)
    end

    def by_date_range(start_date, end_date)
      where(posted_at: start_date..end_date)
    end

    def top_performing(limit = 10)
      order(engagement: :desc).limit(limit)
    end

    def platform_stats
      joins(scheduled_post: :social_account)
        .group('social_accounts.platform')
        .select('social_accounts.platform, SUM(clicks) as clicks, SUM(impressions) as impressions, SUM(engagement) as engagement')
    end
  end

  # Instance methods
  def engagement_rate
    return 0 if impressions.to_i.zero?

    (engagement.to_f / impressions * 100).round(2)
  end

  def click_rate
    return 0 if impressions.to_i.zero?

    (clicks.to_f / impressions * 100).round(2)
  end

  def performance_rating
    engagement_rate_value = engagement_rate

    case engagement_rate_value
    when 0..1 then 'low'
    when 1..3 then 'average'
    when 3..6 then 'good'
    when 6..10 then 'excellent'
    else 'viral'
    end
  end

  def to_platform_metric
    {
      platform: scheduled_post&.social_account&.platform,
      clicks: clicks,
      impressions: impressions,
      engagement: engagement,
      engagement_rate: engagement_rate,
      posted_at: posted_at
    }
  end
end
