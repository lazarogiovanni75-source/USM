class PromptTemplatesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_template, only: [:show, :edit, :update, :destroy, :duplicate, :use_template]
  before_action :authorize_template_access, only: [:show, :edit, :update, :destroy, :duplicate]
  
  # GET /prompt_templates
  def index
    @templates = PromptTemplate.accessible_to(current_user)
      .active_templates
      .order(usage_count: :desc, created_at: :desc)
      .includes(:user)
    
    @categories = PromptTemplate.categories_with_counts
    @featured_templates = PromptTemplate.featured_for_display
    
    # Search and filter
    @search_query = params[:search]
    @selected_category = params[:category]
    
    if @search_query.present?
      @templates = @templates.search(@search_query)
    end
    
    if @selected_category.present?
      @templates = @templates.by_category(@selected_category)
    end
  end
  
  # GET /prompt_templates/new
  def new
    @template = PromptTemplate.new
  end
  
  # POST /prompt_templates
  def create
    @template = PromptTemplate.new(template_params)
    @template.user_id = current_user.id
    
    if @template.save
      redirect_to prompt_templates_path, notice: 'Template created successfully!'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  # GET /prompt_templates/:id
  def show
    # Track usage
    @template.increment_usage
  end
  
  # GET /prompt_templates/:id/edit
  def edit
    # Only allow editing if user owns the template
    unless @template.can_be_edited_by?(current_user)
      redirect_to prompt_templates_path, alert: 'You can only edit your own templates.'
      return
    end
  end
  
  # PATCH/PUT /prompt_templates/:id
  def update
    if @template.update(template_params)
      redirect_to prompt_template_path(@template), notice: 'Template updated successfully!'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  # DELETE /prompt_templates/:id
  def destroy
    if @template.can_be_deleted_by?(current_user)
      @template.destroy
      redirect_to prompt_templates_path, notice: 'Template deleted successfully!'
    else
      redirect_to prompt_templates_path, alert: 'You can only delete your own templates.'
    end
  end
  
  # POST /prompt_templates/:id/duplicate
  def duplicate
    duplicated_template = @template.duplicate_for_user(current_user)
    redirect_to edit_prompt_template_path(duplicated_template), 
                notice: 'Template duplicated! You can now customize it.'
  end
  
  # POST /prompt_templates/:id/use
  def use_template
    @template.increment_usage
    
    # Process the template with any provided variables
    variables = params[:variables] || {}
    
    begin
      processed_prompt = @template.process_template(variables)
      
      # Create a new AI conversation with the processed prompt
      conversation = current_user.ai_conversations.create!(
        title: "Using: #{@template.name}",
        session_type: 'template',
        metadata: {
          template_id: @template.id,
          template_name: @template.name,
          original_variables: variables
        }
      )
      
      # Add the processed prompt as the first message
      conversation.ai_messages.create!(
        role: 'user',
        content: processed_prompt,
        message_type: 'text',
        metadata: {
          template_used: @template.name,
          variables_provided: variables
        }
      )
      
      redirect_to dashboard_path, 
                  notice: "Template '#{@template.name}' processed successfully!"
      
    rescue => e
      Rails.logger.error "Template processing error: #{e.message}"
      redirect_to prompt_template_path(@template), 
                  alert: 'Error processing template. Please check your variables.'
    end
  end
  
  def categories
    @categories = PromptTemplate.categories_with_counts
  end
  
  # GET /prompt_templates/popular
  def popular
    @templates = PromptTemplate.popular_templates(20)
    render :index
  end
  
  # GET /prompt_templates/my_templates
  def my_templates
    @templates = current_user.prompt_templates
      .active_templates
      .order(usage_count: :desc, created_at: :desc)
    
    @search_query = params[:search]
    
    if @search_query.present?
      @templates = @templates.search(@search_query)
    end
    
    render :index
  end
  
  def rate
    @template = PromptTemplate.accessible_to(current_user).find(params[:id])
    rating = params[:rating].to_i
    
    if rating.between?(1, 5)
      @template.rate_template(rating)
      flash[:notice] = 'Rating saved'
    else
      flash[:alert] = 'Invalid rating'
    end
    redirect_to prompt_template_path(@template)
  end
  
  # GET /prompt_templates/export/:id
  def export
    @template = PromptTemplate.accessible_to(current_user).find(params[:id])
    
    template_data = @template.export_to_hash
    
    json_data = template_data.to_json
    send_data json_data, filename: "template_#{@template.id}_#{Date.current}.json"
  end
  
  # POST /prompt_templates/import
  def import
    file = params[:file]
    
    if file.blank?
      redirect_to prompt_templates_path, alert: 'Please select a file to import.'
      return
    end
    
    begin
      if file.content_type == 'application/json'
        template_data = JSON.parse(file.read)
      else
        template_data = YAML.load(file.read)
      end
      
      imported_template = PromptTemplate.import_from_hash(template_data, current_user)
      
      redirect_to prompt_template_path(imported_template), 
                  notice: 'Template imported successfully!'
                  
    rescue JSON::ParserError
      redirect_to prompt_templates_path, alert: 'Invalid JSON file format.'
    rescue => e
      redirect_to prompt_templates_path, alert: "Import failed: #{e.message}"
    end
  end
  
  # GET /prompt_templates/:id/preview
  def preview
    @template = PromptTemplate.accessible_to(current_user).find(params[:id])
    
    variables = params[:variables] || {}
    missing_vars = @template.missing_variables(variables)
    
    @preview_prompt = if missing_vars.any?
                      @template.process_template(variables) + "\n\n[Note: Missing variables: #{missing_vars.join(', ')}]"
                    else
                      @template.process_template(variables)
                    end
    
    @missing_variables = missing_vars
    @all_variables = @template.extract_variables
  end
  
  private
  
  def set_template
    @template = PromptTemplate.find(params[:id])
  end
  
  def authorize_template_access
    unless @template.can_be_viewed_by?(current_user)
      redirect_to prompt_templates_path, alert: 'Template not found or access denied.'
    end
  end
  
  def template_params
    params.require(:prompt_template).permit(
      :name,
      :description,
      :category,
      :prompt,
      :is_public,
      :is_featured,
      :is_active,
      tags: []
    )
  end
end