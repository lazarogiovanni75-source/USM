class ScheduledAiTasksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_task, only: [:show, :edit, :update, :destroy, :toggle_status, :execute_now, :pause_task, :resume_task]
  
  def index
    @scheduled_ai_service = ScheduledAiTasksService.new(current_user)
    @tasks = current_user.scheduled_ai_tasks.order(created_at: :desc)
    @task_templates = @scheduled_ai_service.get_task_templates
    @statistics = @scheduled_ai_service.get_task_statistics
    @due_tasks = @tasks.due.includes(:task_executions)
  end

  def show
    @scheduled_ai_service = ScheduledAiTasksService.new(current_user)
    @executions = @task.task_executions.recent.includes(:user).limit(20)
    @results = current_user.ai_task_results.by_task_type(@task.task_type).recent.limit(10)
    @statistics = @scheduled_ai_service.get_task_statistics
  end

  def new
    @scheduled_ai_service = ScheduledAiTasksService.new(current_user)
    @task_templates = @scheduled_ai_service.get_task_templates
    @task = ScheduledAiTask.new
  end

  def create
    @scheduled_ai_service = ScheduledAiTasksService.new(current_user)
    @task = @scheduled_ai_service.create_task(task_params)
    
    if @task.persisted? && @task.valid?
      redirect_to scheduled_ai_task_path(@task), notice: 'Scheduled AI task was successfully created.'
    else
      @task_templates = @scheduled_ai_service.get_task_templates
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @scheduled_ai_service = ScheduledAiTasksService.new(current_user)
    @task_templates = @scheduled_ai_service.get_task_templates
  end

  def update
    if @task.update(task_params)
      redirect_to scheduled_ai_task_path(@task), notice: 'Scheduled AI task was successfully updated.'
    else
      @scheduled_ai_service = ScheduledAiTasksService.new(current_user)
      @task_templates = @scheduled_ai_service.get_task_templates
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @task.destroy
    redirect_to scheduled_ai_tasks_url, notice: 'Scheduled AI task was successfully deleted.'
  end

  def toggle_status
    new_status = @task.active? ? 'inactive' : 'active'
    @task.update(status: new_status)
    
    status_text = new_status == 'active' ? 'activated' : 'deactivated'
    redirect_to scheduled_ai_task_path(@task), notice: "Scheduled AI task was successfully #{status_text}."
  end

  def execute_now
    @scheduled_ai_service = ScheduledAiTasksService.new(current_user)
    result = @scheduled_ai_service.execute_task(@task)
    
    if result[:success]
      redirect_to scheduled_ai_task_path(@task), notice: "Task executed successfully: #{result[:action]}"
    else
      redirect_to scheduled_ai_tasks_url, alert: "Task execution failed: #{result[:error]}"
    end
  end

  def pause_task
    @task.update(status: 'paused')
    redirect_to scheduled_ai_task_path(@task), notice: 'Scheduled AI task was paused.'
  end

  def resume_task
    @task.update(status: 'active')
    redirect_to scheduled_ai_task_path(@task), notice: 'Scheduled AI task was resumed.'
  end

  def create_from_template
    template_id = params[:template_id]
    
    @scheduled_ai_service = ScheduledAiTasksService.new(current_user)
    template = @scheduled_ai_service.get_task_templates.find { |t| t[:id] == template_id }
    
    if template
      @task = current_user.scheduled_ai_tasks.build(
        name: template[:name],
        description: template[:description],
        task_type: template[:task_type],
        schedule_type: template[:schedule_type],
        config: template[:config] || {},
        status: 'active',
        next_run_at: Time.current + 1.hour
      )
      
      if @task.save
        redirect_to scheduled_ai_task_path(@task), notice: 'Scheduled AI task was created from template.'
      else
        redirect_to scheduled_ai_tasks_url, alert: 'Failed to create task from template.'
      end
    else
      redirect_to scheduled_ai_tasks_url, alert: 'Template not found.'
    end
  end

  def execute_all_due
    @scheduled_ai_service = ScheduledAiTasksService.new(current_user)
    results = @scheduled_ai_service.execute_due_tasks
    
    successful = results.count { |r| r[:success] }
    failed = results.length - successful
    
    if successful > 0
      redirect_to scheduled_ai_tasks_url, notice: "Executed #{successful} tasks successfully. #{failed} failed."
    else
      redirect_to scheduled_ai_tasks_url, alert: "All task executions failed."
    end
  end

  def bulk_actions
    task_ids = params[:task_ids] || []
    action = params[:bulk_action]
    
    case action
    when 'activate'
      current_user.scheduled_ai_tasks.where(id: task_ids).update_all(status: 'active')
      message = "#{task_ids.count} tasks activated"
    when 'deactivate'
      current_user.scheduled_ai_tasks.where(id: task_ids).update_all(status: 'inactive')
      message = "#{task_ids.count} tasks deactivated"
    when 'pause'
      current_user.scheduled_ai_tasks.where(id: task_ids).update_all(status: 'paused')
      message = "#{task_ids.count} tasks paused"
    when 'delete'
      current_user.scheduled_ai_tasks.where(id: task_ids).destroy_all
      message = "#{task_ids.count} tasks deleted"
    when 'execute_now'
      @scheduled_ai_service = ScheduledAiTasksService.new(current_user)
      tasks = current_user.scheduled_ai_tasks.where(id: task_ids)
      results = tasks.map { |task| @scheduled_ai_service.execute_task(task) }
      successful = results.count { |r| r[:success] }
      message = "Executed #{successful} out of #{tasks.count} tasks"
    end
    
    redirect_to scheduled_ai_tasks_url, notice: message
  end

  def results
    @results = current_user.ai_task_results.recent.includes(:user)
    
    # Filter by task type if specified
    if params[:task_type]
      @results = @results.by_task_type(params[:task_type])
    end
  end

  private

  def set_task
    @task = current_user.scheduled_ai_tasks.find(params[:id])
  end

  def task_params
    params.require(:scheduled_ai_task).permit(
      :name, :description, :task_type, :schedule_type, :status, :next_run_at,
      config: {}
    )
  end
end