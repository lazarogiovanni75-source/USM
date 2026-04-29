# frozen_string_literal: true

class Competitor < ApplicationRecord
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

  # Validations
  validates :handle, presence: true, uniqueness: { scope: [:user_id, :platform] }
  validates :platform, presence: true
  validates :user_id, presence: true

  # Callbacks
  before_validation :normalize_handle

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :by_platform, ->(p) { where(platform: p) }
  scope :recently_synced, -> { where('last_synced_at > ?', 24.hours.ago) }

  # Relationships
  has_many :competitor_posts, dependent: :destroy

  # Methods

  def display_name_with_platform
    "#{display_name} on #{platform.titleize}"
  end

  def engagement_rate
    return 0 if follower_count.to_i.zero?

    posts = competitor_posts.where('created_at > ?', 30.days.ago)
    return 0 if posts.empty?

    total_engagement = posts.sum { |p| (p.likes_count || 0) + (p.comments_count || 0) + (p.shares_count || 0) }
    (total_engagement.to_f / follower_count.to_i) * 100
  end

  def posts_per_day
    posts = competitor_posts.where('created_at > ?', 30.days.ago)
    return 0 if posts.empty?

    (posts.count / 30.0).round(2)
  end

  def needs_refresh?
    last_synced_at.nil? || last_synced_at < 1.hour.ago
  end

  def normalized_handle
    handle.to_s.gsub('@', '').strip
  end

  private

  def normalize_handle
    self.handle = normalized_handle if handle.present?
  end
end