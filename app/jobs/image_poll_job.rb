# frozen_string_literal: true

# Polling job for Defapi image generation tasks
# Supports both legacy image API and new GPT-Image-1.5 API
class ImagePollJob < ApplicationJob
  queue_as :default

  MAX_ATTEMPTS = 120 # Poll for up to 10 minutes (120 * 5 seconds)
  POLL_INTERVAL = 5.seconds

  def perform(draft_id, task_id = nil, attempt = 0)
    draft = DraftContent.find(draft_id)

    return if draft.media_url.present?

    if attempt >= MAX_ATTEMPTS
      draft.update(status: 'failed')
      Rails.logger.error "ImagePollJob: Max attempts reached for draft #{draft_id}"
      return
    end

    # Get task_id from draft metadata if not provided
    task_id ||= draft.metadata['task_id']
    return if task_id.blank?

    # Check API version from metadata to determine which status method to use
    api_version = draft.metadata['api_version']
    use_gpt_image = api_version == 'gpt-image-1.5'

    status_response = if use_gpt_image
                        DefapiService.new.gpt_image_status(task_id)
                      else
                        DefapiService.new.image_status(task_id)
                      end

    case status_response['status']
    when 'success'
      if status_response['output'].present?
        draft.update(
          media_url: status_response['output'],
          status: 'draft'
        )
        Rails.logger.info "ImagePollJob: Draft #{draft_id} completed successfully"
      else
        draft.update(status: 'failed')
        Rails.logger.error "ImagePollJob: Draft #{draft_id} succeeded but no output"
      end
    when 'failed', 'error'
      draft.update(status: 'failed')
      Rails.logger.error "ImagePollJob: Draft #{draft_id} failed - #{status_response['status_reason']}"
    when 'in_progress', 'starting', 'pending'
      # Still processing, schedule next poll
      ImagePollJob.perform_later(draft_id, task_id, attempt + 1)
    else
      # Unknown status, schedule next poll
      ImagePollJob.perform_later(draft_id, task_id, attempt + 1)
    end
  end
end
