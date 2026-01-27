class AutoResponseTriggersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_trigger, only: [:show, :edit, :update, :destroy, :toggle_status, :test_trigger]
  
  def index
    @auto_response_service = AutoResponseTriggersService.new(current_user)
    @triggers = current_user.auto_response_triggers.order(created_at: :desc)
    @trigger_templates = @auto_response_service.get_trigger_templates
    @statistics = @auto_response_service.get_trigger_statistics
  end

  def show
    @auto_response_service = AutoResponseTriggersService.new(current_user)
    @executions = @trigger.trigger_executions.order(created_at: :desc).limit(50)
    @statistics = @auto_response_service.get_trigger_statistics
  end

  def new
    @auto_response_service = AutoResponseTriggersService.new(current_user)
    @trigger_templates = @auto_response_service.get_trigger_templates
    @trigger = AutoResponseTrigger.new
  end

  def create
    @auto_response_service = AutoResponseTriggersService.new(current_user)
    @trigger = @auto_response_service.create_trigger(trigger_params)
    
    if @trigger.persisted? && @trigger.valid?
      redirect_to auto_response_trigger_path(@trigger), notice: 'Auto-response trigger was successfully created.'
    else
      @trigger_templates = @auto_response_service.get_trigger_templates
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @auto_response_service = AutoResponseTriggersService.new(current_user)
    @trigger_templates = @auto_response_service.get_trigger_templates
  end

  def update
    if @trigger.update(trigger_params)
      redirect_to auto_response_trigger_path(@trigger), notice: 'Auto-response trigger was successfully updated.'
    else
      @auto_response_service = AutoResponseTriggersService.new(current_user)
      @trigger_templates = @auto_response_service.get_trigger_templates
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @trigger.destroy
    redirect_to auto_response_triggers_url, notice: 'Auto-response trigger was successfully deleted.'
  end

  def toggle_status
    new_status = @trigger.active? ? 'inactive' : 'active'
    @trigger.update(status: new_status)
    
    status_text = new_status == 'active' ? 'activated' : 'deactivated'
    redirect_to auto_response_trigger_path(@trigger), notice: "Auto-response trigger was successfully #{status_text}."
  end

  def test_trigger
    @auto_response_service = AutoResponseTriggersService.new(current_user)
    
    # Create test engagement data
    test_data = {
      content: current_user.contents.first,
      engagement_rate: 7.5,
      engagement_score: 15,
      platform: 'instagram',
      engagement_type: 'comment_received',
      engaging_user_name: 'Test User'
    }
    
    result = @auto_response_service.execute_trigger_response(@trigger, test_data)
    
    if result[:success]
      redirect_to auto_response_trigger_path(@trigger), notice: "Trigger test successful: #{result[:action]}"
    else
      redirect_to auto_response_triggers_url, alert: "Trigger test failed: #{result[:error]}"
    end
  end

  private

  def set_trigger
    @trigger = current_user.auto_response_triggers.find(params[:id])
  end

  def trigger_params
    params.require(:auto_response_trigger).permit(
      :name, :description, :trigger_type, :response_type, :status,
      conditions: [],
      config: {}
    )
  end
end