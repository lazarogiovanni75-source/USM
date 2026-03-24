# frozen_string_literal: true

class ExecuteTaskJob < ApplicationJob
  queue_as :default

  # Exponential backoff: 5s, 15s, 45s (5 * 3^attempt)
  retry_on StandardError, wait: ->(executions) { 5 * (3**executions) }, attempts: 3

  def perform(task_id)
    task = CampaignTask.find(task_id)
    return unless task.pending?

    task.mark_running!

    begin
      # Execute tool using ToolExecutor
      result = Ai::ToolExecutor.call(
        task.tool_name,
        task.parameters,
        user: task.campaign.user,
        campaign: task.campaign
      )

      task.mark_done!(result.to_json)

      # Continue campaign after task completes - this is where autonomy happens
      Rails.logger.info "[ExecuteTaskJob] Task completed, continuing campaign..."
      Ai::Orchestrator.continue_campaign(task.campaign)

    rescue => e
      Rails.logger.error "[ExecuteTaskJob] Task #{task.id} failed: #{e.message}"

      if task.can_retry?
        # Task will be retried automatically by retry_on
        # Just update the last_error for visibility
        task.update!(last_error: e.message)
        raise # Re-raise to trigger retry
      else
        # Max retries exceeded - mark as permanently failed
        task.mark_failed!("Max retries exceeded: #{e.message}")

        # Increment campaign failure counter
        task.campaign.increment!(:failure_count)

        # Check failure rate and pause campaign if too high
        if Ai::Orchestrator.check_failure_rate?(task.campaign)
          Rails.logger.warn "[ExecuteTaskJob] Campaign #{task.campaign.id} paused due to high failure rate"
          task.campaign.mark_paused!
        end

        # Still try to continue campaign after failure
        begin
          Ai::Orchestrator.continue_campaign(task.campaign)
        rescue => cont_error
          Rails.logger.error "[ExecuteTaskJob] Continue campaign failed: #{cont_error.message}"
        end
      end
    end
  end
end
