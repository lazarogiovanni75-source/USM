class ContentCreationController < ApplicationController
  before_action :authenticate_user!

  def index
    @drafts = current_user.draft_contents.order(updated_at: :desc)
    @suggestions = current_user.content_suggestions.order(created_at: :desc).limit(10)
    @templates = ContentTemplate.where(is_active: true).order(category: :asc)
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

    # Call Railway backend for AI content generation
    response = call_railway_content_api(prompt, {
      content_type: content_type,
      platform: platform,
      topic: topic
    })

    # Save as draft
    draft = current_user.draft_contents.create!(
      title: "#{content_type.titleize} - #{topic}",
      content: response[:content],
      content_type: content_type,
      platform: platform,
      status: 'draft'
    )

    @draft = draft
    @ai_response = response
  end

  def publish_content
    draft = current_user.draft_contents.find(params[:id])
    
    # Convert draft to published content
    content = current_user.contents.create!(
      campaign_id: params[:campaign_id],
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

  def call_railway_content_api(prompt, context)
    begin
      response = RestClient.post(
        "#{ENV['RAILWAY_BACKEND_URL']}/api/ai/generate-content",
        {
          prompt: prompt,
          context: context,
          user_id: current_user.id
        },
        {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{ENV['RAILWAY_API_KEY']}"
        }
      )
      
      JSON.parse(response.body)
    rescue => e
      Rails.logger.error "Railway Content API Error: #{e.message}"
      { success: false, content: "Failed to generate content. Please try again.", confidence: 0.0 }
    end
  end
end