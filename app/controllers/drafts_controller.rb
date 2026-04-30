class DraftsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_draft, only: %i[show edit update destroy convert_to_content duplicate retry_video_status download]

  def index
    @drafts = current_user.draft_contents.includes(:content_suggestions).order(updated_at: :desc)
    @suggestions = current_user.content_suggestions.pending.order(created_at: :desc)
  end

  def show
    @draft = current_user.draft_contents.find(params[:id])
    @suggestions = @draft.content_suggestions.order(created_at: :desc) if @draft.present?
  end

  def new
    @draft = current_user.draft_contents.new
    @suggestions = current_user.content_suggestions.pending.order(created_at: :desc)
  end

  def create
    @draft = current_user.draft_contents.new(draft_params)
    
    if @draft.save
      # Auto-generate AI suggestions if requested
      if params[:generate_suggestions] == 'true'
        generate_suggestions(@draft)
      end
      
      redirect_to draft_path(@draft), notice: 'Draft created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @draft = current_user.draft_contents.find(params[:id])
  end

  def update
    if @draft.update(draft_params)
      # Regenerate suggestions if content changed significantly
      if params[:regenerate_suggestions] == 'true'
        regenerate_suggestions(@draft)
      end
      
      redirect_to draft_path(@draft), notice: 'Draft updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @draft.destroy
    redirect_to drafts_url, notice: 'Draft deleted successfully.'
  end

  def convert_to_content
    @draft = current_user.draft_contents.find(params[:id])
    
    # Find or create a default campaign for the user
    campaign = current_user.campaigns.first_or_create(
      name: 'Default Campaign',
      status: 'active'
    )
    
    # Create actual content from draft
    content = current_user.contents.build(
      campaign_id: campaign.id,
      title: @draft.title,
      body: @draft.content,
      content_type: @draft.content_type,
      platform: @draft.platform,
      status: 'published'
    )

    if content.save
      # Update draft status
      @draft.update(status: 'published')
      
      # Accept related suggestions
      @draft.content_suggestions.where(status: 'pending').update_all(status: 'accepted')
      
      redirect_to content_path(content), notice: 'Draft converted to published content.'
    else
      redirect_to draft_path(@draft), alert: "Failed to convert draft to content: #{content.errors.full_messages.join(', ')}."
    end
  end

  def duplicate
    @draft = current_user.draft_contents.find(params[:id])
    duplicated_draft = @draft.dup
    duplicated_draft.title = "#{@draft.title} (Copy)"
    duplicated_draft.status = 'draft'
    duplicated_draft.content_suggestions = @draft.content_suggestions.map(&:dup)
    
    if duplicated_draft.save
      redirect_to draft_path(duplicated_draft), notice: 'Draft duplicated successfully.'
    else
      redirect_to draft_path(@draft), alert: 'Failed to duplicate draft.'
    end
  end

  def retry_video_status
    @draft = current_user.draft_contents.find(params[:id])
    
    # Only retry for video/image content with a task_id
    unless @draft.content_type.in?(['video', 'image'])
      redirect_to draft_path(@draft), alert: 'Only video/image drafts can retry status check.'
      return
    end
    
    task_id = @draft.metadata['task_id']
    service = @draft.metadata['service'] || 'atlas_cloud'
    
    if task_id.blank?
      redirect_to draft_path(@draft), alert: 'No task ID found for this draft.'
      return
    end
    
    begin
      # Manually check the status
      case service
      when 'atlas_cloud'
        status_response = AtlasCloudService.new.task_status(task_id)
      else
        status_response = AtlasCloudService.new.task_status(task_id)
      end
      
      Rails.logger.info "[retry_video_status] Draft #{@draft.id}, Task #{task_id}, Status: #{status_response['status']}, Output: #{status_response['output']}"
      
      raw_status = status_response['status']&.downcase
      
      if raw_status.in?(['success', 'completed', 'done', 'finished', 'ready']) && status_response['output'].present?
        @draft.update(
          media_url: status_response['output'],
          status: 'draft',
          metadata: @draft.metadata.merge({ 'completed_at' => Time.current.to_i })
        )
        redirect_to draft_path(@draft), notice: 'Video found! Media URL updated.'
      elsif raw_status.in?(['in_progress', 'pending', 'submitted', 'starting', 'processing', 'running', 'not_started'])
        @draft.update(status: 'pending', metadata: @draft.metadata.merge({ 'error' => nil }))
        VideoPollJob.perform_later(@draft.id, task_id)
        redirect_to draft_path(@draft), notice: 'Video still processing. Will auto-refresh...'
      elsif raw_status == 'not_found'
        # Task expired or never existed - offer to regenerate
        @draft.update(
          status: 'failed', 
          metadata: @draft.metadata.merge({ 
            'error' => 'Task expired or not found. Would you like to generate a new video?',
            'task_expired' => true,
            'last_check' => Time.current.to_i
          })
        )
        redirect_to draft_path(@draft), alert: 'Video task expired. Please generate a new video from the content creation page.'
      else
        # Still not ready or failed
        error_msg = status_response['error'] || "Status: #{status_response['status']}"
        @draft.update(metadata: @draft.metadata.merge({ 'error' => error_msg, 'last_check' => Time.current.to_i }))
        redirect_to draft_path(@draft), alert: "Video not ready yet. Status: #{status_response['status']}. Error: #{error_msg}"
      end
    rescue => e
      Rails.logger.error "[retry_video_status] Error: #{e.message}"
      redirect_to draft_path(@draft), alert: "Error checking status: #{e.message}"
    end
  end

  def download
    # Check if media is attached via ActiveStorage
    if @draft.media.attached?
      # Serve from ActiveStorage
      redirect_to rails_blob_path(@draft.media, disposition: "attachment")
    elsif @draft.media_url.present?
      # Fallback: redirect to the URL (may be expired)
      redirect_to @draft.media_url, allow_other_host: true
    else
      redirect_to draft_path(@draft), alert: 'No media available for download.'
    end
  end

  def bulk_actions
    draft_ids = params[:draft_ids] || []
    action = params[:bulk_action]
    
    case action
    when 'delete'
      current_user.draft_contents.where(id: draft_ids).destroy_all
      message = 'Selected drafts deleted successfully.'
    when 'publish'
      drafts = current_user.draft_contents.where(id: draft_ids)
      drafts.each do |draft|
        content = current_user.contents.build(
          title: draft.title,
          body: draft.content,
          content_type: draft.content_type,
          platform: draft.platform,
          status: 'published'
        )
        content.save if content.valid?
        draft.update(status: 'published') if content.persisted?
      end
      message = 'Selected drafts published successfully.'
    when 'archive'
      current_user.draft_contents.where(id: draft_ids).update_all(status: 'reviewing')
      message = 'Selected drafts archived successfully.'
    end
    
    redirect_to drafts_url, notice: message
  end

  def search
    query = params[:q]
    @drafts = current_user.draft_contents
      .where("title ILIKE ? OR content ILIKE ?", "%#{query}%", "%#{query}%")
      .order(updated_at: :desc)
    
    render partial: 'drafts/draft_results'
  end

  private

  def set_draft
    @draft = current_user.draft_contents.find(params[:id])
  end

  def draft_params
    params.require(:draft_content).permit(:title, :content, :content_type, :platform, :status, :tags)
  end

  def generate_suggestions(draft)
    # Create AI content suggestions based on draft
    suggestions = [
      {
        topic: 'Improve engagement',
        suggestion: 'Consider adding a question at the end to encourage comments.',
        confidence: 0.85,
        content_type: draft.content_type,
        status: 'pending'
      },
      {
        topic: 'Optimize for platform',
        suggestion: "For #{draft.platform}, try using more visual elements and hashtags.",
        confidence: 0.78,
        content_type: draft.content_type,
        status: 'pending'
      },
      {
        topic: 'Timing optimization',
        suggestion: 'Schedule this content during peak engagement hours for your audience.',
        confidence: 0.72,
        content_type: draft.content_type,
        status: 'pending'
      }
    ]

    suggestions.each do |suggestion|
      draft.content_suggestions.create(suggestion)
    end
  end

  def regenerate_suggestions(draft)
    # Clear existing pending suggestions
    draft.content_suggestions.where(status: 'pending').destroy_all
    
    # Generate new suggestions based on updated content
    generate_suggestions(draft)
  end
end