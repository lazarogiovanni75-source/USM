# frozen_string_literal: true

# Webhook controller to receive callbacks from Atlas Cloud video generation service
class AtlasCloudWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false
  before_action :verify_atlas_cloud_webhook, only: :video_callback

  # Handle video generation callback from Atlas Cloud
  def video_callback
    Rails.logger.info "[AtlasCloudWebhook] Received callback: #{params.inspect}"

    # Extract task data from callback
    task_id = params.dig(:data, :task_id) || params[:task_id]
    status = params.dig(:data, :status) || params[:status]
    video_url = params.dig(:data, :result, :video_url) || params.dig(:result, :video_url) || params[:video_url]
    error = params.dig(:data, :error, :message) || params.dig(:error, :message) || params[:error]

    Rails.logger.info "[AtlasCloudWebhook] Task #{task_id}, Status: #{status}, Video URL: #{video_url}"

    if task_id.blank?
      Rails.logger.error "[AtlasCloudWebhook] No task_id in callback"
      render json: { error: 'No task_id provided' }, status: :bad_request
      return
    end

    # Find the draft by task_id
    draft = DraftContent.find_by("metadata ->> 'task_id' = ?", task_id)

    if draft.nil?
      Rails.logger.error "[AtlasCloudWebhook] Draft not found for task_id: #{task_id}"
      render json: { error: 'Draft not found' }, status: :not_found
      return
    end

    case status
    when 'success', 'completed'
      if video_url.present?
        draft.update!(
          media_url: video_url,
          status: 'draft'
        )
        Rails.logger.info "[AtlasCloudWebhook] Draft #{draft.id} updated with video URL: #{video_url}"
        render json: { success: true, message: 'Video saved successfully' }
      else
        draft.update!(status: 'failed')
        Rails.logger.error "[AtlasCloudWebhook] Draft #{draft.id} succeeded but no video URL"
        render json: { error: 'No video URL in callback' }, status: :unprocessable_entity
      end
    when 'failed', 'error'
      error_msg = error || 'Video generation failed'
      draft.update!(status: 'failed')
      Rails.logger.error "[AtlasCloudWebhook] Draft #{draft.id} failed: #{error_msg}"
      render json: { success: false, error: error_msg }
    else
      # Still processing - just acknowledge
      Rails.logger.info "[AtlasCloudWebhook] Draft #{draft.id} status: #{status} - continuing"
      render json: { success: true, message: "Status: #{status}" }
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "[AtlasCloudWebhook] Record not found: #{e.message}"
    render json: { error: 'Draft not found' }, status: :not_found
  rescue => e
    Rails.logger.error "[AtlasCloudWebhook] Error: #{e.message}\n#{e.backtrace.first(5)}"
    render json: { error: e.message }, status: :internal_server_error
  end

  private

  def verify_atlas_cloud_webhook
    # Atlas Cloud may send a signature header for verification
    # For now, we accept callbacks without verification
    # In production, you should verify the signature if provided
    Rails.logger.debug "[AtlasCloudWebhook] Verifying webhook request"
  end
end
