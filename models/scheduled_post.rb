class ScheduledPost < ApplicationRecord
  belongs_to :content
  belongs_to :social_account
  belongs_to :user
  has_many :performance_metrics, dependent: :destroy

  after_create :trigger_postforme_webhook

  enum status: {
    scheduled: 'scheduled',
    published: 'published',
    failed: 'failed',
    cancelled: 'cancelled'
  }

  validates :scheduled_at, presence: true
  
  scope :by_platform, ->(platform) { joins(:social_account).where(social_accounts: { platform: platform }) if platform.present? }
  scope :upcoming, -> { where('scheduled_at >= ?', Time.current).order(scheduled_at: :asc) }
  scope :past, -> { where('scheduled_at < ?', Time.current).order(scheduled_at: :desc) }
  
  def platform_and_title
    "#{platform.capitalize} - #{content.title}"
  end
  
  def can_modify?
    status.in?([:scheduled, :failed]) && scheduled_at > Time.current
  end
  
  def can_cancel?
    status == :scheduled
  end
  
  def can_retry?
    status == :failed
  end
  
  def optimal_posting_time
    SchedulerService.new.optimal_time_for_platform(platform)
  end

  private

  def trigger_postforme_webhook
    return if Rails.env.test? && ENV['SKIP_WEBHOOKS'].present?

    PostWebhookJob.perform_later(id, 'created')
  rescue StandardError => e
    Rails.logger.warn("[ScheduledPost] Failed to enqueue webhook job: #{e.message}")
  end
end
