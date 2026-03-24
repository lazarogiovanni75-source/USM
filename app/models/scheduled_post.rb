class ScheduledPost < ApplicationRecord
  belongs_to :content, optional: true
  belongs_to :social_account, optional: true
  belongs_to :user, optional: true
  has_many :performance_metrics, dependent: :destroy
  has_one :postforme_analytic, dependent: :destroy
  has_one :post_analytic, dependent: :destroy

  # Fields for caching latest analytics (optional, for quick access)
  attr_accessor :last_engagement_count, :last_impressions_count, :last_analytics_fetched_at

  delegate :platform, :platform_username, to: :social_account, allow_nil: true

  after_create :trigger_make_webhook

  # Post statuses: draft, scheduled, published, failed, cancelled
  enum status: {
    draft: 'draft',
    scheduled: 'scheduled',
    published: 'published',
    failed: 'failed',
    cancelled: 'cancelled'
  }

  # Valid target platforms (all supported via Postforme API)
  PLATFORMS = %w[instagram facebook tiktok bluesky pinterest linkedin youtube threads x twitter].freeze

  validates :scheduled_at, presence: true
  validates :target_platforms, presence: true, unless: -> { platform.present? }
  validate :validate_target_platforms

  scope :by_platform, ->(platform) { joins(:social_account).where(social_accounts: { platform: platform }) if platform.present? }
  scope :upcoming, -> { where('scheduled_at >= ?', Time.current).order(scheduled_at: :asc) }
  scope :past, -> { where('scheduled_at < ?', Time.current).order(scheduled_at: :desc) }
  scope :due, -> { where('scheduled_at <= ?', Time.current).where(status: %w[draft scheduled]).order(scheduled_at: :asc) }
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :for_date, ->(date) { where(scheduled_at: date.beginning_of_day..date.end_of_day) }

  # Get all platforms (either from target_platforms array or single platform)
  def all_platforms
    return [platform] if platform.present?
    return target_platforms || []
  end

  def platform_and_title
    platform_name = platform&.capitalize || all_platforms.join(', ')
    "#{platform_name} - #{content&.title || 'No content'}"
  end

  def can_modify?
    status.in?(%w[scheduled failed draft]) && scheduled_at > Time.current
  end

  def can_cancel?
    status.in?(%w[scheduled draft])
  end

  def can_retry?
    status == 'failed'
  end

  def can_edit?
    status.in?(%w[draft scheduled]) && scheduled_at > Time.current
  end

  def has_assets?
    image_url.present? || video_url.present? || asset_url.present? ||
    content&.media_url.present? || (content&.media_urls.present? && content.media_urls.any?)
  end

  def post_analytics_data
    post_analytic || postforme_analytic
  end

  def total_engagement
    post_analytics_data&.total_engagement || 0
  end

  def engagement_rate
    post_analytics_data&.engagement_rate || 0
  end

  def performance_score
    post_analytics_data&.performance_score || 0
  end

  def optimal_posting_time
    SchedulerService.new.optimal_time_for_platform(platform)
  end

  # Check if post is ready to publish
  def ready_to_publish?
    return false unless scheduled_at.present?
    return false unless scheduled_at <= Time.current
    return false unless status.in?(%w[draft scheduled])
    has_assets?
  end

  private

  def validate_target_platforms
    return if target_platforms.blank?

    invalid = target_platforms - PLATFORMS
    errors.add(:target_platforms, "contains invalid platforms: #{invalid.join(', ')}") if invalid.any?
  end

  def trigger_make_webhook
    return if Rails.env.test? && ENV['SKIP_WEBHOOKS'].present?

    PostWebhookJob.perform_later(id, 'created')
  rescue StandardError => e
    Rails.logger.warn("[ScheduledPost] Failed to enqueue webhook job: #{e.message}")
  end
end
