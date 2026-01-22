class DashboardsController < ApplicationController
  before_action :authenticate_user!

  def index
    @user = current_user
    @campaigns = @user.campaigns.order(created_at: :desc).limit(5)
    @contents = @user.contents.order(created_at: :desc).limit(10)
    @scheduled_posts = @user.scheduled_posts.order(scheduled_time: :asc).limit(10)
    @voice_commands = @user.voice_commands.order(created_at: :desc).limit(5)
    
    # Calculate some basic statistics
    @total_campaigns = @user.campaigns.count
    @total_contents = @user.contents.count
    @scheduled_posts_count = @user.scheduled_posts.count
    @engagement_rate = rand(2.5..8.5).round(2) # Placeholder for actual calculation
  end

  private
  # Write your private methods here
end
