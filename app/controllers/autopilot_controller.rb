# frozen_string_literal: true

class AutopilotController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @campaigns = current_user.campaigns.order(created_at: :desc)
    @recent_runs = get_recent_autopilot_runs
    @stats = get_autopilot_stats
  end
  
  def start
    campaign_id = params[:campaign_id]
    campaign = campaign_id.present? ? current_user.campaigns.find(campaign_id) : nil
    
    # Start autopilot in background
    FullAutopilotJob.perform_later(current_user.id, campaign_id)
    
    redirect_to autopilot_index_path, notice: 'Autopilot started! Check back for results.'
  end
  
  def status
    run_id = params[:run_id]
    status_data = get_run_status(run_id)
    @status_data = status_data
  end
  
  def stop
    run_id = params[:run_id]
    stop_autopilot_run(run_id)
    
    redirect_to autopilot_index_path, notice: 'Autopilot stopped.'
  end

  private

  def get_recent_autopilot_runs
    # Get recent scheduled posts created by autopilot
    current_user.scheduled_posts
               .where('scheduled_at > ?', 7.days.ago)
               .order(scheduled_at: :desc)
               .limit(20)
  end

  def get_autopilot_stats
    {
      total_posts: current_user.scheduled_posts.count,
      scheduled_this_week: current_user.scheduled_posts.where('scheduled_at > ?', 1.week.ago).count,
      published_this_week: current_user.scheduled_posts.where(status: 'published').where('posted_at > ?', 1.week.ago).count,
      active_campaigns: current_user.campaigns.count
    }
  end

  def get_run_status(run_id)
    # In a real implementation, this would query the autopilot run status
    { run_id: run_id, status: 'running', progress: 50 }
  end

  def stop_autopilot_run(run_id)
    # Cancel the autopilot job if running
    Rails.logger.info "[Autopilot] Stopping run #{run_id}"
  end
end
