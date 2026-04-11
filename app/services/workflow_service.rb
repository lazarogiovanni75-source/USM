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
    workflow.update!(status: :completed, result: result.to_json)
    result
  rescue => e
    fail_workflow(workflow, e.message)
  end

  def execute_content_to_image_post(workflow)
    content = workflow.content
    return fail_workflow(workflow, "No content provided") if content.blank?

    # Generate caption with LLM
    llm_result = LlmService.generate_content(prompt: content)
    
    # Generate image with Atlas Cloud
    image_result = ImageGenerationService.generate_image(prompt: content)
    
    # Save combined results
    result_data = {
      caption: llm_result,
      image_task_id: image_result[:task_id],
      image_service: image_result[:service]
    }
    workflow.update!(status: :completed, result: result_data.to_json)
    result_data
  rescue => e
    fail_workflow(workflow, e.message)
  end

  def execute_content_to_video_post(workflow)
    content = workflow.content
    return fail_workflow(workflow, "No content provided") if content.blank?

    # Generate caption with LLM
    llm_result = LlmService.generate_content(prompt: content)
    
    # Generate video with Atlas Cloud
    video_result = VideoGenerationService.generate_video(prompt: content)
    
    # Save combined results
    result_data = {
      caption: llm_result,
      video_task_id: video_result[:task_id],
      video_service: video_result[:service]
    }
    workflow.update!(status: :completed, result: result_data.to_json)
    result_data
  rescue => e
    fail_workflow(workflow, e.message)
  end

  private

  def fail_workflow(workflow, error_message)
    workflow.update!(status: :failed, error_message: error_message)
    nil
  end
end
