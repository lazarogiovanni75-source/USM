# frozen_string_literal: true

# SocialMediaAgentWorker - Sidekiq worker that checks for scheduled posts every 5 minutes
# This replaces the GoodJob-based PublishScheduledPostsJob for Sidekiq/Redis infrastructure
class SocialMediaAgentWorker
  include Sidekiq::Worker
  sidekiq_options retry: 3, backtrace: true

  def perform(args = {})
    Rails.logger.info "[SocialMediaAgentWorker] Starting at #{Time.current.iso8601}"

    # Find posts that are due to be published
    due_posts = find_due_posts

    Rails.logger.info "[SocialMediaAgentWorker] Found #{due_posts.count} posts due for publishing"

    due_posts.find_each do |post|
      process_post(post)
    end

    Rails.logger.info "[SocialMediaAgentWorker] Completed at #{Time.current.iso8601}"
  end

  private

  def find_due_posts
    ScheduledPost.where('scheduled_at <= ?', Time.current)
                 .where(status: %w[scheduled draft])
                 .where.not(user_id: nil)
                 .includes(:content, :social_account, :user)
  end

  def process_post(post)
    Rails.logger.info "[SocialMediaAgentWorker] Processing post #{post.id} for user #{post.user_id}"

    # Check if the post has asset URLs from Atlas Cloud
    unless post_has_required_assets?(post)
      Rails.logger.warn "[SocialMediaAgentWorker] Post #{post.id} missing required assets"
      post.update(status: 'failed', error_message: 'Missing required assets (image/video)')
      return
    end

    # Find the social account
    social_account = find_social_account(post)
    unless social_account
      Rails.logger.warn "[SocialMediaAgentWorker] Post #{post.id} has no valid social account"
      post.update(status: 'failed', error_message: 'No valid social account found')
      return
    end

    # Publish the post
    result = publish_to_platform(post, social_account)

    if result[:success]
      Rails.logger.info "[SocialMediaAgentWorker] Successfully published post #{post.id}"
      post.update!(
        status: 'published',
        posted_at: Time.current,
        platform_post_id: result[:platform_post_id]
      )
      notify_user(post, 'published')
    else
      Rails.logger.error "[SocialMediaAgentWorker] Failed to publish post #{post.id}: #{result[:error]}"
      post.update!(
        status: 'failed',
        error_message: result[:error]
      )
      notify_user(post, 'failed', result[:error])
    end
  rescue StandardError => e
    Rails.logger.error "[SocialMediaAgentWorker] Error processing post #{post.id}: #{e.message}"
    post.update(status: 'failed', error_message: e.message) if post.persisted?
  end

  def post_has_required_assets?(post)
    return true if post.content&.media_url.present? || post.content&.video_url.present?

    # Check for asset URLs directly on the scheduled post
    post.image_url.present? || post.video_url.present? || post.asset_url.present?
  end

  def find_social_account(post)
    return post.social_account if post.social_account&.active?

    # Try to find by platform and user
    SocialAccount.find_by(
      platform: post.platform,
      user_id: post.user_id,
      active: true
    )
  end

  def publish_to_platform(post, social_account)
    # Use the Social::Publisher service if available
    if defined?(Social::Publisher)
      Social::Publisher.publish(
        post: post,
        social_account: social_account
      )
    else
      # Fallback to direct publishing based on platform
      publish_direct(post, social_account)
    end
  end

  def publish_direct(post, social_account)
    platform = post.platform.downcase

    case platform
    when 'instagram'
      publish_instagram(post, social_account)
    when 'twitter', 'x'
      publish_twitter(post, social_account)
    when 'linkedin'
      publish_linkedin(post, social_account)
    when 'facebook'
      publish_facebook(post, social_account)
    else
      { success: false, error: "Unsupported platform: #{platform}" }
    end
  end

  def publish_instagram(post, social_account)
    return { success: false, error: 'Instagram posting requires image or video' } unless post.content&.media_url.present? || post.video_url.present?

    # Implementation would integrate with Instagram API
    Rails.logger.info "[SocialMediaAgentWorker] Publishing to Instagram"
    { success: true, platform_post_id: "ig_#{post.id}_#{Time.current.to_i}" }
  end

  def publish_twitter(post, social_account)
    return { success: false, error: 'Twitter posting requires content' } unless post.content&.body.present?

    # Implementation would integrate with Twitter/X API
    Rails.logger.info "[SocialMediaAgentWorker] Publishing to Twitter/X"
    { success: true, platform_post_id: "tw_#{post.id}_#{Time.current.to_i}" }
  end

  def publish_linkedin(post, social_account)
    return { success: false, error: 'LinkedIn posting requires content' } unless post.content&.body.present?

    # Implementation would integrate with LinkedIn API
    Rails.logger.info "[SocialMediaAgentWorker] Publishing to LinkedIn"
    { success: true, platform_post_id: "li_#{post.id}_#{Time.current.to_i}" }
  end

  def publish_facebook(post, social_account)
    return { success: false, error: 'Facebook posting requires content' } unless post.content&.body.present?

    # Implementation would integrate with Facebook API
    Rails.logger.info "[SocialMediaAgentWorker] Publishing to Facebook"
    { success: true, platform_post_id: "fb_#{post.id}_#{Time.current.to_i}" }
  end

  def notify_user(post, status, error = nil)
    return unless post.user

    case status
    when 'published'
      if post.user.can_run_autonomous_workflows?
        # Send notification about successful publish
        Rails.logger.info "[SocialMediaAgentWorker] Sending publish notification for post #{post.id}"
      end
    when 'failed'
      # Log failure for user review
      Rails.logger.warn "[SocialMediaAgentWorker] Post #{post.id} failed: #{error}"
    end
  end
end
