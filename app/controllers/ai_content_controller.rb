# AI Content Controller - Handles AI content generation requests
class AiContentController < ApplicationController
  before_action :authenticate_user!, except: [:index, :show]
  before_action :set_user_content, only: [:show]
  before_action :load_options, only: [:index, :new]

  def index
    @contents = if user_signed_in?
                 AiGeneratedContent.where(user: current_user).recent
               else
                 AiGeneratedContent.none
               end

    @contents = @contents.by_platform(params[:platform]) if params[:platform].present?
    @contents = @contents.by_content_type(params[:content_type]) if params[:content_type].present?
    @contents = @contents.by_format(params[:output_format]) if params[:output_format].present?
    @contents = @contents.page(params[:page]).per(12)
  end

  def show
    redirect_to ai_content_index_path, alert: 'Content not found' unless @content
  end

  def new
    @content = AiGeneratedContent.new
  end

  def create
    @content = AiGeneratedContent.new(content_params)
    @content.user = current_user if user_signed_in?

    if @content.save
      GenerateAiContentJob.perform_later(@content.id)
      redirect_to ai_content_path(@content), notice: 'AI is generating your content...'
    else
      load_options
      render :new, status: :unprocessable_entity
    end
  end

  def generate
    result = AnthropicContentService.generate_all_content(
      topic: params[:topic],
      brand_voice: params[:brand_voice] || 'professional',
      platform: params[:platform] || 'instagram',
      additional_context: params[:additional_context],
      custom_system_prompt: params[:custom_system_prompt],
      output_format: params[:output_format] || 'short_form'
    )

    @content = AiGeneratedContent.create!(
      user: current_user,
      topic: params[:topic],
      brand_voice: params[:brand_voice] || 'professional',
      platform: params[:platform] || 'instagram',
      content_type: 'all',
      additional_context: params[:additional_context],
      custom_system_prompt: params[:custom_system_prompt],
      output_format: params[:output_format] || 'short_form',
      caption: result[:caption],
      blog_post: result[:blog_post],
      ad_copy: result[:ad_copy],
      hashtags: result[:hashtags],
      thread_story: result[:thread_story],
      email_marketing: result[:email_marketing]
    )

    render partial: 'result', locals: { content: @content }
  rescue AnthropicContentService::ContentGenerationError => e
    render partial: 'error', locals: { error: e.message }, status: :unprocessable_entity
  end

  def regenerate
    @content = AiGeneratedContent.find_by(id: params[:id], user: current_user)

    unless @content
      head :not_found
      return
    end

    content_type = params[:content_type] || @content.content_type

    service = AnthropicContentService.new(
      topic: @content.topic,
      brand_voice: @content.brand_voice,
      platform: @content.platform,
      content_type: content_type,
      additional_context: @content.additional_context,
      custom_system_prompt: @content.custom_system_prompt,
      output_format: @content.output_format
    )

    new_content = service.generate

    field_name = content_type == 'all' ? 'caption' : content_type
    if @content.respond_to?("#{field_name}=")
      @content.update!(field_name => new_content)
    end

    render partial: 'regenerate_result', locals: { content: @content, content_type: content_type }
  rescue => e
    render partial: 'error', locals: { error: e.message }, status: :unprocessable_entity
  end

  def update_content
    @content = AiGeneratedContent.find_by(id: params[:id], user: current_user)

    unless @content
      head :not_found
      return
    end

    content_field = params[:content_field]
    new_content_text = params[:content_text] || params.dig(:ai_generated_content, content_field)

    unless @content.respond_to?("#{content_field}=")
      render partial: 'error', locals: { error: 'Invalid content field' }, status: :unprocessable_entity
      return
    end

    @content.update(
      content_field => new_content_text,
      is_edited: true
    )

    render partial: 'updated_content', locals: { content: @content, content_field: content_field }
  rescue => e
    render partial: 'error', locals: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_user_content
    @content = AiGeneratedContent.find_by(id: params[:id])
    return unless @content && user_signed_in?

    redirect_to ai_content_index_path, alert: 'Access denied' unless @content.user == current_user || @content.user.nil?
  end

  def load_options
    @platforms = AnthropicContentService.platforms
    @brand_voices = AnthropicContentService.brand_voices
    @content_types = AnthropicContentService.content_types
    @output_formats = AnthropicContentService.output_formats
  end

  def content_params
    params.require(:ai_generated_content).permit(
      :topic, :brand_voice, :platform, :content_type, :additional_context,
      :custom_system_prompt, :output_format
    )
  end
end
