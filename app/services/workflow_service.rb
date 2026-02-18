class WorkflowService
  class WorkflowError < StandardError; end

  def initialize(user)
    @user = user
  end

  # Main method to create content and optionally generate media
  def create_content_with_media(content_text:, generate_image: false, generate_video: false,
                                post_now: false, scheduled_at: nil,
                                social_account_ids: [], campaign_id: nil)
    # Step 1: Create content
    content = Content.create!(
      user: @user,
      title: content_text[0..50],
      body: content_text,
      status: :draft,
      campaign_id: campaign_id
    )

    media_url = nil
    media_type_result = nil
    message_parts = []

    # Step 2: Generate image if requested
    if generate_image && content_text.present?
      begin
        result = ImageGenerationService.generate_image(
          prompt: content_text,
          size: '1024x1024',
          quality: 'high'
        )
        
        if result[:success]
          media_url = result[:output_url] || result[:task_id]
          media_type_result = 'image'
          message_parts << "generated image"
          
          if result[:output_url].present?
            content.update!(media_url: media_url, media_urls: [media_url])
          end
        end
      rescue => e
        Rails.logger.error "Image generation failed: #{e.message}"
      end
    end

    # Step 3: Generate video if requested
    if generate_video && content_text.present?
      begin
        result = VideoGenerationService.generate_video(
          prompt: content_text,
          duration: '5',
          aspect_ratio: '16:9'
        )
        
        if result[:success]
          media_url = result[:task_id]
          media_type_result = 'video'
          message_parts << "generated video"
          
          # Store the task_id - actual URL will be fetched when polling completes
          content.update!(media_url: media_url, media_urls: [media_url])
        end
      rescue => e
        Rails.logger.error "Video generation failed: #{e.message}"
      end
    end

    # Step 4: Schedule or publish
    post = nil
    if post_now || scheduled_at.present?
      social_account = if social_account_ids.present?
        SocialAccount.where(id: social_account_ids, user: @user).first
      else
        @user.social_accounts.first
      end
      
      if social_account
        post_time = post_now ? Time.current : (scheduled_at.present? ? scheduled_at.to_time : 1.hour.from_now)
        
        post = ScheduledPost.create!(
          user: @user,
          content: content,
          social_account: social_account,
          scheduled_at: post_time,
          status: post_now ? :published : :scheduled
        )
        
        message_parts << (post_now ? "posted immediately" : "scheduled for #{post_time.strftime('%b %d at %I:%M %p')}")
        
        if post_now
          post.update!(status: :publishing)
        end
      else
        message_parts << "content created (no social account connected to post)"
      end
    else
      message_parts << "content saved as draft"
    end

    {
      success: true,
      message: message_parts.join(", "),
      content: content,
      media_url: media_url,
      media_type: media_type_result,
      scheduled_post: post
    }
  rescue => e
    Rails.logger.error "WorkflowService Error: #{e.message}"
    { success: false, error: e.message }
  end

  # Execute full workflow: content -> media -> schedule/publish
  def execute_workflow(workflow_id)
    workflow = Workflow.find(workflow_id)

    case workflow.workflow_type
    when 'content_to_image_post'
      execute_content_to_image_post(workflow)
    when 'content_to_video_post'
      execute_content_to_video_post(workflow)
    when 'content_to_post'
      execute_content_to_post(workflow)
    else
      raise WorkflowError, "Unknown workflow type: #{workflow.workflow_type}"
    end
  end

  # Legacy class method support
  def self.create_content_with_media(user:, content_text:, media_type: nil, 
                                     generate_image: false, generate_video: false,
                                     schedule_post: false, post_now: false,
                                     social_account_id: nil, scheduled_at: nil)
    new(user).create_content_with_media(
      content_text: content_text,
      generate_image: generate_image,
      generate_video: generate_video,
      post_now: post_now,
      scheduled_at: scheduled_at,
      social_account_ids: social_account_id ? [social_account_id] : []
    )
  end

  def self.execute_workflow(workflow_id)
    new(nil).execute_workflow(workflow_id)
  end

  private

  def execute_content_to_image_post(workflow)
    params = workflow.params.with_indifferent_access
    content_text = params[:content_text]
    social_account_id = params[:social_account_id]
    scheduled_at = params[:scheduled_at]
    post_now = params[:post_now] || false

    workflow.update!(status: :running)

    content = generate_ai_content(content_text, workflow.user)
    update_step(workflow, 'generate_content', content)

    image_result = generate_image(content)
    update_step(workflow, 'generate_image', image_result)

    post = schedule_or_publish(
      workflow.user,
      content,
      image_result[:url],
      'image',
      social_account_id,
      scheduled_at,
      post_now
    )

    workflow.update!(status: :completed)
    { content: content, image: image_result, post: post }
  end

  def execute_content_to_video_post(workflow)
    params = workflow.params.with_indifferent_access
    content_text = params[:content_text]
    social_account_id = params[:social_account_id]
    scheduled_at = params[:scheduled_at]
    post_now = params[:post_now] || false

    workflow.update!(status: :running)

    content = generate_ai_content(content_text, workflow.user)
    update_step(workflow, 'generate_content', content)

    video_result = generate_video(content)
    update_step(workflow, 'generate_video', video_result)

    post = schedule_or_publish(
      workflow.user,
      content,
      video_result[:url],
      'video',
      social_account_id,
      scheduled_at,
      post_now
    )

    workflow.update!(status: :completed)
    { content: content, video: video_result, post: post }
  end

  def execute_content_to_post(workflow)
    params = workflow.params.with_indifferent_access
    content_text = params[:content_text]
    social_account_id = params[:social_account_id]
    scheduled_at = params[:scheduled_at]
    post_now = params[:post_now] || false

    workflow.update!(status: :running)

    content = generate_ai_content(content_text, workflow.user)
    update_step(workflow, 'generate_content', content)

    post = schedule_or_publish(
      workflow.user,
      content,
      nil,
      'text',
      social_account_id,
      scheduled_at,
      post_now
    )

    workflow.update!(status: :completed)
    { content: content, post: post }
  end

  def generate_ai_content(prompt, user)
    if prompt.present?
      Content.create!(
        user: user,
        title: prompt[0..50],
        body: prompt,
        status: :draft
      )
    else
      raise WorkflowError, "No content provided"
    end
  end

  def generate_image(content)
    begin
      result = ImageGenerationService.generate_image(
        prompt: content.body.to_s,
        size: '1024x1024',
        quality: 'high'
      )
      
      { 
        success: result[:success], 
        url: result[:output_url], 
        task_id: result[:task_id] 
      }
    rescue => e
      { success: false, error: e.message }
    end
  end

  def generate_video(content)
    begin
      result = VideoGenerationService.generate_video(
        prompt: content.body.to_s,
        duration: '5',
        aspect_ratio: '16:9'
      )
      
      { 
        success: result[:success], 
        task_id: result[:task_id] 
      }
    rescue => e
      { success: false, error: e.message }
    end
  end

  def schedule_or_publish(user, content, media_url, media_type, social_account_id, scheduled_at, post_now)
    social_account = SocialAccount.find_by(id: social_account_id) || user.social_accounts.first
    
    return nil unless social_account

    content.update!(media_url: media_url) if media_url.present?

    post_time = post_now ? Time.current : (scheduled_at || 1.hour.from_now)
    
    post = ScheduledPost.create!(
      user: user,
      content: content,
      social_account: social_account,
      scheduled_at: post_time,
      status: post_now ? :published : :scheduled
    )

    if post_now
      # Will be handled asynchronously
    end

    post
  end

  def update_step(workflow, step_type, output)
    step = workflow.workflow_steps.find_by(step_type: step_type)
    step&.update!(
      status: 'completed',
      output: output
    )
  end
end
