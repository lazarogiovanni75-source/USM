class CleanupQueueLocksJob < ApplicationJob
  queue_as :maintenance
  
  def perform
    PublishQueue.cleanup_expired_locks
    
    { cleaned_count: PublishQueue.where('lock_expires_at < ?', Time.current).count }
  rescue => e
    Rails.logger.error "Error in CleanupQueueLocksJob: #{e.message}"
    { success: false, error: e.message }
  end
end