# frozen_string_literal: true

# Background job for posting content to Postforme API
# when social posts are created or scheduled.
#
# This job is enqueued by ScheduledPost callbacks and processes
# Postforme API delivery asynchronously to avoid blocking the main request.
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

    attempt_number = executions + 1

    Rails.logger.info(
      "[PostWebhookJob] Processing #{event_type} event for post #{scheduled_post.id} " \
      "(attempt #{attempt_number}/5) at #{Time.current.iso8601}"
    )

    # Get Postforme API key from social account
    postforme_service = PostformeService.new(scheduled_post.social_account&.postforme_api_key)
    unless postforme_service.configured?
      Rails.logger.error("[PostWebhookJob] Postforme not configured for post #{scheduled_post.id}")
      raise PostformeService::PostformeError, 'Postforme API key not configured'
    end

    content = scheduled_post.content
    profile_id = scheduled_post.social_account&.postforme_profile_id

    unless profile_id.present?
      Rails.logger.error("[PostWebhookJob] Postforme profile ID not configured for post #{scheduled_post.id}")
      raise PostformeService::PostformeError, 'Postforme profile ID not configured'
    end

    text = extract_caption(content)
    media = extract_media(content)

    options = {}
    options[:media] = media if media.present?
    options[:scheduled_at] = scheduled_post.scheduled_at if scheduled_post.scheduled_at.present?

    # If posting immediately, use share_now or create_post with now: true
    if event_type == 'share_now'
      response = postforme_service.create_post(profile_id, text, options.merge(now: true))
    else
      # For scheduled posts
      response = postforme_service.create_post(profile_id, text, options)
    end

    if response.present? && response_success?(response)
      Rails.logger.info(
        "[PostWebhookJob] Successfully posted to Postforme for post #{scheduled_post.id} " \
        "on attempt #{attempt_number} at #{Time.current.iso8601}"
      )

      # Extract Postforme post ID from response
      postforme_post_id = extract_post_id(response)

      # Mark posting as successful
      scheduled_post.update!(
        webhook_status: 'success',
        webhook_error: nil,
        webhook_attempts: attempt_number,
        last_webhook_at: Time.current,
        postforme_post_id: postforme_post_id
      )

      true
    else
      log_failed_attempt(scheduled_post, attempt_number, response)
      raise PostformeService::PostformeError, "Postforme posting failed - will retry"
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.warn(
      "[PostWebhookJob] ScheduledPost #{scheduled_post_id} not found at #{Time.current.iso8601}: #{e.message}"
    )
    raise
  rescue PostformeService::PostformeError => e
    if executions >= 4
      handle_all_retries_exhausted(scheduled_post_id, e)
    end

    log_detailed_error(e, scheduled_post_id)
    raise
  rescue StandardError => e
    if executions >= 4
      handle_all_retries_exhausted(scheduled_post_id, e)
    end

    log_detailed_error(e, scheduled_post_id)
    raise
  end

  private

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

    case media_urls
    when String
      parsed = JSON.parse(media_urls)
      media[:url] = parsed['urls']&.first || parsed.first if parsed.present?
    when Array
      media[:url] = media_urls.first if media_urls.present?
    when Hash
      media[:url] = media_urls['urls']&.first || media_urls.values.first if media_urls.present?
    end

    media.present? ? media : nil
  end

  def response_success?(response)
    # Adjust based on actual Postforme API response structure
    response['success'] || response['post'] || response['id'] || response['data']&.dig('id')
  end

  def extract_post_id(response)
    # Adjust based on actual Postforme API response structure
    response.dig('post', 'id') || response.dig('id') || response['data']&.dig('id')
  end

  def log_failed_attempt(scheduled_post, attempt_number, response)
    payload_summary = {
      user_id: scheduled_post.user_id,
      platform: scheduled_post.social_account&.platform,
      scheduled_at: scheduled_post.scheduled_at&.iso8601,
      content_title: scheduled_post.content&.title&.slice(0, 50),
      postforme_response: response&.slice('success', 'error', 'message', 'id')
    }

    Rails.logger.warn(
      "[PostWebhookJob] Postforme posting FAILED - Attempt #{attempt_number}/5 for post #{scheduled_post.id} " \
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

    scheduled_post.update!(
      webhook_status: 'failed',
      webhook_error: "All retries exhausted - #{exception.class}: #{exception.message}",
      webhook_attempts: 5,
      last_webhook_at: Time.current
    )

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

    Rails.logger.warn(
      "[PostWebhookJob] ADMIN NOTIFICATION - Postforme Posting Failed for Post ##{scheduled_post.id}: " \
      "user_id=#{admin_notification[:user_id]}, " \
      "platform=#{admin_notification[:platform]}, " \
      "error=#{admin_notification[:error_type]}: #{admin_notification[:error_message]}, " \
      "timestamp=#{admin_notification[:timestamp]}"
    )
  rescue StandardError => e
    Rails.logger.warn("[PostWebhookJob] Failed to send admin notification: #{e.message}")
  end
end
