# frozen_string_literal: true

# Controller for receiving webhook callbacks from Postforme
# Handles post status updates, publishing notifications, and analytics data
class PostformeWebhooksController < ApplicationController
  # Skip CSRF for webhooks (external services can't provide CSRF tokens)
  skip_before_action :verify_authenticity_token, only: [:create]

  # Postforme sends webhook POST requests to this endpoint
  def create
    payload = request.body.read
    signature = request.headers['X-Postforme-Signature']

    # Verify webhook signature if configured
    if signature.present? && !verify_signature(payload, signature)
      Rails.logger.error('[PostformeWebhook] Invalid signature')
      return render json: { error: 'Invalid signature' }, status: :unauthorized
    end

    data = JSON.parse(payload)

    # Handle different webhook event types
    event_type = data['event'] || data['type'] || 'unknown'

    case event_type
    when 'post.published'
      handle_post_published(data)
    when 'post.failed'
      handle_post_failed(data)
    when 'post.scheduled'
      handle_post_scheduled(data)
    when 'analytics.update'
      handle_analytics_update(data)
    else
      Rails.logger.info("[PostformeWebhook] Unhandled event type: #{event_type}")
    end

    # Always respond with 200 to acknowledge receipt
    render json: { status: 'received' }, status: :ok
  end

  private

  # Handle post published event
  def handle_post_published(data)
    postforme_post_id = data.dig('post', 'id') || data['post_id']
    external_id = data.dig('post', 'external_id') || data['external_id']

    return unless postforme_post_id

    scheduled_post = ScheduledPost.find_by(postforme_post_id: postforme_post_id)
    return unless scheduled_post

    scheduled_post.update!(
      webhook_status: 'published',
      postforme_post_id: postforme_post_id,
      published_at: Time.current
    )

    Rails.logger.info("[PostformeWebhook] Post ##{scheduled_post.id} published successfully")
  end

  # Handle post failed event
  def handle_post_failed(data)
    postforme_post_id = data.dig('post', 'id') || data['post_id']
    error_message = data.dig('post', 'error') || data['error'] || 'Unknown error'

    return unless postforme_post_id

    scheduled_post = ScheduledPost.find_by(postforme_post_id: postforme_post_id)
    return unless scheduled_post

    scheduled_post.update!(
      webhook_status: 'failed',
      webhook_error: error_message,
      webhook_attempts: scheduled_post.webhook_attempts.to_i + 1
    )

    Rails.logger.error("[PostformeWebhook] Post ##{scheduled_post.id} failed: #{error_message}")
  end

  # Handle post scheduled event
  def handle_post_scheduled(data)
    postforme_post_id = data.dig('post', 'id') || data['post_id']
    scheduled_time = data.dig('post', 'scheduled_at') || data['scheduled_at']

    return unless postforme_post_id

    scheduled_post = ScheduledPost.find_by(postforme_post_id: postforme_post_id)
    return unless scheduled_post

    scheduled_post.update!(
      webhook_status: 'scheduled',
      scheduled_at: scheduled_time
    )

    Rails.logger.info("[PostformeWebhook] Post ##{scheduled_post.id} scheduled for #{scheduled_time}")
  end

  # Handle analytics update event
  def handle_analytics_update(data)
    postforme_post_id = data.dig('post', 'id') || data['post_id']
    analytics = data['analytics'] || data

    return unless postforme_post_id

    scheduled_post = ScheduledPost.find_by(postforme_post_id: postforme_post_id)
    return unless scheduled_post

    # Create or update analytics record
    PostformeAnalytic.upsert(
      postforme_post_id: postforme_post_id,
      clicks: analytics['clicks'],
      impressions: analytics['impressions'],
      engagement: analytics['engagement'],
      shares: analytics['shares'],
      updated_at: Time.current
    )

    Rails.logger.info("[PostformeWebhook] Analytics updated for post ##{scheduled_post.id}")
  end

  # Verify webhook signature (if Postforme supports it)
  def verify_signature(payload, signature)
    # Postforme may send a signature header - implement verification if needed
    # For now, just log it
    Rails.logger.debug("[PostformeWebhook] Received signature: #{signature[0..20]}...")
    true # Allow all for now - implement HMAC verification when Postforme provides docs
  rescue StandardError => e
    Rails.logger.error("[PostformeWebhook] Signature verification error: #{e.message}")
    false
  end
end
