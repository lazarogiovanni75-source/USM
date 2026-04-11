class WorkflowExecutionJob < ApplicationJob
  queue_as :default

  def perform(workflow_id)
    workflow = Workflow.find(workflow_id)
    workflow.update!(status: :processing)

    WorkflowService.new.execute_workflow(workflow)
  rescue => e
    Rails.logger.error "Workflow execution failed: #{e.message}"
    workflow.update!(status: :failed, error_message: e.message) if workflow
    raise
  end
end
