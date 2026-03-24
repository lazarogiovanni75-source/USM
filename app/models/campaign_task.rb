class CampaignTask < ApplicationRecord
  belongs_to :campaign

  enum status: {
    pending: 0,
    running: 1,
    done: 2,
    failed: 3
  }

  MAX_RETRIES = 3

  after_update_commit :check_campaign_completion
  
  def mark_running!
    update!(status: :running, started_at: Time.current)
  end
  
  def mark_done!(result = nil)
    update!(status: :done, completed_at: Time.current, result: result)
  end
  
  def mark_failed!(error = nil)
    update!(status: :failed, last_error: error)
    increment!(:retry_count)
  end

  def can_retry?
    retry_count.to_i < MAX_RETRIES
  end
  
  private
  
  def check_campaign_completion
    return unless saved_change_to_status?
    return unless done? || failed?
    
    # Check if all campaign tasks are done or failed
    if campaign.tasks.where.not(status: [:done, :failed]).none?
      if campaign.tasks.where(status: :failed).any?
        campaign.fail!
      else
        campaign.mark_completed!
      end
    end
  end
end
