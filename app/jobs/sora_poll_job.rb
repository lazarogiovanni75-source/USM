# frozen_string_literal: true

# Polling job for Defapi Sora 2 video generation tasks
# API Documentation: https://defapi.org/en/model/openai/sora-2-pro
class SoraPollJob < ApplicationJob
  queue_as :default

  MAX_ATTEMPTS = 240 # Poll for up to 20 minutes (240 * 5 seconds) for 25-second videos
  POLL_INTERVAL = 5.seconds

  def perform(draft_id, task_id = nil, attempt = 0)
    draft = DraftContent.find(draft_id)

    return if draft.media_url.present?

    if attempt >= MAX_ATTEMPTS
      draft.update(status: 'failed')
      Rails.logger.error "SoraPollJob: Max attempts reached for draft #{draft_id}"
      return
    end

    # Get task_id from draft metadata if not provided
    task_id ||= draft.metadata['task_id']
    return if task_id.blank?

    status_response = DefapiService.new.task_status(task_id)

    Rails.logger.info "SoraPollJob: Draft #{draft_id}, Task #{task_id}, Status: #{status_response['status']}, Attempt: #{attempt}"

    case status_response['status']
    when 'success'
      if status_response['output'].present?
        draft.update(
          media_url: status_response['output'],
          status: 'draft'
        )
        Rails.logger.info "SoraPollJob: Draft #{draft_id} completed successfully with video: #{status_response['output']}"
      else
        draft.update(status: 'failed')
        Rails.logger.error "SoraPollJob: Draft #{draft_id} succeeded but no output"
      end
    when 'failed', 'error'
      error_msg = status_response['error'] || 'Video generation failed without details'
      draft.update(status: 'failed')
      Rails.logger.error "SoraPollJob: Draft #{draft_id} failed - #{error_msg} - #{status_response.inspect}"
    when 'in_progress', 'pending', 'submitted', 'starting'
      # Still processing, schedule next poll
      SoraPollJob.perform_later(draft_id, task_id, attempt + 1)
    else
      # Unknown status, schedule next poll but log warning
      Rails.logger.warn "SoraPollJob: Unknown status '#{status_response['status']}' for draft #{draft_id}"
      SoraPollJob.perform_later(draft_id, task_id, attempt + 1)
    end
  end
end
