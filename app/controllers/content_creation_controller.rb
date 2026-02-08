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
      result = SoraService.new.generate_image(prompt: prompt, size: size)

      if result['output'].present?
        # Save as a draft with image
        draft = current_user.draft_contents.create!(
          title: "Image - #{prompt[0..50]}",
          content: prompt,
          content_type: 'image',
          platform: 'general',
          status: 'draft',
          media_url: result['output']
        )

        redirect_to draft_path(draft), notice: 'Image generated successfully!'
      elsif result['urls']&.present?
        # Prediction started, save with prediction URL for polling
        draft = current_user.draft_contents.create!(
          title: "Image - #{prompt[0..50]}",
          content: prompt,
          content_type: 'image',
          platform: 'general',
          status: 'draft',
          media_url: nil
        )

        # Start polling job
        SoraPollJob.perform_later(draft.id, result['urls']['get'])

        redirect_to draft_path(draft), notice: 'Image generation started! Check back in a few moments.'
      else
        redirect_to content_creation_index_path, alert: 'Failed to start image generation.'
      end
    rescue => e
      Rails.logger.error "Image Generation Error: #{e.message}"
      redirect_to content_creation_index_path, alert: 'Image generation failed. Please check your Replicate API key.'
    end
  end

  def generate_video
    prompt = params[:prompt]
    duration = params[:duration] || '5s'

    begin
      result = SoraService.new.generate_video(prompt: prompt, duration: duration)

      if result['output'].present?
        # Save as a draft with video
        draft = current_user.draft_contents.create!(
          title: "Video - #{prompt[0..50]}",
          content: prompt,
          content_type: 'video',
          platform: 'general',
          status: 'draft',
          media_url: result['output']
        )

        redirect_to content_creation_index_path(video_draft_id: draft.id), notice: 'Video generated successfully!'
      elsif result['urls']&.present?
        # Prediction started, save with prediction URL for polling
        draft = current_user.draft_contents.create!(
          title: "Video - #{prompt[0..50]}",
          content: prompt,
          content_type: 'video',
          platform: 'general',
          status: 'draft',
          media_url: nil
        )

        # Start polling job
        SoraPollJob.perform_later(draft.id, result['urls']['get'])

        redirect_to content_creation_index_path(video_draft_id: draft.id), notice: 'Video generation started! Check back in a few moments.'
      else
        redirect_to content_creation_index_path, alert: 'Failed to start video generation.'
      end
    rescue => e
      Rails.logger.error "Video Generation Error: #{e.message}"
      redirect_to content_creation_index_path, alert: 'Video generation failed. Please check your Replicate API key.'
    end
  end

  def create_draft
    draft = current_user.draft_contents.create!(
      title: params[:title],
      content: params[:content],
      content_type: params[:content_type] || 'post',
      platform: params[:platform] || 'general',
      status: 'draft'
    )

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
      "â¨ #{topic}

Here's something special for you! ð«

# #{topic.gsub(' ', '').underscore} #SocialMedia #ContentCreation"
    when 'twitter'
      "#{topic}. What's your thoughts? ð

#{(1..3).map { |i| "##{topic.gsub(' ', '').underscore}#{i}" }.join(' ')}"
    when 'facebook'
      "We're excited to share about #{topic}!

Have you tried this yet? Let us know in the comments below! ð"
    when 'linkedin'
      "#{topic}

In today's fast-paced world, staying ahead means adapting to new trends.

Key takeaways:
â¢ Embrace change
â¢ Stay consistent
â¢ Focus on quality

What are your thoughts?

# #{topic.gsub(' ', '').underscore} #ProfessionalGrowth"
    when 'tiktok'
      "POV: You just discovered #{topic} ð¬

#fyp # #{topic.gsub(' ', '').underscore} #viral"
    else
      "#{topic}

Create engaging content that resonates with your audience.

- Be authentic
- Stay consistent
- Engage with your community"
    end

    draft = current_user.draft_contents.create!(
      title: "#{content_type.titleize} - #{topic}",
      content: sample_content,
      content_type: content_type,
      platform: platform,
      status: 'draft'
    )

    redirect_to draft_path(draft), notice: 'Content generated (sample)'
  end

  def call_llm_service(prompt, platform)
    system_prompt = "You are a social media content expert. Create engaging, platform-appropriate content.\n\nPlatform-specific guidelines:\n- Instagram: Use emojis, hashtags, line breaks. Include call-to-action.\n- Twitter: Keep under 280 characters, use relevant hashtags.\n- Facebook: Longer posts okay, encourage engagement.\n- LinkedIn: Professional tone, use bullet points for key takeaways.\n- TikTok: Trendy, casual, use relevant hashtags.\n- YouTube: Descriptive, engaging, include timestamps if relevant."

    begin
      content = LlmService.call(
        prompt: prompt,
        system: system_prompt,
        temperature: 0.7,
        max_tokens: 1000
      )

      if content.present?
        { success: true, content: content }
      else
        { success: false, content: nil }
      end
    rescue => e
      Rails.logger.error "LLM Service Error: #{e.message}"
      { success: false, content: nil }
    end
  end
end