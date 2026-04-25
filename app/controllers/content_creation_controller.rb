class ContentCreationController < ApplicationController
  before_action :authenticate_user!
  before_action :check_ideas_access, only: [:generate_ideas]

  def check_ideas_access
    unless current_user.can_access_ai_content_ideas?
      redirect_to subscription_path, alert: 'Upgrade to Entrepreneur or Pro plan to access AI Content Ideas.'
    end
  end

  def index
    @drafts = current_user.draft_contents.order(updated_at: :desc)
    @suggestions = current_user.content_suggestions.order(created_at: :desc).limit(10)
    @templates = ContentTemplate.where(is_active: true).order(category: :asc)
    @campaigns = current_user.campaigns.order(created_at: :desc).limit(10)
    @social_accounts = current_user.social_accounts.order(platform: :asc).limit(10)
    # Get the most recent video draft with a video URL for inline preview
    @latest_video_draft = current_user.draft_contents
      .where(content_type: 'video')
      .where.not(media_url: nil)
      .order(updated_at: :desc)
      .first
    
    # Get the most recent image draft with a media URL for inline preview
    @latest_image_draft = current_user.draft_contents
      .where(content_type: 'image')
      .where.not(media_url: nil)
      .order(updated_at: :desc)
      .first

    # Available models for UI
    @image_models = AtlasCloudImageService.available_models
    @image_edit_models = AtlasCloudImageService.available_image_edit_models
    @video_models = AtlasCloudService.available_video_models
  end

  def generate_content
    topic = params[:topic]
    content_type = params[:content_type] || 'post'
    platform = params[:platform] || 'general'

    begin
      prompt = build_content_prompt(topic, content_type, platform)
      
      result = LlmService.generate_content(
        prompt: prompt,
        user_id: current_user.id,
        content_type: content_type
      )

      if result[:success]
        content = result[:content]
        
        draft = current_user.draft_contents.create!(
          title: content['title'] || "Content - #{topic[0..30]}",
          content: content['body'] || content.to_s,
          content_type: content_type,
          platform: platform,
          status: 'draft'
        )

        redirect_to draft_path(draft), notice: 'Content generated successfully!'
      else
        error_msg = result[:error] || 'Failed to generate content'
        redirect_to content_creation_index_path, alert: error_msg
      end
    rescue LlmService::ApiError => e
      redirect_to content_creation_index_path, alert: "AI Service error: #{e.message}"
    rescue => e
      Rails.logger.error "Content Generation Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      redirect_to content_creation_index_path, alert: "Failed to generate content: #{e.message}"
    end
  end

  def generate_ideas
    topic = params[:topic]
    count = (params[:count] || 5).to_i
    platform = params[:platform] || 'general'

    begin
      prompt = <<~PROMPT
        Generate #{count} creative social media content ideas about: #{topic}
        For platform: #{platform}
        
        Format each idea as:
        - Title: [Catchy title]
        - Description: [Brief explanation of the content idea]
        - Content Type: [post/story/reel/video/caption]
        
        Return ONLY the ideas, no introduction or conclusion.
      PROMPT

      result = LlmService.generate_content(
        prompt: prompt,
        user_id: current_user.id,
        content_type: 'ideas'
      )

      if result[:success]
        ideas_text = result[:content].to_s
        ideas = ideas_text.split(/-\s*Title:/).reject(&:blank?).map do |idea_block|
          title_match = idea_block.match(/Title:\s*(.+?)(?=Description:|$)/i)
          desc_match = idea_block.match(/Description:\s*(.+?)(?=Content Type:|$)/i)
          type_match = idea_block.match(/Content Type:\s*(.+?)(?=\z|$)/i)
          
          {
            title: title_match&.[](1)&.strip || 'Untitled',
            description: desc_match&.[](1)&.strip || '',
            content_type: type_match&.[](1)&.strip || 'post'
          }
        end

        ideas.each do |idea|
          current_user.content_suggestions.create!(
            title: idea[:title],
            content: idea[:description],
            content_type: idea[:content_type],
            topic: topic,
            platform: platform
          )
        end

        redirect_to content_creation_index_path, notice: "#{ideas.count} content ideas generated!"
      else
        error_msg = result[:error] || 'Failed to generate ideas'
        redirect_to content_creation_index_path, alert: error_msg
      end
    rescue => e
      Rails.logger.error "Content Ideas Error: #{e.message}"
      redirect_to content_creation_index_path, alert: 'Failed to generate ideas. Please try again.'
    end
  end

  # Image generation using Atlas Cloud API
  def generate_image
    prompt = params[:prompt]
    size = params[:size] || '1:1'
    model = params[:model] || 'atlascloud/qwen-image/text-to-image'
    quality = params[:quality] || 'standard'
    
    # Validate quality tier
    quality = 'standard' unless QualityTiers.valid_quality?(quality)
    credit_cost = QualityTiers.credit_cost_for(:image, quality)

    # Check credits before generation
    subscription = current_user.user_subscriptions.active.first
    unless subscription && subscription.has_credits?(credit_cost)
      redirect_to content_creation_index_path, 
        alert: "You don't have enough credits. Please upgrade your plan or wait for your monthly reset."
      return
    end

    Rails.logger.info "[ContentCreation] Starting image generation - prompt: #{prompt&.length} chars, quality: #{quality}"

    begin
      result = ImageGenerationService.generate_image(
        prompt: prompt,
        size: size,
        quality: quality,
        model: model
      )

      Rails.logger.info "[ContentCreation] ImageGenerationService result: #{result.inspect}"

      if result[:success]
        service = result[:service]
        task_id = result[:task_id]
        
        # Deduct credits after successful generation start
        subscription&.deduct_credits!(credit_cost)
        
        Rails.logger.info "[ContentCreation] Creating draft with task_id: #{task_id}"
        
        draft_attrs = {
          title: "Image - #{prompt[0..50]}",
          content: prompt,
          content_type: 'image',
          platform: 'general',
          status: 'pending',
          media_url: nil,
          metadata: { 
            'task_id' => task_id, 
            'service' => service, 
            'model' => model,
            'aspect_ratio' => size,
            'quality_tier' => quality
          }
        }
        draft_attrs[:quality_tier] = quality if DraftContent.column_names.include?('quality_tier')
        draft_attrs[:credit_cost] = credit_cost if DraftContent.column_names.include?('credit_cost')
        
        draft = current_user.draft_contents.create!(draft_attrs)

        ImagePollJob.perform_later(draft.id, task_id, service)
        Rails.logger.info "[ContentCreation] Redirecting to draft: #{draft.id}"
        redirect_to draft_path(draft), notice: 'Image generation started! Check back in a few moments.'
      else
        error_msg = result[:error] || 'Unknown error'
        Rails.logger.error "[ContentCreation] Image generation failed: #{error_msg}"
        redirect_to content_creation_index_path, alert: "Image generation failed: #{error_msg}"
      end
    rescue ImageGenerationService::ServiceUnavailableError => e
      Rails.logger.error "[ContentCreation] Service unavailable: #{e.message}"
      redirect_to content_creation_index_path, alert: "Image service unavailable: #{e.message}"
    rescue => e
      Rails.logger.error "[ContentCreation] Image Generation Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      redirect_to content_creation_index_path, alert: "Image generation failed: #{e.message}"
    end
  end

  def generate_video
    prompt = params[:prompt]
    model = params[:model] # nil = auto-select based on prompt
    aspect_ratio = params[:aspect_ratio] || '16:9'
    duration = params[:duration] || '10'
    source_image_url = params[:source_image_url]
    quality = params[:quality] || 'standard'
    overlay_text = params[:overlay_text].to_s.strip
    
    # Validate quality tier
    quality = 'standard' unless QualityTiers.valid_quality?(quality)
    credit_cost = QualityTiers.credit_cost_for(:video, quality)

    # Check credits before generation
    subscription = current_user.user_subscriptions.active.first
    unless subscription
      redirect_to content_creation_index_path,
        alert: "You don't have an active subscription. Please subscribe to a plan to generate videos."
      return
    end
    unless subscription.has_credits?(credit_cost)
      credits_info = subscription.credit_status
      redirect_to content_creation_index_path,
        alert: "You don't have enough internal credits for this video generation. You have #{credits_info[:remaining]} credits remaining. Please upgrade your plan or wait for your monthly reset."
      return
    end

    begin
      if prompt.blank? || prompt.length < 10
        raise ArgumentError, 'Please provide a more detailed prompt (at least 10 characters)'
      end

      if source_image_url.present?
        result = VideoGenerationService.generate_video_from_image(
          image_url: source_image_url,
          prompt: prompt,
          model: model,
          aspect_ratio: aspect_ratio,
          duration: duration,
          quality: quality
        )
      else
        result = VideoGenerationService.generate_video(
          prompt: prompt,
          duration: duration,
          aspect_ratio: aspect_ratio,
          model: model,
          quality: quality
        )
      end

      if result[:success]
        service = result[:service]
        
        # Deduct credits after successful generation start
        subscription&.deduct_credits!(credit_cost)
        
        draft_attrs = {
          title: "Video - #{prompt[0..50]}",
          content: prompt,
          content_type: 'video',
          platform: 'general',
          status: 'pending',
          media_url: nil,
          metadata: { 
            'task_id' => result[:task_id], 
            'service' => service, 
            'model' => model,
            'duration' => duration,
            'aspect_ratio' => aspect_ratio,
            'source_image_url' => source_image_url,
            'quality_tier' => quality
          }
        }
        draft_attrs[:quality_tier] = quality if DraftContent.column_names.include?('quality_tier')
        draft_attrs[:credit_cost] = credit_cost if DraftContent.column_names.include?('credit_cost')
        
        draft = current_user.draft_contents.create!(draft_attrs)

        VideoPollJob.perform_later(draft.id, result[:task_id])

        redirect_to draft_path(draft), notice: 'Video generation started! Check back in a few moments.'
      else
        error_msg = result[:error] || 'Failed to start video generation. The API may be busy or unavailable.'
        Rails.logger.error "[ContentCreation] Video generation failed: #{error_msg}"
        redirect_to content_creation_index_path, alert: error_msg
      end
    rescue VideoGenerationService::ServiceUnavailableError => e
      Rails.logger.error "[ContentCreation] Video service unavailable: #{e.message}"
      redirect_to content_creation_index_path, alert: e.message
    rescue AtlasCloudService::AuthenticationError => e
      Rails.logger.error "[ContentCreation] Atlas Cloud Authentication Error: #{e.message}"
      redirect_to content_creation_index_path, alert: 'Video generation authentication failed. Please check your API configuration.'
    rescue AtlasCloudService::Error => e
      Rails.logger.error "[ContentCreation] Atlas Cloud Error: #{e.message}"
      redirect_to content_creation_index_path, alert: "Video generation error: #{e.message}"
    rescue ArgumentError => e
      redirect_to content_creation_index_path, alert: e.message
    rescue => e
      Rails.logger.error "[ContentCreation] Video Generation Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      redirect_to content_creation_index_path, alert: "Video generation failed: #{e.message}"
    end
  end

  def edit_image
    draft_id = params[:draft_id]
    edit_prompt = params[:edit_prompt]
    edit_model = params[:edit_model] || 'qwen/qwen-image-2.0/edit'

    draft = current_user.draft_contents.find(draft_id)

    if draft.media_url.blank?
      redirect_to content_creation_index_path, alert: 'No image found for this draft'
      return
    end

    if edit_prompt.blank?
      redirect_to content_creation_index_path, alert: 'Please provide edit instructions'
      return
    end

    original_prompt = draft.content.presence || 'AI generated image'
    combined_prompt = "#{original_prompt}. Modification: #{edit_prompt}"

    begin
      service = AtlasCloudImageService.new
      
      result = service.edit_image(
        image_url: draft.media_url,
        prompt: combined_prompt,
        model: edit_model,
        aspect_ratio: draft.metadata.dig('aspect_ratio') || '1:1'
      )

      if result['task_id'].present?
        new_draft = current_user.draft_contents.create!(
          title: "Edited - #{draft.title}",
          content: combined_prompt,
          content_type: 'image',
          platform: draft.platform,
          status: 'pending',
          media_url: nil,
          metadata: { 
            'task_id' => result['task_id'], 
            'service' => 'atlas_cloud', 
            'model' => edit_model,
            'edited_from' => draft.id,
            'edit_prompt' => edit_prompt
          }
        )

        ImagePollJob.perform_later(new_draft.id, result['task_id'], 'atlas_cloud')
        redirect_to draft_path(new_draft), notice: 'Image editing started! Check back in a few moments.'
      else
        redirect_to content_creation_index_path, alert: "Image editing failed: #{result['error']}"
      end
    rescue AtlasCloudImageService::AuthenticationError => e
      redirect_to content_creation_index_path, alert: "Image editing authentication failed: #{e.message}"
    rescue => e
      Rails.logger.error "Image Edit Error: #{e.message}"
      redirect_to content_creation_index_path, alert: "Image editing failed: #{e.message}"
    end
  end

  def upload_media
    uploaded_file = params[:media_file]
    title = params[:title] || 'Uploaded Media'
    content_type = params[:content_type] || 'image'
    platform = params[:platform] || 'general'

    if uploaded_file.nil?
      redirect_to content_creation_index_path, alert: 'No file selected'
      return
    end

    # Validate file type
    allowed_types = ['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'video/mp4', 'video/quicktime', 'video/webm']
    unless allowed_types.include?(uploaded_file.content_type)
      redirect_to content_creation_index_path, alert: 'Invalid file type. Please upload a JPEG, PNG, GIF, WebP, or MP4 file.'
      return
    end

    # Validate file size (50MB max)
    max_size = 50.megabytes
    if uploaded_file.size > max_size
      redirect_to content_creation_index_path, alert: 'File too large. Maximum size is 50MB.'
      return
    end

    begin
      draft = current_user.draft_contents.create!(
        title: title,
        content: "User uploaded #{content_type}",
        content_type: content_type,
        platform: platform,
        status: 'draft'
      )

      draft.media.attach(uploaded_file)
      redirect_to content_creation_index_path, notice: 'File uploaded successfully!'
    rescue => e
      Rails.logger.error "Media Upload Error: #{e.message}"
      redirect_to content_creation_index_path, alert: "Upload failed: #{e.message}"
    end
  end

  def delete_media
    draft_id = params[:draft_id]
    draft = current_user.draft_contents.find(draft_id)
    
    if draft.media.attached?
      draft.media.purge
    end
    
    draft.destroy!
    
    redirect_to content_creation_index_path, notice: 'Media deleted'
  rescue ActiveRecord::RecordNotFound
    redirect_to content_creation_index_path, alert: 'Media not found'
  rescue => e
    Rails.logger.error "Delete Media Error: #{e.message}"
    redirect_to content_creation_index_path, alert: "Delete failed: #{e.message}"
  end

  private

  def build_content_prompt(topic, content_type, platform)
    case content_type
    when 'post'
      "Create an engaging #{platform} post about '#{topic}'. Include a catchy headline, body text (150-300 words), and relevant hashtags."
    when 'caption'
      "Write a catchy #{platform} caption for '#{topic}'. Keep it concise, engaging, and include 3-5 relevant hashtags."
    when 'blog'
      "Write a blog post introduction and outline about '#{topic}'. Include a compelling hook, key points, and a call-to-action."
    when 'story'
      "Create a social media story about '#{topic}'. Include the setup, conflict, and resolution in a engaging narrative format."
    when 'video_script'
      "Write a video script outline for '#{topic}'. Include hook, main points, and call-to-action. Target 60-90 seconds."
    else
      "Create engaging #{platform} content about '#{topic}'."
    end
  end
end
