class DraftsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_draft, only: %i[show edit update destroy convert_to_content duplicate]

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