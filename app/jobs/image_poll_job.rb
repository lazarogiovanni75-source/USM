# frozen_string_literal: true

# Polling job for image generation tasks (supports multiple services)
# Primary: Defapi/GPT-Image-1.5
# Secondary: OpenAI/DALL-E (synchronous, no polling needed)
class ImagePollJob < ApplicationJob
  queue_as :default

  MAX_ATTEMPTS = 120 # Poll for up to 10 minutes (120 * 5 seconds)
  POLL_INTERVAL = 5.seconds

  def perform(draft_id, task_id = nil, service = nil, attempt = 0)
    draft = DraftContent.find(draft_id)

    return if draft.media_url.present?

    if attempt >= MAX_ATTEMPTS
      draft.update(status: 'failed')
      Rails.logger.error "ImagePollJob: Max attempts reached for draft #{draft_id}"
      return
    end

    # Get task_id and service from draft metadata if not provided
    task_id ||= draft.metadata['task_id']
    service ||= draft.metadata['service'] || 'defapi'
    return if task_id.blank?

    # Skip polling for OpenAI (DALL-E generates synchronously)
    if service == 'openai'
      Rails.logger.warn "ImagePollJob: OpenAI service generates synchronously, skipping poll"
      return
    end

    # Get status based on service
    status_response = get_status(service, task_id)

    Rails.logger.info "ImagePollJob: Draft #{draft_id}, Service #{service}, Task #{task_id}, Status: #{status_response['status']}, Attempt: #{attempt}"

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
      # Only mark as failed after a few attempts (allow time for task to register)
      if attempt >= 3
        draft.update(status: 'failed')
        Rails.logger.error "ImagePollJob: Draft #{draft_id} failed - #{status_response['error']}"
      else
        # Retry after delay - task may still be registering
        ImagePollJob.perform_later(draft_id, task_id, service, attempt + 1)
      end
    when 'in_progress', 'starting', 'pending'
      # Still processing, schedule next poll
      ImagePollJob.perform_later(draft_id, task_id, service, attempt + 1)
    when 'not_found'
      # Task not found yet - this is normal for first few seconds
      # Retry after delay
      ImagePollJob.perform_later(draft_id, task_id, service, attempt + 1)
    else
      # Unknown status, schedule next poll
      ImagePollJob.perform_later(draft_id, task_id, service, attempt + 1)
    end
  end

  private

  def get_status(service, task_id)
    case service
    when 'defapi'
      # Use GPT image status for Defapi
      begin
        DefapiService.new.gpt_image_status(task_id)
      rescue DefapiService::Error => e
        # Handle 404 "task not found" - the task may have expired or never existed
        # Return 'not_found' so the job retries instead of failing immediately
        if e.message.include?('404') || e.message.include?('task not found')
          Rails.logger.warn "ImagePollJob: Task #{task_id} not found yet, will retry..."
          return { 'status' => 'not_found', 'error' => 'Task not found - may still be processing' }
        end
        raise
      end
    when 'openai'
      # OpenAI DALL-E is synchronous, return success immediately
      { 'status' => 'success', 'output' => task_id }
    else
      # Default to Defapi
      begin
        DefapiService.new.gpt_image_status(task_id)
      rescue DefapiService::Error => e
        if e.message.include?('404') || e.message.include?('task not found')
          return { 'status' => 'not_found', 'error' => 'Task not found - may still be processing' }
        end
        raise
      end
    end
  end
end
