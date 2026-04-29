# frozen_string_literal: true

class SocialListeningAlert < ApplicationRecord
  belongs_to :user

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

  # Alert type enum
  enum :alert_type, {
    brand_mention: 'brand_mention',
    competitor_mention: 'competitor_mention',
    hashtag: 'hashtag',
    keyword: 'keyword'
  }, prefix: true

  # Sentiment enum
  enum :sentiment, {
    positive: 'positive',
    negative: 'negative',
    neutral: 'neutral'
  }, prefix: true

  # Validations
  validates :platform, presence: true
  validates :user_id, presence: true
  validates :alert_type, presence: true
  validates :content, presence: true

  # Scopes
  scope :unread, -> { where(read_at: nil) }
  scope :by_sentiment, ->(s) { where(sentiment: s) }
  scope :by_type, ->(t) { where(alert_type: t) }
  scope :recent, -> { order(created_at: :desc) }
  scope :high_impact, -> { where('author_followers > ?', 1000).or(where(is_verified: true)) }
  scope :positive_sentiment, -> { where(sentiment: 'positive') }
  scope :negative_sentiment, -> { where(sentiment: 'negative') }

  # Methods

  def mark_as_read
    update(read_at: Time.current) if read_at.nil?
  end

  def read?
    read_at.present?
  end

  def impact_score
    # Calculate impact based on followers and engagement
    base_score = author_followers.to_i / 100.0

    # Boost for verified accounts
    base_score *= 1.5 if is_verified?

    # Boost for high engagement
    engagement = (likes_count || 0) + (comments_count || 0)
    base_score *= 1.2 if engagement > 100

    base_score.round(2)
  end

  def time_ago
    return 'unknown' unless created_at

    seconds = Time.current - created_at
    if seconds < 60
      "#{seconds.to_i}s ago"
    elsif seconds < 3600
      "#{(seconds / 60).to_i}m ago"
    elsif seconds < 86400
      "#{(seconds / 3600).to_i}h ago"
    elsif seconds < 604800
      "#{(seconds / 86400).to_i}d ago"
    else
      created_at.strftime('%b %d')
    end
  end

  def sentiment_color
    case sentiment
    when 'positive' then 'green'
    when 'negative' then 'red'
    else 'gray'
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

  def alert_type_label
    case alert_type
    when 'brand_mention' then 'Brand Mention'
    when 'competitor_mention' then 'Competitor'
    when 'hashtag' then 'Hashtag'
    when 'keyword' then 'Keyword'
    else alert_type.titleize
    end
  end

  def content_truncated(length = 100)
    content.truncate(length, separator: ' ')
  end
end