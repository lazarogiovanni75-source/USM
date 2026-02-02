# frozen_string_literal: true

# Background job for posting content to Buffer
# when social posts are created or scheduled.
#
# This job is enqueued by ScheduledPost callbacks and processes
# Buffer API delivery asynchronously to avoid blocking the main request.
# Supports retry with exponential backoff for reliable delivery.
class PostWebhookJob < ApplicationJob
  queue_as :default

  # Retry configuration with exponential backoff
  # Attempts: 5 (1 initial + 4 retries)
  # Wait times: 3s, 6s, 12s, 24s, 48s (exponentially longer)
  retry_on StandardError, wait: ->(executions) { 3 * (2**executions) }, attempts: 5

  # Called when all retry attempts are exhausted
  # Marks posting as failed in the database and sends admin notification
  def perform(scheduled_post_id, event_type = 'created')
    scheduled_post = ScheduledPost.find_by(id: scheduled_post_id)
    return unless scheduled_post

    # Calculate attempt number (executions + 1 for current attempt)
    attempt_number = executions + 1

    Rails.logger.info(
      "[PostWebhookJob] Processing #{event_type} event for post #{scheduled_post.id} " \
      "(attempt #{attempt_number}/5) at #{Time.current.iso8601}"
    )

    # Get Buffer access token from social account
    buffer_service = BufferService.new(scheduled_post.social_account&.buffer_access_token)
    unless buffer_service.configured?
      Rails.logger.error("[PostWebhookJob] Buffer not configured for post #{scheduled_post.id}")
      raise BufferService::BufferError, 'Buffer access token not configured'
    end

    content = scheduled_post.content
    profile_id = scheduled_post.social_account&.buffer_profile_id

    unless profile_id.present?
      Rails.logger.error("[PostWebhookJob] Buffer profile ID not configured for post #{scheduled_post.id}")
      raise BufferService::BufferError, 'Buffer profile ID not configured'
    end

    text = extract_caption(content)
    media = extract_media(content)

    options = {}
    options[:media] = media if media.present?
    options[:scheduled_at] = scheduled_post.scheduled_at if scheduled_post.scheduled_at.present?

    # If posting immediately, use share_now
    if event_type == 'share_now'
      response = buffer_service.share_now(profile_id, text, options)
    else
      # For scheduled posts
      response = buffer_service.create_update(profile_id, text, options)
    end

    if response.present? && (response['success'] || response['update'].present?)
      Rails.logger.info(
        "[PostWebhookJob] Successfully posted to Buffer for post #{scheduled_post.id} " \
        "on attempt #{attempt_number} at #{Time.current.iso8601}"
      )

      # Extract Buffer update ID from response
      buffer_update_id = response.dig('update', 'id') || response['updates']&.first&.dig('id')

      # Mark posting as successful
      scheduled_post.update!(
        webhook_status: 'success',
        webhook_error: nil,
        webhook_attempts: attempt_number,
        last_webhook_at: Time.current,
        buffer_update_id: buffer_update_id
      )

      true
    else
      # Log failure with attempt number and payload details
      log_failed_attempt(scheduled_post, attempt_number, response)

      # Raise exception to trigger retry (if under max attempts)
      raise BufferService::BufferError, "Buffer posting failed - will retry"
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.warn(
      "[PostWebhookJob] ScheduledPost #{scheduled_post_id} not found at #{Time.current.iso8601}: #{e.message}"
    )
    raise
  rescue BufferService::BufferError => e
    # Check if this is the last retry attempt
    if executions >= 4 # 0-indexed, so 4 = 5th attempt
      handle_all_retries_exhausted(scheduled_post_id, e)
    end

    log_detailed_error(e, scheduled_post_id)
    raise
  rescue StandardError => e
    # Check if this is the last retry attempt
    if executions >= 4 # 0-indexed, so 4 = 5th attempt
      handle_all_retries_exhausted(scheduled_post_id, e)
    end

    log_detailed_error(e, scheduled_post_id)
    raise
  end

  private

  # Get the number of previous execution attempts (for retry tracking)
  def executions
    execution_attempts.to_i
  end

  def execution_attempts
    0
  end

  def extract_caption(content)
    return nil if content.nil?
    content.body.presence || content.title.presence || content.caption.presence
  end

  def extract_media(content)
    return nil if content.nil?
    return nil if content.media_urls.blank?

    media_urls = content.media_urls
    return nil if media_urls.empty?

    media = {}

    # Handle different media_urls formats
    case media_urls
    when String
      parsed = JSON.parse(media_urls)
      media[:photo] = parsed['urls']&.first || parsed.first if parsed.present?
    when Array
      media[:photo] = media_urls.first if media_urls.present?
    when Hash
      media[:photo] = media_urls['urls']&.first || media_urls.values.first if media_urls.present?
    end

    media.present? ? media : nil
  end

  def log_failed_attempt(scheduled_post, attempt_number, response)
    payload_summary = {
      user_id: scheduled_post.user_id,
      platform: scheduled_post.social_account&.platform,
      scheduled_at: scheduled_post.scheduled_at&.iso8601,
      content_title: scheduled_post.content&.title&.slice(0, 50),
      buffer_response: response&.slice('success', 'error', 'message')
    }

    Rails.logger.warn(
      "[PostWebhookJob] Buffer posting FAILED - Attempt #{attempt_number}/5 for post #{scheduled_post.id} " \
      "at #{Time.current.iso8601}. Details: #{payload_summary.to_json}"
    )
  end

  def log_detailed_error(exception, scheduled_post_id)
    Rails.logger.warn(
      "[PostWebhookJob] ERROR (attempt #{executions + 1}/5) at #{Time.current.iso8601}: " \
      "post_id=#{scheduled_post_id}, " \
      "error_class=#{exception.class}, " \
      "error_message=#{exception.message}"
    )
  end

  def handle_all_retries_exhausted(scheduled_post_id, exception)
    scheduled_post = ScheduledPost.find_by(id: scheduled_post_id)
    return unless scheduled_post

    # Mark the Buffer posting as failed in the database
    scheduled_post.update!(
      webhook_status: 'failed',
      webhook_error: "All retries exhausted - #{exception.class}: #{exception.message}",
      webhook_attempts: 5,
      last_webhook_at: Time.current
    )

    # Send notification to admin
    notify_admin_about_failure(scheduled_post, exception)
  end

  def notify_admin_about_failure(scheduled_post, exception)
    admin_notification = {
      post_id: scheduled_post.id,
      user_id: scheduled_post.user_id,
      platform: scheduled_post.social_account&.platform,
      scheduled_time: scheduled_post.scheduled_at&.iso8601,
      error_type: exception.class.to_s,
      error_message: exception.message,
      timestamp: Time.current.iso8601,
      attempts: 5
    }

    # Log the admin notification
    Rails.logger.warn(
      "[PostWebhookJob] ADMIN NOTIFICATION - Buffer Posting Failed for Post ##{scheduled_post.id}: " \
      "user_id=#{admin_notification[:user_id]}, " \
      "platform=#{admin_notification[:platform]}, " \
      "error=#{admin_notification[:error_type]}: #{admin_notification[:error_message]}, " \
      "timestamp=#{admin_notification[:timestamp]}"
    )
  rescue StandardError => e
    Rails.logger.warn("[PostWebhookJob] Failed to send admin notification: #{e.message}")
  end
end
