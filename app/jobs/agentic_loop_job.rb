# frozen_string_literal: true

# Agentic Loop Job - Triggers the autonomous AI agent every 5 minutes
# This job finds all active users and runs the agentic loop for each
class AgenticLoopJob < ApplicationJob
  queue_as :default

  # Run every 5 minutes via cron
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(max_budget_usd: 0.50)
    Rails.logger.info "[AgenticLoopJob] Starting agentic loop run, max_budget: $#{max_budget_usd}"

    # Find all active users who have enabled autonomous posting
    active_users.find_each do |user|
      next unless user.can_run_autonomous_workflows?
      next if user.subscription_plan.nil? # Skip users without subscription

      begin
        result = AgenticLoopService.new(
          user: user,
          max_budget_usd: max_budget_usd
        ).call

        log_result(user, result)
      rescue => e
        Rails.logger.error "[AgenticLoopJob] Error for user #{user.id}: #{e.message}"
        log_error(user, e)
      end
    end

    Rails.logger.info "[AgenticLoopJob] Completed agentic loop run"
  end

  private

  def active_users
    User.where.not(subscription_plan: nil)
      .where(role: %w[user premium admin moderator])
      .where.not(encrypted_password: nil)
  end

  def log_result(user, result)
    Rails.logger.info "[AgenticLoopJob] User #{user.id} - Posts: #{result[:posts_processed]}, Published: #{result[:posts_published]}, Cost: $#{'%.6f' % result[:total_cost]}"
  end

  def log_error(user, error)
    Rails.logger.error "[AgenticLoopJob] User #{user.id} failed: #{error.message}"
  end
end
