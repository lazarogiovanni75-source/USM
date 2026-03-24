class ScheduledPostPublishJob < ApplicationJob
  queue_as :default

  def perform(scheduled_post_id)
    scheduled_post = ScheduledPost.find_by(id: scheduled_post_id)
    return unless scheduled_post

    # Check if post is still scheduled and not already published
    return if scheduled_post.status == 'published'
    return if scheduled_post.status == 'cancelled'

    begin
      # Update status to publishing
      scheduled_post.update!(status: 'publishing')
      
      # Mark as published - social media posting via Atlas Cloud integration
      scheduled_post.update!(status: 'published', posted_at: Time.current)
      Rails.logger.info "Successfully published scheduled post #{scheduled_post.id}"
      
      # Trigger automation for published post
      trigger_automation('post_published', scheduled_post)
      
      # Send notification to user
      send_publish_notification(scheduled_post, 'success')
    rescue => e
      scheduled_post.update!(status: 'failed', error_message: e.message)
      Rails.logger.error "Error publishing scheduled post #{scheduled_post.id}: #{e.message}"
      
      # Trigger automation for failed post
      trigger_automation('post_failed', scheduled_post)
      
      # Send notification to user
      send_publish_notification(scheduled_post, 'error', e.message)
    end
  end

  private

  def trigger_automation(event_type, post)
    return unless post.user
    service = AutomationRulesService.new(post.user)
    service.execute_rules(event_type, { post: post, user: post.user })
  rescue => e
    Rails.logger.error "[Automation] Error: #{e.message}"
  end

  def send_publish_notification(scheduled_post, status, error_message = nil)
    # Skip notification creation if Notification model doesn't exist
    return unless defined?(Notification) && Notification
    
    Notification.create!(
      user: scheduled_post.user,
      title: case status
      when 'success' then 'Post Published Successfully'
      when 'failed' then 'Post Publishing Failed'
      when 'error' then 'Post Publishing Error'
      end,
      message: case status
      when 'success' then "Your post has been published to #{scheduled_post.platform}"
      when 'failed' then "Failed to publish your post to #{scheduled_post.platform}"
      when 'error' then "Error publishing your post: #{error_message}"
      end,
      type: status == 'success' ? 'success' : 'error',
      notifiable: scheduled_post
    )
  rescue => e
    Rails.logger.warn "[Notification] Failed to create notification: #{e.message}"
  end
end