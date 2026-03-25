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
    # Get the most recent video draft with a video URL for inline preview
    @latest_video_draft = current_user.draft_contents
      .where(content_type: 'video')
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

    if topic.blank?
      redirect_to content_creation_index_path, alert: 'Please enter a topic'
      return
    end

    begin
      # Generate content using Anthropic Claude
      prompt = build_content_prompt(topic, content_type, platform)
      
      Rails.logger.info "[ContentCreation] Starting content generation for #{content_type}/#{platform}"
      Rails.logger.info "[ContentCreation] Topic: #{topic}"
      
      content = LlmService.call_blocking(
        prompt: prompt,
        system: "You are an expert social media content creator. Generate engaging, platform-appropriate content.",
        max_tokens: 2000
      )

      # Save as a draft
      draft = current_user.draft_contents.create!(
        title: "#{content_type.titleize} - #{topic[0..30]}",
        content: content,
        content_type: content_type,
        platform: platform,
        status: 'draft'
      )

      redirect_to draft_path(draft), notice: 'Content generated successfully!'
    rescue LlmService::LlmError => e
      Rails.logger.error "[ContentCreation] LLM Service Error: #{e.class} - #{e.message}"
      Rails.logger.error "[ContentCreation] Backtrace: #{e.backtrace.first(10).join("\n")}"
      redirect_to content_creation_index_path, alert: "AI service error: #{e.message}"
    rescue => e
      Rails.logger.error "[ContentCreation] Content Generation Error: #{e.class} - #{e.message}"
      Rails.logger.error "[ContentCreation] Backtrace: #{e.backtrace.first(10).join("\n")}"
      redirect_to content_creation_index_path, alert: "Failed to generate content: #{e.message}"
    end
  end

  def generate_ideas
    topic = params[:topic]
    platform = params[:platform] || 'general'
    count = 3 # Fixed at 3 ideas per request

    prompt = "Generate #{count} creative content ideas for #{platform} about '#{topic}'. "\
             "Return as a JSON array with objects containing 'title' and 'description' fields. "\
             "Keep descriptions under 100 characters each."

    begin
      content = LlmService.call_blocking(
        prompt: prompt,
        system: "You are a social media content strategist. Generate creative, engaging ideas.",
        max_tokens: 1500
      )

      # Parse the JSON response - handle markdown code blocks
      json_content = content.strip
      # Remove markdown code block markers if present
      json_content = json_content.sub(/^```json\s*/i, '').sub(/\s*```$/i, '')
      json_content = json_content.sub(/^```\s*/i, '').sub(/\s*```$/i, '')
      ideas = JSON.parse(json_content)

      ideas.each do |idea|
        current_user.content_suggestions.create!(
          topic: topic,
          suggestion: idea['description'],
          content_type: 'idea',
          platform: platform,
          confidence: 0.8,
          status: 'pending'
        )
      end

      redirect_to content_creation_index_path, notice: "#{ideas.count} content ideas generated!"
    rescue => e
      Rails.logger.error "Content Ideas Error: #{e.message}"
      redirect_to content_creation_index_path, alert: 'Failed to generate ideas. Please try again.'
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

  # Content generation now uses Anthropic Claude via LlmService
  # LlmService handles all API communication with proper error handling

  def generate_image
    prompt = params[:prompt]
    size = params[:size] || '1:1'
    model = params[:model] || 'black-forest-labs/flux-1.1-pro'

    Rails.logger.info "[ContentCreation] Starting image generation - prompt: #{prompt&.length} chars"

    begin
      # Use unified service
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
        
        # Always use polling to ensure we get the final URL
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
      # Validate prompt
      if prompt.blank? || prompt.length < 10
        raise ArgumentError, 'Please provide a more detailed prompt (at least 10 characters)'
      end

      if source_image_url.present?
        # Image-to-video generation
        result = VideoGenerationService.generate_video_from_image(
          image_url: source_image_url,
          prompt: prompt,
          model: model,
          aspect_ratio: aspect_ratio,
          duration: duration
        )
      else
        # Text-to-video generation
        result = VideoGenerationService.generate_video(
          prompt: prompt,
          duration: duration,
          aspect_ratio: aspect_ratio,
          model: model
        )
      end

      if result[:success]
        service = result[:service]
        
        # Save as a draft with task_id for polling
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

        # Start polling job
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

    # Combine original prompt with edit instructions to generate a new image
    original_prompt = draft.content.presence || 'AI generated image'
    combined_prompt = "#{original_prompt}. Modification: #{edit_prompt}"

    begin
      # Generate a new image based on the edit prompt
      result = ImageGenerationService.generate_image(
        prompt: combined_prompt,
        size: draft.metadata.dig('aspect_ratio') || '1:1',
        quality: 'high'
      )

      if result[:success]
        service = result[:service]
        model = result.dig(:metadata, :model) || 'black-forest-labs/flux-1.1-pro'
        
        if result[:output_url]
          # Create a new draft with the edited image
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
          # Create draft with task_id for polling
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
end
