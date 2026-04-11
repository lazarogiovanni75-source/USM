# frozen_string_literal: true

class WorkflowsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_workflow, only: [:show, :destroy]

  def index
    @workflows = current_user.workflows.order(created_at: :desc)
    @social_accounts = current_user.social_accounts
  end

  def show
    @social_accounts = current_user.social_accounts
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
    @social_accounts = current_user.social_accounts
  end

  def create
    # Extract params from simple form fields
    workflow_type = params[:workflow_type]
    content_text = params[:content_text]
    social_account_id = params[:social_account_id]
    post_now = params[:post_now] == "1"
    scheduled_at = params[:scheduled_at]

    # Validate required fields
    unless content_text.present?
      flash[:alert] = "Please enter content for your workflow."
      @social_accounts = current_user.social_accounts
      render :new and return
    end

    unless workflow_type.present?
      flash[:alert] = "Please select a workflow type."
      @social_accounts = current_user.social_accounts
      render :new and return
    end

    # Build params hash for the workflow
    workflow_params = {
      content_text: content_text,
      social_account_id: social_account_id.presence,
      post_now: post_now,
      scheduled_at: scheduled_at.presence
    }.compact

    @workflow = current_user.workflows.new(
      title: content_text.truncate(50),
      workflow_type: workflow_type,
      status: 'pending'
    )
    @workflow.params = workflow_params

    if @workflow.save
      WorkflowExecutionJob.perform_later(@workflow.id)
      redirect_to workflows_path, notice: 'Workflow started successfully!'
    else
      flash[:alert] = "Failed: #{@workflow.errors.full_messages.join(', ')}"
      @social_accounts = current_user.social_accounts
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
