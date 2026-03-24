class ProcessQueueItemJob < ApplicationJob
  queue_as :publishing
  
  def perform(queue_item_id)
    queue_item = PublishQueue.find(queue_item_id)
    return unless queue_item
    
    service = PublishQueueService.new(queue_item.user)
    result = service.process_queue_item(queue_item)
    
    { success: result[:success], error: result[:error], item_id: queue_item_id }
  rescue => e
    Rails.logger.error "Error in ProcessQueueItemJob: #{e.message}"
    { success: false, error: e.message, item_id: queue_item_id }
  end
end