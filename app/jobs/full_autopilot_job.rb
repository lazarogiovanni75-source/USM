# frozen_string_literal: true

class FullAutopilotJob < ApplicationJob
  queue_as :default

  def perform(user_id, campaign_id = nil)
    user = User.find(user_id)
    campaign = campaign_id ? user.campaigns.find(campaign_id) : nil
    
    Rails.logger.info "[FullAutopilotJob] Starting autopilot for user #{user_id}"
    
    autopilot = FullAutopilotService.new(user: user, campaign: campaign)
    results = autopilot.start
    
    Rails.logger.info "[FullAutopilotJob] Completed with results: #{results}"
    
    # Notify user of completion
    send_completion_notification(user, results)
    
  rescue => e
    Rails.logger.error "[FullAutopilotJob] Error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  private

  def send_completion_notification(user, results)
    message = "Autopilot completed!\n"
    message += "- Content created: #{results[:content_created] || 0}\n"
    message += "- Posts scheduled: #{results[:posts_scheduled] || 0}\n"
    
    Rails.logger.info "[FullAutopilotJob] Notifying user: #{message}"
    # Could send email, push notification, etc.
  end
end
