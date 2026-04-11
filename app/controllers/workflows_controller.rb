# frozen_string_literal: true

class WorkflowsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_workflow, only: [:show, :destroy]

  def index
    @workflows = current_user.workflows.order(created_at: :desc)
  end

  def show
  end

  def run
    @workflow = current_user.workflows.find(params[:id])
    WorkflowService.execute_workflow(@workflow.id)
    redirect_to workflow_path(@workflow), notice: 'Workflow started!'
  rescue => e
    redirect_to workflow_path(@workflow), alert: "Error: #{e.message}"
  end

  def new
    @workflow = current_user.workflows.build
  end

  def create
    # Handle both JSON API and form submissions - extract raw data first
    workflow_data = params[:workflow]
    
    # Extract params from different possible structures
    raw_params = nil
    if workflow_data.present?
      raw_params = workflow_data['params'] || workflow_data[:params]
    end
    raw_params ||= params[:params]
    
    # Validate content_text is provided
    unless raw_params.present?
      flash[:alert] = 'Please provide content parameters (params: {content_text: "..."}).'
      render :new and return
    end
    
    # Parse the nested params - handle ActionController::Parameters, String, and Hash
    parsed = case raw_params.class.name
    when 'ActionController::Parameters'
      raw_params.permit!.to_h.with_indifferent_access
    when 'Hash'
      raw_params.with_indifferent_access
    when 'String'
      begin
        JSON.parse(raw_params).with_indifferent_access
      rescue JSON::ParserError
        # Treat plain strings as content_text directly
        { content_text: raw_params }
      end
    else
      raw_params.to_h.with_indifferent_access rescue {}
    end
    
    unless parsed[:content_text].present?
      flash[:alert] = 'Please provide a "content_text" key with your content.'
      render :new and return
    end
    
    # Extract workflow_type - check both nested (form_with model) and top-level params
    workflow_type = workflow_data ? (workflow_data['workflow_type'] || workflow_data[:workflow_type]) : nil
    workflow_type ||= params[:workflow_type]
    title = workflow_data ? (workflow_data['title'] || workflow_data[:title] || 'Untitled Workflow') : 'Untitled Workflow'
    
    @workflow = current_user.workflows.new(
      title: title,
      workflow_type: workflow_type,
      status: 'pending'
    )
    @workflow.params = parsed

    if @workflow.save
      WorkflowExecutionJob.perform_later(@workflow.id)
      redirect_to workflows_path, notice: 'Workflow started successfully!'
    else
      flash[:alert] = "Failed: #{@workflow.errors.full_messages.join(', ')}"
      render :new
    end
  end

  def destroy
    @workflow.destroy
    redirect_to workflows_path, notice: 'Workflow deleted.'
  end

  private

  def set_workflow
    @workflow = current_user.workflows.find(params[:id])
  end
end
