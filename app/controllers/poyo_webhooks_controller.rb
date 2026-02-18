# frozen_string_literal: true

# Webhook controller to receive callbacks from Poyo.ai video generation service
class PoyoWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false
  before_action :verify_poyo_webhook, only: :video_callback

  # Handle video generation callback from Poyo.ai
  def video_callback
    Rails.logger.info "[PoyoWebhook] Received callback: #{params.inspect}"

    # Extract task data from callback
    task_id = params.dig(:data, :task_id) || params[:task_id]
    status = params.dig(:data, :status) || params[:status]
    video_url = params.dig(:data, :result, :video_url) || params.dig(:result, :video_url) || params[:video_url]
    error = params.dig(:data, :error, :message) || params.dig(:error, :message) || params[:error]

    Rails.logger.info "[PoyoWebhook] Task #{task_id}, Status: #{status}, Video URL: #{video_url}"

    if task_id.blank?
      Rails.logger.error "[PoyoWebhook] No task_id in callback"
      render json: { error: 'No task_id provided' }, status: :bad_request
      return
    end

    # Find the draft by task_id
    draft = DraftContent.find_by("metadata ->> 'task_id' = ?", task_id)

    if draft.nil?
      Rails.logger.error "[PoyoWebhook] Draft not found for task_id: #{task_id}"
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
        Rails.logger.info "[PoyoWebhook] Draft #{draft.id} updated with video URL: #{video_url}"
        render json: { success: true, message: 'Video saved successfully' }
      else
        draft.update!(status: 'failed')
        Rails.logger.error "[PoyoWebhook] Draft #{draft.id} succeeded but no video URL"
        render json: { error: 'No video URL in callback' }, status: :unprocessable_entity
      end
    when 'failed', 'error'
      error_msg = error || 'Video generation failed'
      draft.update!(status: 'failed')
      Rails.logger.error "[PoyoWebhook] Draft #{draft.id} failed: #{error_msg}"
      render json: { success: false, error: error_msg }
    else
      # Still processing - just acknowledge
      Rails.logger.info "[PoyoWebhook] Draft #{draft.id} status: #{status} - continuing"
      render json: { success: true, message: "Status: #{status}" }
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "[PoyoWebhook] Record not found: #{e.message}"
    render json: { error: 'Draft not found' }, status: :not_found
  rescue => e
    Rails.logger.error "[PoyoWebhook] Error: #{e.message}\n#{e.backtrace.first(5)}"
    render json: { error: e.message }, status: :internal_server_error
  end

  private

  def verify_poyo_webhook
    # Poyo.ai may send a signature header for verification
    # For now, we accept callbacks without verification
    # In production, you should verify the signature if provided
    Rails.logger.debug "[PoyoWebhook] Verifying webhook request"
  end
end
