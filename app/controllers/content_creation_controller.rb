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

    Rails.logger.info "[ContentCreation] Starting image generation - prompt: #{prompt&.length} chars"

    begin
      result = ImageGenerationService.generate_image(
        prompt: prompt,
        size: size,
        quality: 'high',
        model: model
      )

      Rails.logger.info "[ContentCreation] ImageGenerationService result: #{result.inspect}"

      if result[:success]
        service = result[:service]
        task_id = result[:task_id]
        
        Rails.logger.info "[ContentCreation] Creating draft with task_id: #{task_id}"
        
        draft = current_user.draft_contents.create!(
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
            'aspect_ratio' => size
          }
        )

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
    model = params[:model] || 'atlascloud/magi-1-24b'
    aspect_ratio = params[:aspect_ratio] || '16:9'
    duration = params[:duration] || '5'
    source_image_url = params[:source_image_url]

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
          duration: duration
        )
      else
        result = VideoGenerationService.generate_video(
          prompt: prompt,
          duration: duration,
          aspect_ratio: aspect_ratio,
          model: model
        )
      end

      if result[:success]
        service = result[:service]
        
        draft = current_user.draft_contents.create!(
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
            'source_image_url' => source_image_url
          }
        )

        VideoPollJob.perform_later(draft.id, result[:task_id], service)

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
      result = ImageGenerationService.generate_image(
        prompt: combined_prompt,
        size: draft.metadata.dig('aspect_ratio') || '1:1',
        quality: 'high'
      )

      if result[:success]
        service = result[:service]
        model = result.dig(:metadata, :model) || 'atlascloud/qwen-image/text-to-image'
        
        if result[:output_url]
          new_draft = current_user.draft_contents.create!(
            title: "Edited - #{draft.title}",
            content: combined_prompt,
            content_type: 'image',
            platform: draft.platform,
            status: 'published',
            media_url: result[:output_url],
            metadata: { 
              'service' => service, 
              'model' => model,
              'edited_from' => draft.id,
              'edit_prompt' => edit_prompt
            }
          )
          
          redirect_to draft_path(new_draft), notice: 'Image edited successfully!'
        else
          new_draft = current_user.draft_contents.create!(
            title: "Edited - #{draft.title}",
            content: combined_prompt,
            content_type: 'image',
            platform: draft.platform,
            status: 'pending',
            media_url: nil,
            metadata: { 
              'task_id' => result[:task_id], 
              'service' => service, 
              'model' => model,
              'edited_from' => draft.id,
              'edit_prompt' => edit_prompt
            }
          )

          ImagePollJob.perform_later(new_draft.id, result[:task_id], service)
          redirect_to draft_path(new_draft), notice: 'Image editing started! Check back in a few moments.'
        end
      else
        redirect_to content_creation_index_path, alert: "Image editing failed: #{result[:error]}"
      end
    rescue => e
      Rails.logger.error "Image Edit Error: #{e.message}"
      redirect_to content_creation_index_path, alert: "Image editing failed: #{e.message}"
    end
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
