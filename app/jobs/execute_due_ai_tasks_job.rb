# frozen_string_literal: true

# Job to execute scheduled AI tasks that are due
class ExecuteDueAiTasksJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "[ExecuteDueAiTasksJob] Checking for due AI tasks"

    # Find all active tasks that are due
    due_tasks = ScheduledAiTask.active.where('next_run_at <= ?', Time.current)

    Rails.logger.info "[ExecuteDueAiTasksJob] Found #{due_tasks.count} tasks due for execution"

    due_tasks.find_each do |task|
      begin
        execute_task(task)
      rescue => e
        Rails.logger.error "[ExecuteDueAiTasksJob] Failed to execute task #{task.id}: #{e.message}"
      end
    end
  end

  private

  def execute_task(task)
    service = ScheduledAiTasksService.new(task.user)
    result = service.execute_task(task)

    if result[:success]
      Rails.logger.info "[ExecuteDueAiTasksJob] Successfully executed task #{task.id}: #{result[:action]}"
      
      # Schedule next run if recurring
      if task.recurring?
        next_run = service.calculate_next_execution(task)
        task.update!(next_run_at: next_run, last_run_at: Time.current)
      else
        task.update!(status: 'inactive', last_run_at: Time.current)
      end
    else
      Rails.logger.warn "[ExecuteDueAiTasksJob] Failed to execute task #{task.id}: #{result[:error]}"
      task.update!(last_run_at: Time.current, last_error: result[:error])
    end
  end
end
