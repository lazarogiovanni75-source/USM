# frozen_string_literal: true

# Polling job for video generation tasks (supports multiple services)
# Primary: Atlas Cloud/Seedance v1 Pro (https://api.atlascloud.ai)
# Secondary: Atlas Cloud (deprecated - fallback only)
class VideoPollJob < ApplicationJob
  queue_as :default

  MAX_ATTEMPTS = 3600 # Poll for up to 2 hours (3600 * 2 seconds)
  POLL_INTERVAL = 2.seconds

  def perform(draft_id, task_id = nil, service = nil, attempt = 0)
    # Add delay for first few attempts to allow generation to start
    # In inline mode, jobs run immediately, so we need to wait for the API
    if attempt < 3
      Rails.logger.info "VideoPollJob: Waiting before poll attempt #{attempt + 1}"
      sleep(3)
    elsif attempt > 0
      # Wait 2 seconds between polls as per Atlas Cloud async polling spec
      sleep(2)
    end

    draft = DraftContent.find(draft_id)

    # If already has media, nothing to do
    return if draft.media_url.present?

    # Get task_id and service from draft metadata if not provided
    task_id ||= draft.metadata['task_id']
    service ||= draft.metadata['service'] || 'atlas_cloud'
    
    if task_id.blank?
      Rails.logger.error "VideoPollJob: No task_id for draft #{draft_id}"
      draft.update(status: 'failed', metadata: draft.metadata.merge({ 'error' => 'No task ID' }))
      return
    end

    # Get status FIRST before checking max attempts
    status_response = get_status(service, task_id)

    Rails.logger.info "VideoPollJob: Draft #{draft_id}, Service #{service}, Task #{task_id}, Status: #{status_response['status']}, Output: #{status_response['output'] ? status_response['output'][0..50] : 'nil'}, Attempt: #{attempt}"

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
          Rails.logger.info "VideoPollJob: Uploading video to S3 for draft #{draft_id}..."
          success = VideoStorageService.store_video_from_url(draft, status_response['output'])
          if success
            Rails.logger.info "VideoPollJob: Successfully uploaded video to S3 for draft #{draft_id}"
          else
            Rails.logger.warn "VideoPollJob: Failed to upload video to S3, using external URL instead"
          end
        end
        
        Rails.logger.info "VideoPollJob: Draft #{draft_id} completed successfully with video: #{status_response['output']}"
      else
        draft.update(status: 'failed', metadata: draft.metadata.merge({ 'error' => 'Success but no output' }))
        Rails.logger.error "VideoPollJob: Draft #{draft_id} succeeded but no output"
      end
    elsif raw_status.in?(['failed', 'error'])
      # Task has failed - mark as failed regardless of attempt count
      error_msg = status_response['error'] || status_response['message'] || 'Video generation failed without details'
      draft.update(status: 'failed', metadata: draft.metadata.merge({ 'error' => error_msg }))
      Rails.logger.error "VideoPollJob: Draft #{draft_id} failed - #{error_msg} - #{status_response.inspect}"
    elsif raw_status.in?(['in_progress', 'pending', 'submitted', 'starting', 'processing'])
      # Still processing - check if we've exceeded max attempts
      if attempt >= MAX_ATTEMPTS
        draft.update(status: 'failed', metadata: draft.metadata.merge({ 'error' => 'Timed out after 2 hours' }))
        Rails.logger.error "VideoPollJob: Max attempts reached for draft #{draft_id}"
        return
      end
      # Schedule next poll
      VideoPollJob.perform_later(draft_id, task_id, service, attempt + 1)
    elsif raw_status == 'not_found' || raw_status.nil?
      # Task not found or temporary error - this can happen with APIs that use webhooks instead of polling
      # Or the API key might be invalid/expired, or Atlas Cloud may have a temporary issue
      # Don't fail immediately - the video may still be processing on the server
      # Allow more retries for temporary server errors
      max_not_found_retries = 60 # Try 60 times (about 5 minutes) for not_found/temporary errors
      
      if attempt >= max_not_found_retries
        # After multiple retries, assume the task failed or API key is invalid
        error_msg = status_response['error'] || 'Task not found after multiple retries - possible invalid API key, expired task, or Atlas Cloud server issue'
        draft.update(status: 'failed', metadata: draft.metadata.merge({ 'error' => error_msg }))
        Rails.logger.error "VideoPollJob: Max not_found retries reached for draft #{draft_id}. API key may be invalid or server may be experiencing issues."
        return
      end
      # Retry after delay - continue polling
      Rails.logger.warn "VideoPollJob: Task #{task_id} not found (attempt #{attempt + 1}/#{max_not_found_retries}), continuing to poll..."
      VideoPollJob.perform_later(draft_id, task_id, service, attempt + 1)
    else
      # Unknown status - check max attempts
      if attempt >= MAX_ATTEMPTS
        draft.update(status: 'failed', metadata: draft.metadata.merge({ 'error' => "Unknown status: #{status_response['status']}" }))
        Rails.logger.error "VideoPollJob: Max attempts reached with unknown status for draft #{draft_id}"
        return
      end
      # Schedule next poll but log warning
      Rails.logger.warn "VideoPollJob: Unknown status '#{status_response['status']}' for draft #{draft_id}"
      VideoPollJob.perform_later(draft_id, task_id, service, attempt + 1)
    end
  end

  private

  def get_status(service, task_id)
    case service
    when 'atlas_cloud', 'atlas_cloud_video'
      begin
        AtlasCloudService.new.task_status(task_id)
      rescue AtlasCloudService::Error => e
        # Handle various API errors that should trigger a retry
        error_msg = e.message.downcase
        if error_msg.include?('404') || error_msg.include?('not found') || 
           error_msg.include?('server error: 500') || error_msg.include?('server error: 502') ||
           error_msg.include?('server error: 503') || error_msg.include?('server error: 504') ||
           error_msg.include?('connection error') || error_msg.include?('timeout')
          Rails.logger.warn "VideoPollJob: Task #{task_id} got temporary error '#{e.message}', will retry..."
          return { 'status' => 'not_found', 'error' => e.message }
        end
        raise
      end
    else
      begin
        AtlasCloudService.new.task_status(task_id)
      rescue AtlasCloudService::Error => e
        error_msg = e.message.downcase
        if error_msg.include?('404') || error_msg.include?('not found') || 
           error_msg.include?('server error: 500') || error_msg.include?('server error: 502') ||
           error_msg.include?('server error: 503') || error_msg.include?('server error: 504') ||
           error_msg.include?('connection error') || error_msg.include?('timeout')
          Rails.logger.warn "VideoPollJob: Task #{task_id} got temporary error '#{e.message}', will retry..."
          return { 'status' => 'not_found', 'error' => e.message }
        end
        raise
      end
    end
  end
end
