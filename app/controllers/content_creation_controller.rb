class ContentCreationController < ApplicationController
  before_action :authenticate_user!

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
  end

  def generate_ideas
    topic = params[:topic]
    platform = params[:platform] || 'general'
    count = 3 # Fixed at 3 ideas per request

    prompt = "Generate #{count} creative content ideas for #{platform} about '#{topic}'. "\
             "Return as a JSON array with objects containing 'title' and 'description' fields. "\
             "Keep descriptions under 100 characters each."

    begin
      content = LlmService.call(
        prompt: prompt,
        system: "You are a social media content strategist. Generate creative, engaging ideas.",
        temperature: 0.8,
        max_tokens: 1500
      )

      # Parse the JSON response
      ideas = JSON.parse(content)

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

  def generate_image
    prompt = params[:prompt]
    size = params[:size] || '1024x1024'

    begin
      # Use unified service with primary/secondary fallback
      result = ImageGenerationService.generate_image(
        prompt: prompt,
        size: size,
        quality: 'high'
      )

      if result[:success]
        service = result[:service]
        model = result.dig(:metadata, :model) || 'gpt-image-1.5'
        
        if result[:output_url]
          # Secondary service (OpenAI DALL-E) returns URL directly
          draft = current_user.draft_contents.create!(
            title: "Image - #{prompt[0..50]}",
            content: prompt,
            content_type: 'image',
            platform: 'general',
            status: 'completed',
            media_url: result[:output_url],
            metadata: { 'service' => service, 'model' => model }
          )
          
          redirect_to draft_path(draft), notice: 'Image generated successfully!'
        else
          # Primary service (Defapi) returns task_id for polling
          draft = current_user.draft_contents.create!(
            title: "Image - #{prompt[0..50]}",
            content: prompt,
            content_type: 'image',
            platform: 'general',
            status: 'pending',
            media_url: nil,
            metadata: { 
              'task_id' => result[:task_id], 
              'service' => service, 
              'model' => model 
            }
          )

          ImagePollJob.perform_later(draft.id, result[:task_id])
          redirect_to draft_path(draft), notice: 'Image generation started! Check back in a few moments.'
        end
      else
        redirect_to content_creation_index_path, alert: "Image generation failed: #{result[:error]}"
      end
    rescue ImageGenerationService::ServiceUnavailableError => e
      redirect_to content_creation_index_path, alert: e.message
    rescue => e
      Rails.logger.error "Image Generation Error: #{e.message}"
      redirect_to content_creation_index_path, alert: "Image generation failed: #{e.message}"
    end
  end

  def generate_video
    prompt = params[:prompt]

    begin
      # Validate prompt
      if prompt.blank? || prompt.length < 10
        raise ArgumentError, 'Please provide a more detailed prompt (at least 10 characters)'
      end

      # Use unified service with primary/secondary fallback
      result = VideoGenerationService.generate_video(
        prompt: prompt,
        duration: '10',
        aspect_ratio: '16:9'
      )

      if result[:success]
        service = result[:service]
        model = result.dig(:metadata, :model) || 'seedance-v1-pro'
        
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
            'duration' => result.dig(:metadata, :duration),
            'aspect_ratio' => result.dig(:metadata, :aspect_ratio)
          }
        )

        # Start polling job
        SoraPollJob.perform_later(draft.id, result[:task_id], service)

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
    rescue PoyoService::AuthenticationError => e
      Rails.logger.error "[ContentCreation] Poyo.ai Authentication Error: #{e.message}"
      redirect_to content_creation_index_path, alert: 'Video generation authentication failed. Please check your API configuration.'
    rescue PoyoService::Error => e
      Rails.logger.error "[ContentCreation] Poyo.ai Error: #{e.message}"
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

    # Note: Image editing is limited - show message
    redirect_to content_creation_index_path, alert: 'Image editing requires DALL-E 2 API. Please generate a new image instead.'
  rescue ActiveRecord::RecordNotFound
    redirect_to content_creation_index_path, alert: 'Draft not found'
  end

  def create_draft
    draft = current_user.draft_contents.create!(
      title: params[:title],
      content: params[:content],
      content_type: params[:content_type] || 'post',
      platform: params[:platform] || 'general',
      status: 'draft'
    )

    # Trigger automation for draft_created
    trigger_automation('draft_created', draft)

    @draft = draft
    flash[:notice] = 'Draft created successfully'
    redirect_to draft_path(draft)
  end

  def update_draft
    draft = current_user.draft_contents.find(params[:id])
    
    if draft.update(
      title: params[:title],
      content: params[:content],
      content_type: params[:content_type],
      platform: params[:platform],
      status: params[:status] || 'draft'
    )
      @draft = draft
      flash[:notice] = 'Draft updated successfully'
      redirect_to draft_path(draft)
    else
      flash[:alert] = draft.errors.full_messages.join(', ')
      redirect_to edit_draft_path(draft)
    end
  end

  def generate_content
    topic = params[:topic]
    content_type = params[:content_type] || 'post'
    platform = params[:platform] || 'general'
    template_id = params[:template_id]

    # Use template if provided
    if template_id.present?
      template = ContentTemplate.find(template_id)
      prompt = "Generate content using this template: #{template.content}. Topic: #{topic}. Platform: #{platform}."
    else
      prompt = "Create a #{content_type} for #{platform} about: #{topic}. Be creative, engaging, and platform-appropriate."
    end

    # Try LLM service first (OpenAI or Gemini)
    if ENV['OPENAI_API_KEY'].present? || ENV['LLM_API_KEY'].present?
      response = call_llm_service(prompt, platform)

      if response[:success] && response[:content].present?
        # Save as draft with AI-generated content
        draft = current_user.draft_contents.create!(
          title: "#{content_type.titleize} - #{topic}",
          content: response[:content],
          content_type: content_type,
          platform: platform,
          status: 'draft'
        )

        redirect_to draft_path(draft), notice: 'Content generated successfully'
      else
        # Fallback to sample content
        generate_fallback_content(topic, content_type, platform)
      end
    else
      # No LLM configured, use fallback
      generate_fallback_content(topic, content_type, platform)
    end
  end

  def publish_content
    draft = current_user.draft_contents.find(params[:id])
    
    # Find or create a default campaign for the user
    campaign = current_user.campaigns.first_or_create(
      name: 'Default Campaign',
      status: 'active'
    )
    
    # Convert draft to published content
    content = current_user.contents.create!(
      campaign_id: campaign.id,
      title: draft.title,
      body: draft.content,
      content_type: draft.content_type,
      platform: draft.platform,
      status: 'published',
      media_urls: []
    )

    # Update draft status
    draft.update(status: 'published')

    # Trigger automation for content_published
    trigger_automation('content_published', content)

    @content = content
    flash[:notice] = 'Content published successfully'
    redirect_to content_path(content)
  rescue => e
    Rails.logger.error "Publish Error: #{e.message}"
    redirect_to content_creation_index_path, alert: "Failed to publish: #{e.message}"
  end

  def schedule_content
    draft = current_user.draft_contents.find(params[:id])
    scheduled_time = params[:scheduled_at]
    social_account_id = params[:social_account_id]

    # Create scheduled post
    scheduled_post = current_user.scheduled_posts.create!(
      content_id: draft.content.id,
      social_account_id: social_account_id,
      scheduled_time: scheduled_time,
      status: 'pending'
    )

    # Update draft status
    draft.update(status: 'scheduled')

    @scheduled_post = scheduled_post
    flash[:notice] = 'Content scheduled successfully'
    redirect_to scheduled_post_path(scheduled_post)
  end

  private

  def generate_fallback_content(topic, content_type, platform)
    # Generate sample content without AI backend
    sample_content = case platform
    when 'instagram'
      "✨ #{topic}

Here's something special for you! 💫

#content #socialmedia #{topic.downcase.gsub(/\s+/, '#')}"
    when 'twitter'
      "🧵 #{topic}

#{topic.capitalize} is changing everything. Here's what you need to know 👇

#{topic.capitalize} #trending"
    when 'linkedin'
      "💡 Insight on #{topic}

After deep analysis, here's what I found:

1. #{topic.capitalize} is evolving
2. Early adopters see 3x results
3. The key is consistency

What's your experience with #{topic}?

#ProfessionalDevelopment #{topic.capitalize}"
    else
      "📝 #{topic}

Check out this new content about #{topic}!

#content #socialmedia"
    end

    draft = current_user.draft_contents.create!(
      title: "#{content_type.titleize} - #{topic}",
      content: sample_content,
      content_type: content_type,
      platform: platform,
      status: 'draft'
    )

    redirect_to draft_path(draft), notice: 'Content generated successfully (sample)'
  end

  def call_llm_service(prompt, platform)
    # Build context-aware prompt based on platform
    platform_guidance = case platform
    when 'instagram'
      'Keep it visually engaging, use minimal hashtags (max 5), conversational tone, include call-to-action'
    when 'twitter'
      'Concise and punchy, max 280 characters, engaging hooks, relevant hashtags (2-3 max)'
    when 'linkedin'
      'Professional yet approachable, data-driven insights, thought leadership style, industry relevant hashtags'
    when 'tiktok'
      'Trendy, Gen Z friendly, conversational, viral-style hooks, includes trending sounds reference'
    when 'youtube'
      'Engaging title-style hook, description with timestamps, call-to-action for engagement'
    else
      'Engaging and platform-appropriate content'
    end

    enhanced_prompt = "#{prompt}

Platform guidelines: #{platform_guidance}

Please return only the content body without any introduction or explanation."

    # Use LlmService (supports OpenAI, Gemini, DeepSeek)
    response = LlmService.call(
      prompt: enhanced_prompt,
      system: "You are an expert social media content creator. Create engaging, platform-optimized content.",
      temperature: 0.8,
      max_tokens: 1000
    )

    if response[:success] && response[:content].present?
      { success: true, content: response[:content] }
    else
      { success: false, error: response[:error] || 'LLM generation failed' }
    end
  end

  def trigger_automation(event_type, content)
    return unless current_user
    
    service = AutomationRulesService.new(current_user)
    service.execute_rules(event_type, { content: content, draft: content, user: current_user })
  rescue => e
    Rails.logger.error "[Automation] Error triggering #{event_type}: #{e.message}"
  end
end
