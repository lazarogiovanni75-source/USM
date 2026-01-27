class AutomationRulesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_rule, only: [:show, :edit, :update, :destroy, :toggle_status]
  
  def index
    @automation_service = AutomationRulesService.new(current_user)
    @rules = current_user.automation_rules.order(created_at: :desc)
    @rule_templates = @automation_service.get_rule_templates
    @statistics = @automation_service.get_rule_statistics
  end

  def show
    @automation_service = AutomationRulesService.new(current_user)
    @executions = @rule.rule_executions.order(created_at: :desc).limit(50)
    @statistics = @automation_service.get_rule_statistics
  end

  def new
    @automation_service = AutomationRulesService.new(current_user)
    @rule_templates = @automation_service.get_rule_templates
    @rule = AutomationRule.new
  end

  def create
    @automation_service = AutomationRulesService.new(current_user)
    @rule = @automation_service.create_rule(rule_params)
    
    if @rule.persisted? && @rule.valid?
      redirect_to @rule, notice: 'Automation rule was successfully created.'
    else
      @rule_templates = @automation_service.get_rule_templates
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @automation_service = AutomationRulesService.new(current_user)
    @rule_templates = @automation_service.get_rule_templates
  end

  def update
    if @rule.update(rule_params)
      redirect_to @rule, notice: 'Automation rule was successfully updated.'
    else
      @automation_service = AutomationRulesService.new(current_user)
      @rule_templates = @automation_service.get_rule_templates
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @rule.destroy
    redirect_to automation_rules_url, notice: 'Automation rule was successfully deleted.'
  end

  def toggle_status
    new_status = @rule.active? ? 'inactive' : 'active'
    @rule.update(status: new_status)
    
    status_text = new_status == 'active' ? 'activated' : 'deactivated'
    redirect_to @rule, notice: "Automation rule was successfully #{status_text}."
  end

  def create_from_template
    template_id = params[:template_id]
    
    @automation_service = AutomationRulesService.new(current_user)
    template = @automation_service.get_rule_templates.find { |t| t[:id] == template_id }
    
    if template
      @rule = current_user.automation_rules.build(
        name: template[:name],
        description: template[:description],
        trigger_events: template[:trigger_events],
        action_type: template[:action_type],
        conditions: template[:conditions] || [],
        config: template[:config] || {},
        status: 'active'
      )
      
      if @rule.save
        redirect_to @rule, notice: 'Automation rule was created from template.'
      else
        redirect_to automation_rules_url, alert: 'Failed to create rule from template.'
      end
    else
      redirect_to automation_rules_url, alert: 'Template not found.'
    end
  end

  def test_rule
    @automation_service = AutomationRulesService.new(current_user)
    
    # Create test data
    test_data = {
      content: current_user.contents.first,
      engagement_rate: 5.5,
      platform: 'instagram'
    }
    
    result = @automation_service.execute_rule_action(@rule, test_data)
    
    if result[:success]
      redirect_to @rule, notice: "Rule test successful: #{result[:action]}"
    else
      redirect_to @rule, alert: "Rule test failed: #{result[:error]}"
    end
  end

  def export_rules
    rules = current_user.automation_rules
    
    respond_to do |format|
      format.csv do
        csv_data = generate_rules_csv(rules)
        send_data csv_data, filename: "automation_rules_#{Date.current}.csv"
      end
      format.json do
        render json: rules.as_json(include: [:rule_executions])
      end
    end
  end

  def bulk_actions
    rule_ids = params[:rule_ids] || []
    action = params[:bulk_action]
    
    case action
    when 'activate'
      current_user.automation_rules.where(id: rule_ids).update_all(status: 'active')
      message = "#{rule_ids.count} rules activated"
    when 'deactivate'
      current_user.automation_rules.where(id: rule_ids).update_all(status: 'inactive')
      message = "#{rule_ids.count} rules deactivated"
    when 'delete'
      current_user.automation_rules.where(id: rule_ids).destroy_all
      message = "#{rule_ids.count} rules deleted"
    end
    
    redirect_to automation_rules_url, notice: message
  end

  private

  def set_rule
    @rule = current_user.automation_rules.find(params[:id])
  end

  def rule_params
    params.require(:automation_rule).permit(
      :name, :description, :action_type, :status,
      trigger_events: [],
      conditions: [],
      config: {}
    )
  end

  def generate_rules_csv(rules)
    CSV.generate do |csv|
      csv << ['Name', 'Description', 'Action Type', 'Trigger Events', 'Status', 'Created At']
      
      rules.each do |rule|
        csv << [
          rule.name,
          rule.description,
          rule.action_type,
          rule.trigger_events.join(', '),
          rule.status,
          rule.created_at.strftime('%Y-%m-%d %H:%M')
        ]
      end
    end
  end
end