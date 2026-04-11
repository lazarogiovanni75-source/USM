class WorkflowService
  def execute_workflow(workflow)
    case workflow.workflow_type
    when 'content_to_image_post'
      execute_content_to_image_post(workflow)
    when 'content_to_video_post'
      execute_content_to_video_post(workflow)
    else
      execute_content_to_post(workflow)
    end
  end

  def execute_content_to_post(workflow)
    content = workflow.content
    return fail_workflow(workflow, "No content provided") if content.blank?

    result = LlmService.generate_content(prompt: content)
    workflow.update!(status: :completed)
    result
  rescue => e
    fail_workflow(workflow, e.message)
  end

  def execute_content_to_image_post(workflow)
    content = workflow.content
    return fail_workflow(workflow, "No content provided") if content.blank?

    result = LlmService.generate_content(prompt: content)
    ImageGenerationService.new.generate_image(prompt: content)
    workflow.update!(status: :completed)
    result
  rescue => e
    fail_workflow(workflow, e.message)
  end

  def execute_content_to_video_post(workflow)
    content = workflow.content
    return fail_workflow(workflow, "No content provided") if content.blank?

    result = LlmService.generate_content(prompt: content)
    VideoGenerationService.new.generate_video(prompt: content)
    workflow.update!(status: :completed)
    result
  rescue => e
    fail_workflow(workflow, e.message)
  end

  private

  def fail_workflow(workflow, error_message)
    workflow.update!(status: :failed, error_message: error_message)
    nil
  end
end
