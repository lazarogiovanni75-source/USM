class WorkflowExecutionJob < ApplicationJob
  queue_as :default

  # DO NOT add retry_on/discard_on here - ApplicationJob manages all retry strategies
  # DO NOT rescue exceptions unless you re-raise them
  # All uncaught exceptions are automatically reported to frontend via SystemMonitor Channel
  #
  # Consider syncing results to frontend via ActionCable:
  #
  #   ActionCable.server.broadcast("xxx_#{id}", {
  #     type: 'update',  # REQUIRED: type field routes to client handler method
  #     data: your_data  # Frontend MUST implement xxxController#handleUpdate() method
  #   })
  def perform(workflow_id)
    WorkflowService.execute_workflow(workflow_id)
  end
end
