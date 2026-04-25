# Plan Limit Service - Enforces subscription plan limits
class PlanLimitService
  def initialize(user)
    @user = user
  end

  # Check if user can create a new campaign
  def can_create_campaign?
    current_count = campaigns_this_month
    current_count < @user.max_campaigns_per_month
  end

  # Check if user can schedule a new post
  def can_schedule_post?
    current_count = posts_this_month
    current_count < @user.max_posts_per_month
  end

  # Check if user can connect another platform (always true - unlimited)
  def can_connect_platform?
    true
  end

  # Check if campaign can generate more videos (always true - unlimited)
  def can_generate_video?(campaign)
    true
  end

  # Check if campaign can generate more images (always true - unlimited)
  def can_generate_image?(campaign)
    true
  end

  # Check storage limit
  def can_upload?(file_size_bytes)
    used_storage = calculate_storage_usage
    used_storage + file_size_bytes <= @user.storage_limit_gb.gigabytes
  end

  # Get current usage stats
  def usage_stats
    {
      campaigns_this_month: campaigns_this_month,
      max_campaigns: @user.max_campaigns_per_month,
      posts_this_month: posts_this_month,
      max_posts: @user.max_posts_per_month,
      platforms_connected: @user.social_accounts.count,
      max_platforms: @user.max_platforms,
      storage_used_gb: calculate_storage_usage.gigabytes,
      max_storage_gb: @user.storage_limit_gb
    }
  end

  # Return error message if limit exceeded, nil if ok
  def campaign_limit_error
    return nil if can_create_campaign?
    "You've reached your monthly campaign limit (#{@user.max_campaigns_per_month}). Upgrade to #{next_plan} for more."
  end

  def post_limit_error
    return nil if can_schedule_post?
    "You've reached your monthly post limit (#{@user.max_posts_per_month}). Upgrade to #{next_plan} for more."
  end

  def platform_limit_error
    # Platform limits removed - all users can connect all 9 platforms
    nil
  end

  def video_limit_error(campaign)
    # Videos in campaigns are unlimited and free
    nil
  end

  def image_limit_error(campaign)
    # Images in campaigns are unlimited and free
    nil
  end

  private

  def campaigns_this_month
    @user.campaigns.where('created_at >= ?', Time.current.beginning_of_month).count
  end

  def posts_this_month
    @user.scheduled_posts.where('scheduled_at >= ?', Time.current.beginning_of_month).count
  end

  def calculate_storage_usage
    # Sum up media file sizes from draft_contents and contents
    # This is a simplified calculation
    0 # TODO: Implement actual storage calculation based on ActiveStorage
  end

  def next_plan
    case @user.subscription_plan
    when 'Starter' then 'Entrepreneur'
    when 'Entrepreneur' then 'Pro'
    else nil
    end
  end
end
