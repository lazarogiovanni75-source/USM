class Api::V1::WorkflowsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_default_headers

  # Create and execute a workflow
  def create
    workflow_type = params[:workflow_type]
    content_text = params[:content_text]
    generate_image = params[:generate_image] == true || params[:generate_image] == 'true'
    generate_video = params[:generate_video] == true || params[:generate_video] == 'true'
    post_now = params[:post_now] == true || params[:post_now] == 'true'
    social_account_id = params[:social_account_id]
    scheduled_at = params[:scheduled_at]

    if content_text.blank?
      render json: { error: 'Content text is required' }, status: :bad_request
      return
    end

    begin
      result = WorkflowService.create_content_with_media(
        user: current_user,
        content_text: content_text,
        generate_image: generate_image,
        generate_video: generate_video,
        post_now: post_now,
        social_account_id: social_account_id,
        scheduled_at: scheduled_at
      )

      response = {
        success: true,
        content_id: result[:content].id,
        media_url: result[:media_url],
        media_type: result[:media_type],
        scheduled_post_id: result[:scheduled_post]&.id,
        message: build_response_message(result)
      }

      render json: response
    rescue => e
      Rails.logger.error "Workflow error: #{e.message}"
      render json: { error: e.message }, status: :internal_server_error
    end
  end

  # List user's workflows
  def index
    workflows = current_user.workflows.order(created_at: :desc).limit(20)
    
    render json: {
      workflows: workflows.map { |w| {
        id: w.id,
        workflow_type: w.workflow_type,
        status: w.status,
        created_at: w.created_at,
        steps: w.workflow_steps.map { |s| {
          step_type: s.step_type,
          status: s.status,
          output: s.output
        }}
      }}
    }
  end

  # Get workflow status
  def show
    workflow = current_user.workflows.find_by(id: params[:id])
    
    unless workflow
      render json: { error: 'Workflow not found' }, status: :not_found
      return
    end

    render json: {
      id: workflow.id,
      workflow_type: workflow.workflow_type,
      status: workflow.status,
      params: workflow.params,
      steps: workflow.workflow_steps.order(:order).map { |s| {
        step_type: s.step_type,
        status: s.status,
        output: s.output
      }}
    }
  end

  private

  def build_response_message(result)
    post = result[:scheduled_post]
    media_type = result[:media_type]
    
    if post
      if post.published?
        "Your #{media_type || 'content'} has been published!"
      else
        "Your #{media_type || 'content'} has been scheduled for #{post.scheduled_at.strftime('%B %d at %I:%M %p')}!"
      end
    else
      "Your content has been created! Connect a social account to post it."
    end
  end
end
