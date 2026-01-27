class ContentTemplatesController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @templates = if params[:user_id].present?
      ContentTemplate.user_templates(current_user.id)
    else
      ContentTemplate.public_templates
    end
    
    # Apply filters
    @templates = @templates.for_platform(params[:platform]) if params[:platform].present?
    @templates = @templates.by_type(params[:type]) if params[:type].present?
    @templates = @templates.by_category(params[:category]) if params[:category].present?
    @templates = @templates.search(params[:search]) if params[:search].present?
    
    @templates = @templates.page(params[:page]).per(12)
    
    # Get template categories and types for filter options
    @categories = ContentTemplate.categories.keys
    @types = ContentTemplate.template_types.keys
    @platforms = ContentTemplate.platforms.keys
  end
  
  def show
    @template = ContentTemplate.includes(:content_template_variables).find(params[:id])
    @processed_content = @template.process_variables({})
  end
  
  def new
    @template = ContentTemplate.new
    @template.content_template_variables.build
  end
  
  def create
    @template = current_user.content_templates.build(template_params)
    
    if @template.save
      redirect_to @template, notice: 'Template created successfully'
    else
      render :new
    end
  end
  
  def edit
    @template = current_user.content_templates.find(params[:id])
  end
  
  def update
    @template = current_user.content_templates.find(params[:id])
    
    if @template.update(template_params)
      redirect_to @template, notice: 'Template updated successfully'
    else
      render :edit
    end
  end
  
  def destroy
    @template = current_user.content_templates.find(params[:id])
    @template.destroy
    
    redirect_to content_templates_path, notice: 'Template deleted successfully'
  end
  
  def duplicate
    original_template = ContentTemplate.find(params[:id])
    
    if original_template.user_id.nil? || original_template.user_id == current_user.id
      @new_template = original_template.duplicate_for_user(current_user)
      
      if @new_template.persisted?
        redirect_to @new_template, notice: 'Template duplicated successfully'
      else
        redirect_to content_templates_path, alert: 'Failed to duplicate template'
      end
    else
      redirect_to content_templates_path, alert: 'You can only duplicate your own templates'
    end
  end
  
  def process
    @template = ContentTemplate.find(params[:id])
    
    variables = params[:variables] || {}
    processed_content = @template.process_variables(variables)
    
    # Increment usage count
    @template.increment_usage
    
    respond_to do |format|
      format.html { redirect_to @template }
      format.json { render json: { content: processed_content } }
    end
  end
  
  def preview
    @template = ContentTemplate.find(params[:id])
    
    variables = params[:variables] || {}
    processed_content = @template.process_variables(variables)
    
    render json: { content: processed_content }
  end
  
  def search
    query = params[:query]
    platform = params[:platform]
    category = params[:category]
    
    templates = ContentTemplate.public_templates
    
    templates = templates.search(query) if query.present?
    templates = templates.for_platform(platform) if platform.present?
    templates = templates.by_category(category) if category.present?
    
    render json: templates.limit(10).pluck(:id, :name, :description, :category, :platform)
  end
  
  def popular
    @templates = ContentTemplate.popular.limit(20)
    
    render json: @templates
  end
  
  def categories
    categories = ContentTemplate.categories.map do |key, value|
      { id: key, name: key.humanize, count: ContentTemplate.by_category(key).count }
    end
    
    render json: categories
  end
  
  private
  
  def template_params
    params.require(:content_template).permit(
      :name, :description, :template_content, :template_type, :category, 
      :platform, :is_featured, :user_id,
      content_template_variables_attributes: [
        :id, :variable_name, :variable_type, :default_value, 
        :placeholder_text, :validation_rules, :_destroy
      ]
    )
  end
end