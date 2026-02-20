class ContentsController < ApplicationController
  before_action :set_content, only: %i[show edit update destroy approve reject duplicate generate_variation]
  before_action :authenticate_user!

  # GET /contents
  def index
    @contents = current_user.contents.includes(:campaign).order(created_at: :desc)
    @pending_contents = @contents.where(status: 'draft')
    @approved_contents = @contents.where(status: 'approved')
    @rejected_contents = @contents.where(status: 'rejected')
    
    # Also fetch drafts and suggestions for unified view
    @drafts = current_user.draft_contents.includes(:content_suggestions).order(updated_at: :desc)
    @suggestions = current_user.content_suggestions.pending.order(created_at: :desc)
  end

  # GET /contents/1
  def show
    @related_contents = current_user.contents.where(campaign_id: @content.campaign_id).where.not(id: @content.id).limit(5)
  end

  # GET /contents/new
  def new
    @content = Content.new
  end

  # GET /contents/1/edit
  def edit
  end

  # POST /contents
  def create
    @content = current_user.contents.build(content_params)

    if @content.save
      redirect_to content_path(@content), notice: 'Content was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /contents/1
  def update
    if @content.update(content_params)
      redirect_to content_path(@content), notice: 'Content was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /contents/1
  def destroy
    @content.destroy
    redirect_to contents_url, notice: 'Content was successfully deleted.'
  end

  # Approve content
  def approve
    if @content.update(status: 'approved', approved_at: Time.current)
      # Send approval notification
      ContentApprovalService.new(@content).notify_approval
      redirect_to content_path(@content), notice: 'Content has been approved and is ready for scheduling.'
    else
      redirect_to content_path(@content), alert: 'Failed to approve content.'
    end
  end

  # Reject content
  def reject
    if @content.update(status: 'rejected', rejected_at: Time.current)
      redirect_to content_path(@content), notice: 'Content has been rejected.'
    else
      redirect_to content_path(@content), alert: 'Failed to reject content.'
    end
  end

  # Duplicate content for editing
  def duplicate
    @new_content = @content.dup
    @new_content.title = "#{@content.title} (Copy)"
    @new_content.status = 'draft'
    
    if @new_content.save
      redirect_to edit_content_path(@new_content), notice: 'Content duplicated successfully. You can now edit it.'
    else
      redirect_to content_path(@content), alert: 'Failed to duplicate content.'
    end
  end

  # Generate content variation
  def generate_variation
    begin
      generated_content = AiAutopilotService.new(
        action: 'generate_content_variation',
        content: @content
      ).call
      
      if generated_content
        @new_content = current_user.contents.create!(
          title: "Variation of #{@content.title}",
          body: generated_content[:body],
          content_type: @content.content_type,
          platform: @content.platform,
          campaign_id: @content.campaign_id,
          status: 'draft'
        )
        redirect_to new_content_path(@new_content), notice: 'Content variation generated successfully.'
      else
        redirect_to content_path(@content), alert: 'Failed to generate content variation.'
      end
    rescue StandardError => e
      redirect_to content_path(@content), alert: "Error generating variation: #{e.message}"
    end
  end

  # Bulk approve selected content
  def bulk_approve
    content_ids = params[:content_ids]
    contents = current_user.contents.where(id: content_ids)
    
    updated_count = 0
    contents.each do |content|
      if content.update(status: 'approved', approved_at: Time.current)
        ContentApprovalService.new(content).notify_approval
        updated_count += 1
      end
    end
    
    redirect_to contents_path, notice: "Successfully approved #{updated_count} content items."
  end

  # Bulk reject selected content
  def bulk_reject
    content_ids = params[:content_ids]
    contents = current_user.contents.where(id: content_ids)
    
    updated_count = 0
    contents.each do |content|
      if content.update(status: 'rejected', rejected_at: Time.current)
        updated_count += 1
      end
    end
    
    redirect_to contents_path, notice: "Successfully rejected #{updated_count} content items."
  end

  # Preview content for different platforms
  def preview
    @platform = params[:platform] || @content.platform
    render 'preview'
  end

  # AI-powered content optimization suggestions
  def optimize
    begin
      optimization_suggestions = AiAutopilotService.new(
        action: 'optimize_content',
        content: @content
      ).call
      
      @suggestions = optimization_suggestions[:suggestions] || []
      @optimized_content = optimization_suggestions[:optimized_content]
    rescue StandardError => e
      @error = "Error generating optimization suggestions: #{e.message}"
    end
    
    render 'optimize'
  end

  # Apply optimization suggestions
  def apply_optimization
    optimized_body = params[:optimized_body]
    
    if @content.update(body: optimized_body)
      redirect_to content_path(@content), notice: 'Content has been optimized successfully.'
    else
      redirect_to content_path(@content), alert: 'Failed to apply optimization.'
    end
  end

  private
    def set_content
      @content = current_user.contents.find(params[:id])
    end

    def content_params
      params.require(:content).permit(:title, :body, :content_type, :platform, :status, :campaign_id)
    end
end