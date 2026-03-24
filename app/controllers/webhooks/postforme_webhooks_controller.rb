# frozen_string_literal: true

module Webhooks
  # Controller for receiving Postforme webhook events
  # Handles publish_success, publish_failed, and metrics_update events
  class PostformeWebhooksController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :verify_webhook_signature, unless: :development?

    # POST /webhooks/postforme
    def receive
      event_type = params[:event_type] || params.dig('event', 'type')
      data = params[:data] || params.dig('event', 'data')

      Rails.logger.info "[PostformeWebhook] Received event: #{event_type}"

      case event_type
      when 'publish_success', 'post.published'
        handle_publish_success(data)
      when 'publish_failed', 'post.failed'
        handle_publish_failed(data)
      when 'metrics_update', 'metrics.updated'
        handle_metrics_update(data)
      else
        Rails.logger.warn "[PostformeWebhook] Unknown event type: #{event_type}"
      end

      head :ok
    rescue => e
      Rails.logger.error "[PostformeWebhook] Error processing webhook: #{e.message}"
      head :ok # Return ok anyway to prevent retries
    end

    private

    def handle_publish_success(data)
      postforme_id = data.dig('post', 'id') || data['postforme_post_id']
      return unless postforme_id

      post = ScheduledPost.find_by(postforme_post_id: postforme_id)
      return unless post

      post.update!(
        status: 'published',
        published_at: Time.current,
        platform_url: data.dig('post', 'url') || data['url']
      )

      Rails.logger.info "[PostformeWebhook] Post #{post.id} marked as published"
    end

    def handle_publish_failed(data)
      postforme_id = data.dig('post', 'id') || data['postforme_post_id']
      return unless postforme_id

      post = ScheduledPost.find_by(postforme_post_id: postforme_id)
      return unless post

      error_message = data.dig('error', 'message') || data['error'] || 'Publishing failed'

      post.update!(
        status: 'failed',
        error_message: error_message
      )

      Rails.logger.warn "[PostformeWebhook] Post #{post.id} marked as failed: #{error_message}"
    end

    def handle_metrics_update(data)
      postforme_id = data.dig('post', 'id') || data['postforme_post_id']
      return unless postforme_id

      post = ScheduledPost.find_by(postforme_post_id: postforme_id)
      return unless post

      metrics = data['metrics'] || data

      PostMetric.find_or_initialize_by(
        post_type: 'ScheduledPost',
        post_id: post.id,
        collected_at: Time.current
      ).update!(
        impressions: metrics.dig('impressions', 'count') || metrics['impressions'] || 0,
        likes: metrics.dig('likes', 'count') || metrics['likes'] || 0,
        comments: metrics.dig('comments', 'count') || metrics['comments'] || 0,
        shares: metrics.dig('shares', 'count') || metrics['shares'] || 0,
        saves: metrics.dig('saves', 'count') || metrics['saves'] || 0,
        clicks: metrics.dig('clicks', 'count') || metrics['clicks'] || 0,
        raw_metrics: metrics
      )

      Rails.logger.info "[PostformeWebhook] Metrics updated for post #{post.id}"
    end

    def verify_webhook_signature
      signature = request.headers['X-Postforme-Signature']
      return if signature.blank?

      secret = ENV.fetch('POSTFORME_WEBHOOK_SECRET', 'development_secret')
      body = request.body.read
      expected_signature = OpenSSL::HMAC.hexdigest('SHA256', secret, body)

      return if ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)

      Rails.logger.warn "[PostformeWebhook] Invalid signature"
      head :unauthorized
    end

    def development?
      Rails.env.development?
    end
  end
end
