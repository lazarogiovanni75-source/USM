# frozen_string_literal: true

# Polling job for video generation tasks (supports multiple services)
# Primary: Atlas Cloud/Seedance v1 Pro (https://api.atlascloud.ai)
# Secondary: Atlas Cloud (deprecated - fallback only)
class VideoPollJob < ApplicationJob
  queue_as :default

  MAX_ATTEMPTS = 3600 # Poll for up to 2 hours (3600 * 2 seconds)
  POLL_INTERVAL = 2.seconds

  def perform(content_item_id, task_id)
    attempt = 0

    # Get service and task_id from draft metadata if content_item_id is provided
    if content_item_id.present?
      draft = DraftContent.find(content_item_id)
      service = draft.metadata['service'] || 'atlas_cloud'
      task_id ||= draft.metadata['task_id']
    else
      service = 'atlas_cloud'
    end

    # Add delay for first few attempts to allow generation to start
    if attempt < 3
      Rails.logger.info "VideoPollJob: Waiting before poll attempt #{attempt + 1}"
      sleep(3)
    elsif attempt > 0
      sleep(2)
    end

    draft = DraftContent.find(content_item_id)

    return if draft.media_url.present?

    if task_id.blank?
      Rails.logger.error "VideoPollJob: No task_id for draft #{content_item_id}"
      draft.update(status: 'failed', metadata: draft.metadata.merge({ 'error' => 'No task ID' }))
      return
    end

    status_response = get_status(service, task_id)

    Rails.logger.info "VideoPollJob: Draft #{content_item_id}, Service #{service}, Task #{task_id}, Status: #{status_response['status']}, Output: #{status_response['output'] ? status_response['output'][0..100] : 'nil'}, Attempt: #{attempt}"

    raw_status = status_response['status']&.downcase

    if raw_status.in?(['success', 'completed', 'done', 'finished', 'ready'])
      output_url = status_response['output']
      if output_url.present?
        draft.update(
          media_url: output_url,
          status: 'draft',
          metadata: draft.metadata.merge({ 'completed_at' => Time.current.to_i })
        )

        if VideoStorageService.s3_configured?
          Rails.logger.info "VideoPollJob: Uploading video to S3 for draft #{content_item_id}..."
          success = VideoStorageService.store_video_from_url(draft, output_url)
          if success
            Rails.logger.info "VideoPollJob: Successfully uploaded video to S3 for draft #{content_item_id}"
          else
            Rails.logger.warn "VideoPollJob: Failed to upload video to S3, using external URL instead"
          end
        end

        Rails.logger.info "VideoPollJob: Draft #{content_item_id} completed successfully with video: #{output_url}"
        Rails.logger.info "VideoPollJob: VERIFIED - Saved media_url to Draft #{content_item_id}: #{draft.reload.media_url}"
      else
        draft.update(status: 'failed', metadata: draft.metadata.merge({ 'error' => 'Success but no output' }))
        Rails.logger.error "VideoPollJob: Draft #{content_item_id} succeeded but no output URL"
      end
    elsif raw_status.in?(['failed', 'error'])
      error_msg = status_response['error'] || status_response['message'] || 'Video generation failed without details'
      draft.update(status: 'failed', metadata: draft.metadata.merge({ 'error' => error_msg }))
      Rails.logger.error "VideoPollJob: Draft #{content_item_id} failed - #{error_msg} - #{status_response.inspect}"
    elsif raw_status.in?(['in_progress', 'pending', 'submitted', 'starting', 'processing'])
      if attempt >= MAX_ATTEMPTS
        draft.update(status: 'failed', metadata: draft.metadata.merge({ 'error' => 'Timed out after 2 hours' }))
        Rails.logger.error "VideoPollJob: Max attempts reached for draft #{content_item_id}"
        return
      end
      VideoPollJob.set(wait: 2.seconds).perform_later(content_item_id, task_id)
    elsif raw_status == 'not_found' || raw_status.nil?
      max_not_found_retries = 60

      if attempt >= max_not_found_retries
        error_msg = status_response['error'] || 'Task not found after multiple retries - possible invalid API key, expired task, or Atlas Cloud server issue'
        draft.update(status: 'failed', metadata: draft.metadata.merge({ 'error' => error_msg }))
        Rails.logger.error "VideoPollJob: Max not_found retries reached for draft #{content_item_id}. API key may be invalid or server may be experiencing issues."
        return
      end
      Rails.logger.warn "VideoPollJob: Task #{task_id} not found (attempt #{attempt + 1}/#{max_not_found_retries}), continuing to poll..."
      VideoPollJob.set(wait: 2.seconds).perform_later(content_item_id, task_id)
    else
      if attempt >= MAX_ATTEMPTS
        draft.update(status: 'failed', metadata: draft.metadata.merge({ 'error' => "Unknown status: #{status_response['status']}" }))
        Rails.logger.error "VideoPollJob: Max attempts reached with unknown status for draft #{content_item_id}"
        return
      end
      Rails.logger.warn "VideoPollJob: Unknown status '#{status_response['status']}' for draft #{content_item_id}"
      VideoPollJob.set(wait: 2.seconds).perform_later(content_item_id, task_id)
    end
  end

  private

  def get_status(service, task_id)
    case service
    when 'atlas_cloud', 'atlas_cloud_video'
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
