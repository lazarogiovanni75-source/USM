class WorkflowService
  def self.create_content_with_media(user:, content_text:, generate_image: false, generate_video: false, post_now: false, social_account_id: nil, scheduled_at: nil)
    # Generate content with LLM
    llm_result = LlmService.generate_content(prompt: content_text)
    
    # Get caption text
    caption = llm_result[:content] || llm_result[:body] || content_text
    hashtags = llm_result[:hashtags]
    
    # Generate media if requested
    media_url = nil
    media_type = nil
    draft = nil
    
    if generate_image
      image_result = ImageGenerationService.generate_image(prompt: content_text)
      
      if image_result[:success] && image_result[:task_id].present?
        draft = DraftContent.create!(
          user: user,
          title: caption.truncate(50),
          content: caption,
          content_type: 'image',
          platform: 'general',
          status: 'pending',
          media_url: nil,
          metadata: {
            'task_id' => image_result[:task_id],
            'service' => image_result[:service],
            'model' => image_result.dig(:metadata, :model),
            'hashtags' => hashtags
          }
        )
        
        # Schedule polling job
        ImagePollJob.perform_later(draft.id, image_result[:task_id], image_result[:service])
        
        # If image is immediately available
        if image_result[:output_url].present?
          draft.update!(media_url: image_result[:output_url], status: 'draft')
          media_url = image_result[:output_url]
        end
        
        media_type = 'image'
      end
    elsif generate_video
      video_result = VideoGenerationService.generate_video(prompt: content_text)
      
      if video_result[:success] && video_result[:task_id].present?
        draft = DraftContent.create!(
          user: user,
          title: caption.truncate(50),
          content: caption,
          content_type: 'video',
          platform: 'general',
          status: 'pending',
          media_url: nil,
          metadata: {
            'task_id' => video_result[:task_id],
            'service' => video_result[:service]
          }
        )
        
        # Schedule video polling
        VideoPollJob.perform_later(draft.id, video_result[:task_id], video_result[:service]) if defined?(VideoPollJob)
        
        media_type = 'video'
      end
    end
    
    # Create content record
    content = Content.create!(
      user: user,
      title: caption.truncate(50),
      body: caption,
      hashtags: hashtags,
      status: 'draft'
    )
    
    # Create or update media association
    if draft.present?
      content.update!(media_url: draft.media_url) if draft.media_url.present?
    end
    
    # Handle social posting
    scheduled_post = nil
    if post_now && social_account_id.present?
      social_account = SocialAccount.find_by(id: social_account_id, user: user)
      if social_account
        scheduled_post = ScheduledPost.create!(
          user: user,
          content: content,
          social_account: social_account,
          scheduled_at: scheduled_at || Time.current,
          status: scheduled_at && scheduled_at > Time.current ? 'scheduled' : 'published'
        )
      end
    end
    
    {
      success: true,
      content: content,
      draft: draft,
      media_url: draft&.media_url,
      media_type: media_type,
      scheduled_post: scheduled_post,
      caption: caption
    }
  rescue => e
    Rails.logger.error "WorkflowService.create_content_with_media error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    raise e
  end

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
    
    # Create DraftContent to track the image and poll for completion
    draft = DraftContent.create!(
      user: workflow.user,
      title: workflow.title,
      content: llm_result[:content] || llm_result[:body] || content.truncate(200),
      content_type: 'image',
      platform: 'general',
      status: 'pending',
      media_url: nil,
      metadata: {
        'task_id' => image_result[:task_id],
        'service' => image_result[:service],
        'model' => image_result.dig(:metadata, :model),
        'workflow_id' => workflow.id
      }
    )
    
    # Schedule polling job to check for image completion
    ImagePollJob.perform_later(draft.id, image_result[:task_id], image_result[:service])
    
    # Save combined results
    result_data = {
      caption: llm_result,
      image_task_id: image_result[:task_id],
      image_service: image_result[:service],
      draft_id: draft.id
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
