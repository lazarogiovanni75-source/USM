# frozen_string_literal: true

# Background job for sending Make webhook notifications
# when social posts are created or scheduled.
#
# This job is enqueued by ScheduledPost callbacks and processes
# webhook delivery asynchronously to avoid blocking the main request.
# Supports retry with exponential backoff for reliable delivery.
class PostWebhookJob < ApplicationJob
  queue_as :default

  # Retry configuration with exponential backoff
  # Attempts: 5 (1 initial + 4 retries)
  # Wait times: 3s, 6s, 12s, 24s, 48s (exponentially longer)
  retry_on StandardError, wait: ->(executions) { 3 * (2**executions) }, attempts: 5

  # Called when all retry attempts are exhausted
  # Marks webhook as failed in the database and sends admin notification
  def perform(scheduled_post_id, event_type = 'created')
    scheduled_post = ScheduledPost.find_by(id: scheduled_post_id)
    return unless scheduled_post

    # Calculate attempt number (executions + 1 for current attempt)
    attempt_number = executions + 1

    Rails.logger.info(
      "[PostWebhookJob] Processing #{event_type} event for post #{scheduled_post.id} " \
      "(attempt #{attempt_number}/5) at #{Time.current.iso8601}"
    )

    service = MakeWebhookService.new(scheduled_post)
    success = event_type == 'created' ? service.trigger_post_created : service.trigger_post_scheduled

    if success
      Rails.logger.info(
        "[PostWebhookJob] Successfully sent webhook for post #{scheduled_post.id} " \
        "on attempt #{attempt_number} at #{Time.current.iso8601}"
      )

      # Mark webhook as successful
      scheduled_post.update!(
        webhook_status: 'success',
        webhook_error: nil,
        webhook_attempts: attempt_number,
        last_webhook_at: Time.current
      )
    else
      # Log failure with attempt number and payload details
      log_failed_attempt(scheduled_post, attempt_number)

      # Raise exception to trigger retry (if under max attempts)
      raise StandardError, "Webhook delivery failed - will retry"
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.warn(
      "[PostWebhookJob] ScheduledPost #{scheduled_post_id} not found at #{Time.current.iso8601}: #{e.message}"
    )
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

  def log_failed_attempt(scheduled_post, attempt_number)
    payload_summary = {
      user_id: scheduled_post.user_id,
      platform: scheduled_post.social_account&.platform,
      scheduled_at: scheduled_post.scheduled_at&.iso8601,
      content_title: scheduled_post.content&.title&.slice(0, 50)
    }

    Rails.logger.warn(
      "[PostWebhookJob] Webhook delivery FAILED - Attempt #{attempt_number}/5 for post #{scheduled_post.id} " \
      "at #{Time.current.iso8601}. Payload: #{payload_summary.to_json}"
    )
  end

  def log_detailed_error(exception, scheduled_post_id)
    Rails.logger.warn(
      "[PostWebhookJob] ERROR (attempt #{executions + 1}/5) at #{Time.current.iso8601}: " \
      "post_id=#{scheduled_post_id}, " \
      "error_class=#{exception.class}, " \
      "error_message=#{exception.message}, " \
      "http_status=#{extract_http_status(exception)}"
    )
  end

  def extract_http_status(exception)
    return nil unless exception.respond_to?(:response) && exception.response.present?

    exception.response.code
  rescue StandardError
    nil
  end

  def handle_all_retries_exhausted(scheduled_post_id, exception)
    scheduled_post = ScheduledPost.find_by(id: scheduled_post_id)
    return unless scheduled_post

    # Mark the webhook delivery as failed in the database
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
      error_details: extract_error_details(exception),
      timestamp: Time.current.iso8601,
      attempts: 5
    }

    # Log the admin notification
    Rails.logger.warn(
      "[PostWebhookJob] ADMIN NOTIFICATION - Webhook Delivery Failed for Post ##{scheduled_post.id}: " \
      "user_id=#{admin_notification[:user_id]}, " \
      "platform=#{admin_notification[:platform]}, " \
      "error=#{admin_notification[:error_type]}: #{admin_notification[:error_message]}, " \
      "timestamp=#{admin_notification[:timestamp]}"
    )

    # In production, integrate with your notification system:
    # AdminNotificationService.deliver(
    #   subject: "[URGENT] Webhook Delivery Failed - Post ##{scheduled_post.id}",
    #   body: build_admin_email_body(admin_notification),
    #   priority: 'high'
    # )
  rescue StandardError => e
    Rails.logger.warn("[PostWebhookJob] Failed to send admin notification: #{e.message}")
  end

  def extract_error_details(exception)
    {
      message: exception.message,
      backtrace: exception.backtrace&.first(5),
      response_code: extract_http_status(exception)
    }
  rescue StandardError
    { message: exception.message }
  end

  def build_admin_email_body(notification)
    <<~BODY
      Webhook delivery to Make failed after 5 retry attempts.

      Post Details:
      - Post ID: #{notification[:post_id]}
      - User ID: #{notification[:user_id]}
      - Platform: #{notification[:platform]}
      - Scheduled Time: #{notification[:scheduled_time]}

      Error Information:
      - Error Type: #{notification[:error_type]}
      - Error Message: #{notification[:error_message]}
      - HTTP Status: #{notification[:error_details][:response_code] || 'N/A'}

      Timestamp: #{notification[:timestamp]}

      Please check:
      1. Webhook URL configuration
      2. Network connectivity
      3. Make webhook endpoint status
    BODY
  end
end
