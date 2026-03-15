class WorkflowChannel < ApplicationCable::Channel
  def subscribed
    if current_user
      workflow_id = params[:workflow_id]
      if workflow_id.present?
        workflow = current_user.workflows.find_by(id: workflow_id)
        if workflow
          @stream_name = "workflow_#{workflow_id}_#{current_user.id}"
          stream_from @stream_name
          Rails.logger.info "[WorkflowChannel] Subscribed: #{@stream_name}"
        else
          reject
        end
      else
        reject
      end
    else
      reject
    end
  rescue StandardError => e
    handle_channel_error(e)
    reject
  end

  def unsubscribed
    Rails.logger.info "[WorkflowChannel] Unsubscribed: #{@stream_name}"
  end
end
