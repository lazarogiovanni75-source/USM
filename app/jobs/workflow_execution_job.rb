class WorkflowExecutionJob < ApplicationJob
  queue_as :default

  def perform(workflow_id)
    workflow = Workflow.find(workflow_id)
    stream_name = "workflow_#{workflow_id}_#{workflow.user_id}"

    ActionCable.server.broadcast(stream_name, {
      type: "workflow_started",
      workflow_id: workflow_id,
      status: "running",
      message: "Workflow is running..."
    })

    result = WorkflowService.execute_workflow(workflow_id)
    workflow.reload

    ActionCable.server.broadcast(stream_name, {
      type: "workflow_completed",
      workflow_id: workflow_id,
      status: workflow.status,
      message: "Workflow completed successfully.",
      result: result
    })
  rescue => e
    begin
      wf = Workflow.find_by(id: workflow_id)
      wf&.update(status: :failed)
      ActionCable.server.broadcast("workflow_#{workflow_id}_#{wf&.user_id}", {
        type: "workflow_failed",
        workflow_id: workflow_id,
        status: "failed",
        message: "Workflow failed: #{e.message}"
      })
    rescue
    end
    raise
  end
end
