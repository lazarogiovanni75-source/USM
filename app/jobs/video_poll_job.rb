# frozen_string_literal: true

# Polling job for video generation tasks (supports multiple services)
# Primary: Atlas Cloud/Seedance v1 Pro (https://api.atlascloud.ai)
# Secondary: Atlas Cloud (deprecated - fallback only)
class VideoPollJob < ApplicationJob
  queue_as :default

  MAX_ATTEMPTS = 3600 # Poll for up to 2 hours (3600 * 2 seconds)
  POLL_INTERVAL = 2.seconds

  def perform(content_item_id, task_id, attempt = 0)
    @content_item_id = content_item_id # Store for use in get_status error handling

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

    status_response = get_status(service, task_id, content_item_id)

    Rails.logger.info "VideoPollJob: Draft #{content_item_id}, Service #{service}, Task #{task_id}, Status: #{status_response['status']}, Output: #{status_response['output'] ? status_response['output'][0..100] : 'nil'}, Attempt: #{attempt}"

    raw_status = status_response['status']&.downcase

    if raw_status.in?(['success', 'completed', 'done', 'finished', 'ready', 'succeeded'])
      output_url = status_response['output']
      if output_url.present?
        # Download and attach the video to ActiveStorage
        begin
          require 'open-uri'
          video_file = URI.open(output_url)
          filename = "video_#{content_item_id}_#{Time.current.to_i}.mp4"
          
          draft.media.attach(io: video_file, filename: filename, content_type: 'video/mp4')
          draft.update!(
            status: 'draft',
            metadata: draft.metadata.merge({ 'completed_at' => Time.current.to_i })
          )

          Rails.logger.info "VideoPollJob: Draft #{content_item_id} completed - video downloaded and attached to ActiveStorage"

          # Apply text overlay if configured
          if draft.metadata['overlay_text'].present?
            Rails.logger.info "VideoPollJob: Applying text overlay for draft #{content_item_id}..."
            VideoOverlayService.apply_overlay(draft)
            draft.reload
          end
        rescue => e
          # Fallback: save URL if download fails
          Rails.logger.warn "VideoPollJob: Failed to download video for draft #{content_item_id}: #{e.message}. Saving URL instead."
          draft.update(
            media_url: output_url,
            status: 'draft',
            metadata: draft.metadata.merge({ 'completed_at' => Time.current.to_i })
          )

          # Still try to apply overlay even if download failed
          if draft.metadata['overlay_text'].present?
            Rails.logger.info "VideoPollJob: Applying text overlay for draft #{content_item_id}..."
            VideoOverlayService.apply_overlay(draft)
            draft.reload
          end
        end
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
      VideoPollJob.set(wait: 2.seconds).perform_later(content_item_id, task_id, attempt + 1)
    elsif raw_status == 'not_found' || raw_status.nil?
      max_not_found_retries = 60

      if attempt >= max_not_found_retries
        error_msg = status_response['error'] || 'Task not found after multiple retries - possible invalid API key, expired task, or Atlas Cloud server issue'
        draft.update(status: 'failed', metadata: draft.metadata.merge({ 'error' => error_msg }))
        Rails.logger.error "VideoPollJob: Max not_found retries reached for draft #{content_item_id}. API key may be invalid or server may be experiencing issues."
        return
      end
      Rails.logger.warn "VideoPollJob: Task #{task_id} not found (attempt #{attempt + 1}/#{max_not_found_retries}), continuing to poll..."
      VideoPollJob.set(wait: 2.seconds).perform_later(content_item_id, task_id, attempt + 1)
    else
      if attempt >= MAX_ATTEMPTS
        draft.update(status: 'failed', metadata: draft.metadata.merge({ 'error' => "Unknown status: #{status_response['status']}" }))
        Rails.logger.error "VideoPollJob: Max attempts reached with unknown status for draft #{content_item_id}"
        return
      end
      Rails.logger.warn "VideoPollJob: Unknown status '#{status_response['status']}' for draft #{content_item_id}"
      VideoPollJob.set(wait: 2.seconds).perform_later(content_item_id, task_id, attempt + 1)
    end
  end

  private

  def get_status(service, task_id, content_item_id = nil)
    @content_item_id ||= content_item_id # Ensure instance var is set
    case service
    when 'atlas_cloud', 'atlas_cloud_video'
      begin
        AtlasCloudService.new.task_status(task_id)
      rescue AtlasCloudService::AuthenticationError => e
        error_msg = 'Authentication failed - please check your Atlas Cloud API key'
        draft = DraftContent.find_by(id: @content_item_id) if defined?(@content_item_id)
        draft&.update(status: 'failed', metadata: (draft.metadata || {}).merge({ 'error' => error_msg })) if defined?(@content_item_id)
        Rails.logger.error "VideoPollJob: Authentication error for task #{task_id}: #{e.message}"
        return { 'status' => 'failed', 'error' => error_msg }
      rescue AtlasCloudService::Error => e
        error_msg_lower = e.message.downcase
        if error_msg_lower.include?('insufficient credits') || error_msg_lower.include?('top up')
          error_msg = 'Insufficient credits - please top up your Atlas Cloud account'
          draft = DraftContent.find_by(id: @content_item_id) if defined?(@content_item_id)
          draft&.update(status: 'failed', metadata: (draft.metadata || {}).merge({ 'error' => error_msg })) if defined?(@content_item_id)
          Rails.logger.error "VideoPollJob: Insufficient credits for task #{task_id}"
          return { 'status' => 'failed', 'error' => error_msg }
        elsif error_msg_lower.include?('server error: 500') || error_msg_lower.include?('server error: 502') ||
              error_msg_lower.include?('server error: 503') || error_msg_lower.include?('server error: 504')
          error_msg = "Atlas Cloud server error - #{e.message}"
          draft = DraftContent.find_by(id: @content_item_id) if defined?(@content_item_id)
          draft&.update(status: 'failed', metadata: (draft.metadata || {}).merge({ 'error' => error_msg })) if defined?(@content_item_id)
          Rails.logger.error "VideoPollJob: Atlas Cloud server error for task #{task_id}: #{e.message}"
          return { 'status' => 'failed', 'error' => error_msg }
        elsif error_msg_lower.include?('404') || error_msg_lower.include?('not found')
          return { 'status' => 'not_found', 'error' => e.message }
        elsif error_msg_lower.include?('rate limit')
          # Retry rate limit errors
          return { 'status' => 'not_found', 'error' => e.message }
        else
          raise
        end
      end
    else
      begin
        AtlasCloudService.new.task_status(task_id)
      rescue AtlasCloudService::Error => e
        error_msg_lower = e.message.downcase
        if error_msg_lower.include?('insufficient credits') || error_msg_lower.include?('top up') ||
           error_msg_lower.include?('server error: 500') || error_msg_lower.include?('server error: 502') ||
           error_msg_lower.include?('server error: 503') || error_msg_lower.include?('server error: 504')
          return { 'status' => 'failed', 'error' => e.message }
        elsif error_msg_lower.include?('404') || error_msg_lower.include?('not found') ||
              error_msg_lower.include?('rate limit') || error_msg_lower.include?('connection error') ||
              error_msg_lower.include?('timeout')
          return { 'status' => 'not_found', 'error' => e.message }
        else
          raise
        end
      end
    end
  end
end
