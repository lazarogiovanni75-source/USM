class ZapierWebhooksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_webhook, only: [:show, :edit, :update, :destroy, :test]
  
  def index
    @webhooks = current_user.zapier_webhooks.order(created_at: :desc)
    @zapier_service = ZapierIntegrationService.new(current_user)
    @workflow_templates = @zapier_service.get_workflow_templates
  end

  def show
  end

  def new
    @zapier_service = ZapierIntegrationService.new(current_user)
    @workflow_templates = @zapier_service.get_workflow_templates
    @webhook = ZapierWebhook.new
  end

  def create
    @webhook = current_user.zapier_webhooks.build(webhook_params)
    
    if @webhook.save
      redirect_to @webhook, notice: 'Webhook was successfully created.'
    else
      @zapier_service = ZapierIntegrationService.new(current_user)
      @workflow_templates = @zapier_service.get_workflow_templates
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @zapier_service = ZapierIntegrationService.new(current_user)
    @workflow_templates = @zapier_service.get_workflow_templates
  end

  def update
    if @webhook.update(webhook_params)
      redirect_to @webhook, notice: 'Webhook was successfully updated.'
    else
      @zapier_service = ZapierIntegrationService.new(current_user)
      @workflow_templates = @zapier_service.get_workflow_templates
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @webhook.destroy
    redirect_to zapier_webhooks_url, notice: 'Webhook was successfully deleted.'
  end

  def test
    @zapier_service = ZapierIntegrationService.new(current_user)
    
    # Test webhook with sample data
    test_data = {
      event: 'test',
      timestamp: Time.current,
      user_id: current_user.id,
      message: 'Test webhook payload'
    }
    
    result = @zapier_service.send_to_zapier(@webhook.webhook_url, test_data)
    
    if result[:success]
      redirect_to @webhook, notice: 'Webhook test successful!'
    else
      redirect_to @webhook, alert: "Webhook test failed: #{result[:error]}"
    end
  end

  # API endpoint for receiving webhooks
  def receive
    begin
      payload = JSON.parse(request.body.read)
      webhook_type = params[:type] || 'generic'
      
      zapier_service = ZapierIntegrationService.new
      result = zapier_service.handle_webhook(payload, webhook_type)
      
      render json: { success: true, result: result }
    rescue JSON::ParserError
      render json: { error: 'Invalid JSON payload' }, status: :bad_request
    rescue => e
      Rails.logger.error "Webhook processing failed: #{e.message}"
      render json: { error: 'Internal server error' }, status: :internal_server_error
    end
  end

  # Create workflow from template
  def create_from_template
    template_id = params[:template_id]
    user_config = params[:config] || {}
    
    zapier_service = ZapierIntegrationService.new(current_user)
    result = zapier_service.create_workflow_from_template(template_id, user_config)
    
    if result
      redirect_to zapier_webhooks_url, notice: 'Workflow created successfully!'
    else
      redirect_to zapier_webhooks_url, alert: 'Failed to create workflow from template.'
    end
  end

  private

  def set_webhook
    @webhook = current_user.zapier_webhooks.find(params[:id])
  end

  def webhook_params
    params.require(:zapier_webhook).permit(
      :name, :webhook_url, :event_type, :status, :config,
      :trigger_content_created, :trigger_post_published, 
      :trigger_engagement_received, :trigger_scheduled_post,
      :trigger_weekly_summary, :trigger_competitor_detected
    )
  end
  
  # Process trigger events from form
  def process_trigger_events
    trigger_events = []
    
    trigger_events << 'content_created' if params.dig(:zapier_webhook, :trigger_content_created)
    trigger_events << 'post_published' if params.dig(:zapier_webhook, :trigger_post_published)
    trigger_events << 'engagement_received' if params.dig(:zapier_webhook, :trigger_engagement_received)
    trigger_events << 'scheduled_post' if params.dig(:zapier_webhook, :trigger_scheduled_post)
    trigger_events << 'weekly_summary' if params.dig(:zapier_webhook, :trigger_weekly_summary)
    trigger_events << 'competitor_detected' if params.dig(:zapier_webhook, :trigger_competitor_detected)
    
    trigger_events
  end
  
  # Override create and update to handle trigger events
  def create
    @webhook = current_user.zapier_webhooks.build(webhook_params.merge(trigger_events: process_trigger_events))
    
    if @webhook.save
      redirect_to @webhook, notice: 'Webhook was successfully created.'
    else
      @zapier_service = ZapierIntegrationService.new(current_user)
      @workflow_templates = @zapier_service.get_workflow_templates
      render :new, status: :unprocessable_entity
    end
  end
  
  def update
    if @webhook.update(webhook_params.merge(trigger_events: process_trigger_events))
      redirect_to @webhook, notice: 'Webhook was successfully updated.'
    else
      @zapier_service = ZapierIntegrationService.new(current_user)
      @workflow_templates = @zapier_service.get_workflow_templates
      render :edit, status: :unprocessable_entity
    end
  end
end