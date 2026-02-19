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

    # If already has media, nothing to do
    return if draft.media_url.present?

    # Get task_id and service from draft metadata if not provided
    task_id ||= draft.metadata['task_id']
    service ||= draft.metadata['service'] || 'poyo'
    
    if task_id.blank?
      Rails.logger.error "SoraPollJob: No task_id for draft #{draft_id}"
      draft.update(status: 'failed', metadata: draft.metadata.merge({ 'error' => 'No task ID' }))
      return
    end

    # Get status FIRST before checking max attempts
    status_response = get_status(service, task_id)

    Rails.logger.info "SoraPollJob: Draft #{draft_id}, Service #{service}, Task #{task_id}, Status: #{status_response['status']}, Output: #{status_response['output'] ? status_response['output'][0..50] : 'nil'}, Attempt: #{attempt}"

    # Check if the task has actually completed or failed
    raw_status = status_response['status']&.downcase
    
    # Handle various success status values
    if raw_status.in?(['success', 'completed', 'done', 'finished', 'ready'])
      if status_response['output'].present?
        # Update with the external URL first
        draft.update(
          media_url: status_response['output'],
          status: 'draft',
          metadata: draft.metadata.merge({ 'completed_at' => Time.current.to_i })
        )
        
        # Upload to S3 if configured
        if VideoStorageService.s3_configured?
          Rails.logger.info "SoraPollJob: Uploading video to S3 for draft #{draft_id}..."
          success = VideoStorageService.store_video_from_url(draft, status_response['output'])
          if success
            Rails.logger.info "SoraPollJob: Successfully uploaded video to S3 for draft #{draft_id}"
          else
            Rails.logger.warn "SoraPollJob: Failed to upload video to S3, using external URL instead"
          end
        end
        
        Rails.logger.info "SoraPollJob: Draft #{draft_id} completed successfully with video: #{status_response['output']}"
      else
        draft.update(status: 'failed', metadata: draft.metadata.merge({ 'error' => 'Success but no output' }))
        Rails.logger.error "SoraPollJob: Draft #{draft_id} succeeded but no output"
      end
    elsif raw_status.in?(['failed', 'error'])
      # Task has failed - mark as failed regardless of attempt count
      error_msg = status_response['error'] || status_response['message'] || 'Video generation failed without details'
      draft.update(status: 'failed', metadata: draft.metadata.merge({ 'error' => error_msg }))
      Rails.logger.error "SoraPollJob: Draft #{draft_id} failed - #{error_msg} - #{status_response.inspect}"
    elsif raw_status.in?(['in_progress', 'pending', 'submitted', 'starting', 'processing'])
      # Still processing - check if we've exceeded max attempts
      if attempt >= MAX_ATTEMPTS
        draft.update(status: 'failed', metadata: draft.metadata.merge({ 'error' => 'Timed out after 2 hours' }))
        Rails.logger.error "SoraPollJob: Max attempts reached for draft #{draft_id}"
        return
      end
      # Schedule next poll
      SoraPollJob.perform_later(draft_id, task_id, service, attempt + 1)
    elsif raw_status == 'not_found' || raw_status.nil?
      # Task not found - this can happen with APIs that use webhooks instead of polling
      # Or the API key might be invalid/expired
      # Don't fail immediately - the video may still be processing on the server
      # But limit retries significantly to avoid wasting resources
      max_not_found_retries = 10 # Only try 10 times for not_found (50 seconds)
      
      if attempt >= max_not_found_retries
        # After 10 "not found" responses, assume the task failed or API key is invalid
        error_msg = status_response['error'] || 'Task not found - possible invalid API key or expired task'
        draft.update(status: 'failed', metadata: draft.metadata.merge({ 'error' => error_msg }))
        Rails.logger.error "SoraPollJob: Max not_found retries reached for draft #{draft_id}. API key may be invalid."
        return
      end
      # Retry after delay - continue polling
      Rails.logger.warn "SoraPollJob: Task #{task_id} not found (attempt #{attempt + 1}/#{max_not_found_retries}), continuing to poll..."
      SoraPollJob.perform_later(draft_id, task_id, service, attempt + 1)
    else
      # Unknown status - check max attempts
      if attempt >= MAX_ATTEMPTS
        draft.update(status: 'failed', metadata: draft.metadata.merge({ 'error' => "Unknown status: #{status_response['status']}" }))
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
