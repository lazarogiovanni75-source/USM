class ProcessQueueBatchJob < ApplicationJob
  queue_as :publishing
  
  def perform(user_id, batch_size = 5)
    user = User.find(user_id)
    return unless user
    
    service = PublishQueueService.new(user)
    result = service.process_queue(max_items: batch_size)
    
    { 
      processed_count: result[:processed_count], 
      rate_limited: result[:rate_limited],
      user_id: user_id 
    }
  rescue => e
    Rails.logger.error "Error in ProcessQueueBatchJob: #{e.message}"
    { success: false, error: e.message, user_id: user_id }
  end
end