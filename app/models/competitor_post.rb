# frozen_string_literal: true

class CompetitorPost < ApplicationRecord
  belongs_to :competitor

  # Platform enum
  enum :platform, {
    instagram: 'instagram',
    facebook: 'facebook',
    twitter: 'twitter',
    linkedin: 'linkedin',
    tiktok: 'tiktok',
    youtube: 'youtube',
    pinterest: 'pinterest',
    threads: 'threads',
    snapchat: 'snapchat'
  }, prefix: true

  # Validations
  validates :platform_post_id, uniqueness: { scope: :competitor_id }, allow_blank: true

  # Scopes
  scope :recent, -> { where('created_at > ?', 30.days.ago) }
  scope :ordered_by_likes, -> { order(likes_count: :desc) }

  # Methods

  def engagement_rate
    return 0 if competitor&.follower_count.to_i.zero?

    engagement = (likes_count || 0) + (comments_count || 0) + (shares_count || 0)
    (engagement.to_f / competitor.follower_count.to_i) * 100
  end

  def total_engagement
    (likes_count || 0) + (comments_count || 0) + (shares_count || 0)
  end

  def posted_time_ago
    return 'unknown' unless posted_at

    seconds = Time.current - posted_at
    if seconds < 60
      "#{seconds.to_i}s ago"
    elsif seconds < 3600
      "#{(seconds / 60).to_i}m ago"
    elsif seconds < 86400
      "#{(seconds / 3600).to_i}h ago"
    else
      "#{(seconds / 86400).to_i}d ago"
    end
  end

  def platform_icon
    case platform
    when 'instagram' then 'camera'
    when 'facebook' then 'thumbs-up'
    when 'twitter' then 'repeat'
    when 'linkedin' then 'briefcase'
    when 'tiktok' then 'music'
    when 'youtube' then 'play'
    when 'pinterest' then 'map-pin'
    when 'threads' then 'message-circle'
    when 'snapchat' then 'camera'
    else 'globe'
    end
  end
end