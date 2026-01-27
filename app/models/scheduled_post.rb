class ScheduledPost < ApplicationRecord
  belongs_to :content
  belongs_to :social_account
  belongs_to :user
  has_many :performance_metrics, dependent: :destroy
  
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
    # This would integrate with your calendar service for optimal timing
    SchedulerService.new.optimal_time_for_platform(platform)
  end
end
