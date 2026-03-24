# frozen_string_literal: true

# Model for storing analytics data for each published post
# Pulled from Postforme API and refreshed every 24 hours
class PostAnalytic < ApplicationRecord
  belongs_to :scheduled_post

  validates :scheduled_post_id, uniqueness: true

  # Metrics that can be updated
  METRICS = %i[likes comments shares saves clicks impressions reach views].freeze

  scope :recent, -> { where('fetched_at >= ?', 7.days.ago) }
  scope :for_platform, ->(platform) { joins(:scheduled_post).where(scheduled_posts: { platform: platform }) }

  def total_engagement
    likes.to_i + comments.to_i + shares.to_i + saves.to_i
  end

  def update_from_postforme!(analytics_data)
    update!(
      likes: analytics_data[:likes] || analytics_data['likes'] || 0,
      comments: analytics_data[:comments] || analytics_data['comments'] || 0,
      shares: analytics_data[:shares] || analytics_data['shares'] || 0,
      saves: analytics_data[:saves] || analytics_data['saves'] || 0,
      clicks: analytics_data[:clicks] || analytics_data['clicks'] || 0,
      impressions: analytics_data[:impressions] || analytics_data['impressions'] || 0,
      reach: analytics_data[:reach] || analytics_data['reach'] || 0,
      views: analytics_data[:views] || analytics_data['views'] || 0,
      engagement_rate: calculate_engagement_rate,
      raw_data: analytics_data[:raw_data] || analytics_data,
      fetched_at: Time.current
    )
  end

  def calculate_engagement_rate
    return 0.0 if impressions.to_i.zero?

    ((total_engagement.to_f / impressions) * 100).round(2)
  end

  def performance_score
    score = 0

    # Engagement rate weight (40%)
    score += (engagement_rate.to_f * 10).clamp(0, 40)

    # Total engagement weight (30%)
    score += [total_engagement.to_i / 10, 30].min

    # Impressions weight (20%)
    score += [impressions.to_i / 100, 20].min

    # Recency bonus (10%)
    if fetched_at && fetched_at >= 1.day.ago
      score += 10
    elsif fetched_at && fetched_at >= 3.days.ago
      score += 7
    elsif fetched_at && fetched_at >= 7.days.ago
      score += 5
    end

    score.to_i.clamp(0, 100)
  end

  def trend
    return :stable if historical_data.blank?

    recent_avg = historical_data.last(7).map { |d| d[:total_engagement] }.sum / 7.0
    older_avg = historical_data.first(7).map { |d| d[:total_engagement] }.sum / 7.0

    return :stable if recent_avg.zero? || older_avg.zero?

    ratio = recent_avg / older_avg
    if ratio > 1.1
      :improving
    elsif ratio < 0.9
      :declining
    else
      :stable
    end
  end

  private

  def historical_data
    @historical_data ||= scheduled_post.post_analytics.order(created_at: :asc).map do |analytic|
      { total_engagement: analytic.total_engagement, impressions: analytic.impressions }
    end
  end
end
