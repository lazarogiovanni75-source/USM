class PublishQueue < ApplicationRecord
  belongs_to :user
  belongs_to :scheduled_post, optional: true
  belongs_to :content, optional: true
  
  enum status: {
    pending: 'pending',
    processing: 'processing',
    published: 'published',
    failed: 'failed',
    cancelled: 'cancelled',
    retrying: 'retrying'
  }
  
  enum priority: {
    low: 1,
    normal: 5,
    high: 10,
    urgent: 15
  }
  
  validates :platform, presence: true
  validates :content_data, presence: true
  validates :scheduled_at, presence: true
  
  scope :by_priority, -> { order(priority: :desc, created_at: :asc) }
  scope :ready_for_publishing, -> { 
    where(status: [:pending, :retrying])
    .where('scheduled_at <= ?', Time.current)
    .where('lock_expires_at IS NULL OR lock_expires_at < ?', Time.current)
  }
  scope :failed_retry_eligible, -> {
    where(status: :failed)
    .where('retry_count < ?', 3)
    .where('next_retry_at IS NOT NULL AND next_retry_at <= ?', Time.current)
  }
  
  def initialize_queue_item(content_data:, platform:, scheduled_at:, priority: :normal, dependency_ids: [])
    self.content_data = content_data
    self.platform = platform
    self.scheduled_at = scheduled_at
    self.priority = priority
    self.dependency_ids = dependency_ids
    self.status = :pending
    self.retry_count = 0
    self.next_retry_at = nil
  end
  
  def can_process?
    return false unless [:pending, :retrying].include?(status)
    return false if scheduled_at > Time.current
    return false if lock_expires_at && lock_expires_at > Time.current
    
    # Check dependencies
    return false unless dependencies_satisfied?
    
    true
  end
  
  def dependencies_satisfied?
    return true if dependency_ids.blank?
    
    dependency_ids.all? do |dep_id|
      dep = PublishQueue.find_by(id: dep_id)
      dep && dep.status == 'published'
    end
  end
  
  def acquire_lock(lock_duration = 30.minutes)
    return false if lock_expires_at && lock_expires_at > Time.current
    
    update!(
      status: :processing,
      lock_expires_at: Time.current + lock_duration,
      locked_at: Time.current
    )
    true
  end
  
  def release_lock
    update!(
      lock_expires_at: nil,
      locked_at: nil
    )
  end
  
  def mark_published(platform_post_id: nil, published_at: nil)
    update!(
      status: :published,
      published_at: published_at || Time.current,
      platform_post_id: platform_post_id,
      lock_expires_at: nil,
      locked_at: nil
    )
  end
  
  def mark_failed(error_message: nil, retry_scheduled: false)
    update!(
      status: retry_scheduled ? :retrying : :failed,
      error_message: error_message,
      lock_expires_at: nil,
      locked_at: nil,
      retry_count: retry_count + 1,
      next_retry_at: retry_scheduled ? calculate_next_retry_time : nil
    )
  end
  
  def calculate_next_retry_time
    # Exponential backoff: 5min, 15min, 45min
    retry_intervals = [5.minutes, 15.minutes, 45.minutes]
    interval = retry_intervals[retry_count] || 45.minutes
    Time.current + interval
  end
  
  def retry_eligible?
    failed? && retry_count < 3 && (!next_retry_at || next_retry_at <= Time.current)
  end
  
  def cancel
    update!(status: :cancelled, lock_expires_at: nil, locked_at: nil)
  end
  
  def platform_specific_config
    {
      instagram: {
        rate_limit: 200, # posts per hour
        min_interval: 18, # seconds between posts
        max_retries: 3,
        requires_media: false
      },
      twitter: {
        rate_limit: 300, # posts per 3 hours
        min_interval: 30,
        max_retries: 3,
        requires_media: false
      },
      linkedin: {
        rate_limit: 100, # posts per hour
        min_interval: 60,
        max_retries: 2,
        requires_media: false
      },
      facebook: {
        rate_limit: 150, # posts per hour
        min_interval: 36,
        max_retries: 3,
        requires_media: false
      },
      tiktok: {
        rate_limit: 50, # posts per day
        min_interval: 120, # 2 minutes
        max_retries: 2,
        requires_media: true
      }
    }[platform.to_sym] || {
      rate_limit: 100,
      min_interval: 60,
      max_retries: 3,
      requires_media: false
    }
  end
  
  def estimated_processing_time
    # Base time + platform-specific time
    base_time = 2.seconds
    
    case platform.to_sym
    when :instagram
      content_data['images'].present? ? 8.seconds : 5.seconds
    when :twitter
      3.seconds
    when :linkedin
      6.seconds
    when :facebook
      5.seconds
    when :tiktok
      15.seconds # Video processing time
    else
      5.seconds
    end + base_time
  end
  
  def self.process_queue_batch(user_id, batch_size = 5)
    user = User.find(user_id)
    return [] unless user
    
    # Get ready items for this user
    ready_items = user.publish_queues
                   .ready_for_publishing
                   .by_priority
                   .limit(batch_size)
                   .includes(:scheduled_post, :content)
    
    processed_items = []
    
    ready_items.each do |item|
      break unless item.acquire_lock
      
      begin
        # Process the item
        result = ProcessQueueItemJob.perform_now(item.id)
        processed_items << { item: item, success: result[:success], error: result[:error] }
      rescue => e
        Rails.logger.error "Error processing queue item #{item.id}: #{e.message}"
        item.mark_failed(e.message)
        processed_items << { item: item, success: false, error: e.message }
      ensure
        item.release_lock
      end
    end
    
    processed_items
  end
  
  def self.cleanup_expired_locks
    where('lock_expires_at < ?', Time.current).each do |item|
      item.release_lock
    end
  end
end