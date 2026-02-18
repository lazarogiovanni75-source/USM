# frozen_string_literal: true

# Polling job for video generation tasks (supports multiple services)
# Primary: Poyo.ai (https://api.poyo.ai)
# Secondary: OpenAI/Sora (placeholder for when available)
class SoraPollJob < ApplicationJob
  queue_as :default

  MAX_ATTEMPTS = 1440 # Poll for up to 2 hours (1440 * 5 seconds)
  POLL_INTERVAL = 5.seconds

  def perform(draft_id, task_id = nil, service = nil, attempt = 0)
    draft = DraftContent.find(draft_id)

    return if draft.media_url.present?

    # Get task_id and service from draft metadata if not provided
    task_id ||= draft.metadata['task_id']
    service ||= draft.metadata['service'] || 'poyo'
    return if task_id.blank?

    # Get status FIRST before checking max attempts
    status_response = get_status(service, task_id)

    Rails.logger.info "SoraPollJob: Draft #{draft_id}, Service #{service}, Task #{task_id}, Status: #{status_response['status']}, Attempt: #{attempt}"

    # Check if the task has actually completed or failed
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
      # Task has failed - mark as failed regardless of attempt count
      error_msg = status_response['error'] || status_response['message'] || 'Video generation failed without details'
      draft.update(status: 'failed')
      Rails.logger.error "SoraPollJob: Draft #{draft_id} failed - #{error_msg} - #{status_response.inspect}"
    when 'in_progress', 'pending', 'submitted', 'starting'
      # Still processing - check if we've exceeded max attempts
      if attempt >= MAX_ATTEMPTS
        draft.update(status: 'failed')
        Rails.logger.error "SoraPollJob: Max attempts reached for draft #{draft_id}"
        return
      end
      # Schedule next poll
      SoraPollJob.perform_later(draft_id, task_id, service, attempt + 1)
    when 'not_found', nil
      # Task not found - this can happen with APIs that use webhooks instead of polling
      # Keep retrying for a very long time as the video may still be processing on the server
      if attempt >= MAX_ATTEMPTS
        draft.update(status: 'failed')
        Rails.logger.error "SoraPollJob: Max attempts reached (task not found) for draft #{draft_id}"
        return
      end
      # Retry after delay - continue polling
      Rails.logger.warn "SoraPollJob: Task #{task_id} status unavailable, continuing to poll... (attempt #{attempt + 1})"
      SoraPollJob.perform_later(draft_id, task_id, service, attempt + 1)
    else
      # Unknown status - check max attempts
      if attempt >= MAX_ATTEMPTS
        draft.update(status: 'failed')
        Rails.logger.error "SoraPollJob: Max attempts reached with unknown status for draft #{draft_id}"
        return
      end
      # Schedule next poll but log warning
      Rails.logger.warn "SoraPollJob: Unknown status '#{status_response['status']}' for draft #{draft_id}"
      SoraPollJob.perform_later(draft_id, task_id, service, attempt + 1)
    end
  end

  private

  def get_status(service, task_id)
    case service
    when 'poyo'
      begin
        PoyoService.new.task_status(task_id)
      rescue PoyoService::Error => e
        # Handle 404 "task not found" - the task may have expired or never existed
        # Return 'not_found' so the job retries instead of failing immediately
        if e.message.include?('404') || e.message.include?('Not Found') || e.message.include?('task not found')
          Rails.logger.warn "SoraPollJob: Task #{task_id} not found yet, will retry..."
          return { 'status' => 'not_found', 'error' => 'Task not found - may still be processing' }
        end
        raise
      end
    when 'openai'
      # Placeholder - will implement when OpenAI Sora becomes available
      { 'status' => 'error', 'error' => 'OpenAI Sora not yet available via API' }
    else
      begin
        PoyoService.new.task_status(task_id)
      rescue PoyoService::Error => e
        if e.message.include?('404') || e.message.include?('Not Found') || e.message.include?('task not found')
          return { 'status' => 'not_found', 'error' => 'Task not found - may still be processing' }
        end
        raise
      end
    end
  end
end
