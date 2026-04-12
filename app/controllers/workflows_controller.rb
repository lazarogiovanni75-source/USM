class WorkflowsController < ApplicationController
  before_action :authenticate_user!

  def index
    @workflows = current_user.workflows.order(created_at: :desc)
  end

  def new
    @workflow = Workflow.new
  end

  def create
    @workflow = current_user.workflows.new(workflow_params)

    if @workflow.save
      WorkflowExecutionJob.perform_later(@workflow.id)
      redirect_to workflow_path(@workflow), notice: 'Workflow created successfully!'
    else
      flash[:alert] = @workflow.errors.full_messages.join(', ')
      render :new
    end
  end

  def show
    @workflow = current_user.workflows.find(params[:id])
  end

  def destroy
    @workflow = current_user.workflows.find(params[:id])
    @workflow.destroy
    redirect_to workflows_path, notice: 'Workflow deleted.'
  end

  private

  def workflow_params
    params.require(:workflow).permit(:workflow_type, :content)
  end
end
