# frozen_string_literal: true

# Polling job for video generation tasks (supports multiple services)
# Primary: Atlas Cloud/Google Veo 3.1 Lite (https://api.atlascloud.ai)
# Secondary: Atlas Cloud (deprecated - fallback only)
class VideoPollJob < ApplicationJob
  queue_as :default

  MAX_ATTEMPTS = 3600 # Poll for up to 2 hours (3600 * 2 seconds)
  POLL_INTERVAL = 2.seconds

  def perform(content_item_id, task_id, attempt = 0)
    @content_item_id = content_item_id

    # Add delay for first few attempts to allow generation to start
    if attempt < 3
      Rails.logger.info "VideoPollJob: Waiting before poll attempt #{attempt + 1}"
      sleep(3)
    elsif attempt > 0
      sleep(2)
    end

    draft = DraftContent.find(content_item_id)

    return if draft.media_url.present? && draft.status == 'draft'

    if task_id.blank?
      task_id = draft.metadata['task_id']
    end
    
    if task_id.blank?
      draft.update(status: 'failed', metadata: draft.metadata.merge({ 'error' => 'No task ID' }))
      return
    end

    service = draft.metadata['service'] || 'atlas_cloud'
    status_response = get_status(service, task_id, content_item_id)

    Rails.logger.info "VideoPollJob: Draft #{content_item_id}, Service #{service}, Task #{task_id}, Status: #{status_response['status']}, Output: #{status_response['output'] ? status_response['output'][0..100] : 'nil'}, Attempt: #{attempt}"

    raw_status = status_response['status']&.downcase

    if raw_status.in?(['success', 'completed', 'done', 'finished', 'ready', 'succeeded'])
      output_url = status_response['output']
      
      # Try alternative URL sources if primary output is nil
      if output_url.blank?
        output_url = draft.metadata['output_url'] || 
                     draft.metadata['video_url'] ||
                     draft.metadata['result_url'] ||
                     draft.metadata.dig('result', 'video_url') ||
                     draft.metadata.dig('result', 'url')
      end
      
      if output_url.present?
        # Simply save the URL directly - like the original working code
        draft.update(
          media_url: output_url,
          status: 'draft',
          metadata: draft.metadata.merge({ 'completed_at' => Time.current.to_i })
        )
        Rails.logger.info "VideoPollJob: Draft #{content_item_id} completed - saved media_url: #{output_url[0..80]}..."
      else
        if attempt >= 10
          draft.update(
            status: 'failed',
            metadata: draft.metadata.merge({ 'error' => 'Video completed but no output URL received' })
          )
        else
          VideoPollJob.set(wait: 3.seconds).perform_later(content_item_id, task_id, attempt + 1)
        end
      end
    elsif raw_status.in?(['failed', 'error'])
      error_msg = status_response['error'] || status_response['message'] || 'Video generation failed'
      draft.update(status: 'failed', metadata: draft.metadata.merge({ 'error' => error_msg }))
      Rails.logger.error "VideoPollJob: Draft #{content_item_id} failed - #{error_msg}"
    elsif raw_status.in?(['in_progress', 'pending', 'submitted', 'starting', 'processing'])
      if attempt >= MAX_ATTEMPTS
        draft.update(status: 'failed', metadata: draft.metadata.merge({ 'error' => 'Timed out after 2 hours' }))
        return
      end
      VideoPollJob.set(wait: 2.seconds).perform_later(content_item_id, task_id, attempt + 1)
    elsif raw_status == 'retry'
      max_retry_attempts = 30
      if attempt >= max_retry_attempts
        error_msg = status_response['error'] || 'Atlas Cloud server error after multiple retries'
        draft.update(status: 'failed', metadata: draft.metadata.merge({ 'error' => error_msg }))
        return
      end
      VideoPollJob.set(wait: 5.seconds).perform_later(content_item_id, task_id, attempt + 1)
    elsif raw_status == 'not_found' || raw_status.nil?
      max_not_found_retries = 60
      if attempt >= max_not_found_retries
        error_msg = 'Task not found after multiple retries - possible invalid API key or Atlas Cloud server issue'
        draft.update(status: 'failed', metadata: draft.metadata.merge({ 'error' => error_msg }))
        return
      end
      VideoPollJob.set(wait: 2.seconds).perform_later(content_item_id, task_id, attempt + 1)
    else
      if attempt >= MAX_ATTEMPTS
        draft.update(status: 'failed', metadata: draft.metadata.merge({ 'error' => "Unknown status: #{status_response['status']}" }))
        return
      end
      VideoPollJob.set(wait: 2.seconds).perform_later(content_item_id, task_id, attempt + 1)
    end
  end

  private

  def get_status(service, task_id, content_item_id = nil)
    @content_item_id ||= content_item_id
    case service
    when 'atlas_cloud', 'atlas_cloud_video'
      begin
        AtlasCloudService.new.task_status(task_id)
      rescue AtlasCloudService::AuthenticationError => e
        error_msg = 'Authentication failed - please check your Atlas Cloud API key'
        draft = DraftContent.find_by(id: @content_item_id)
        draft&.update(status: 'failed', metadata: (draft.metadata || {}).merge({ 'error' => error_msg }))
        return { 'status' => 'failed', 'error' => error_msg }
      rescue AtlasCloudService::Error => e
        error_msg_lower = e.message.downcase
        if error_msg_lower.include?('insufficient credits') || error_msg_lower.include?('top up')
          error_msg = 'Insufficient credits - please top up your Atlas Cloud account'
          draft = DraftContent.find_by(id: @content_item_id)
          draft&.update(status: 'failed', metadata: (draft.metadata || {}).merge({ 'error' => error_msg }))
          return { 'status' => 'failed', 'error' => error_msg }
        elsif error_msg_lower.include?('server error: 500') || error_msg_lower.include?('server error: 502') ||
              error_msg_lower.include?('server error: 503') || error_msg_lower.include?('server error: 504')
          return { 'status' => 'retry', 'error' => e.message }
        elsif error_msg_lower.include?('404') || error_msg_lower.include?('not found')
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
        if error_msg_lower.include?('404') || error_msg_lower.include?('not found')
          return { 'status' => 'not_found', 'error' => e.message }
        else
          raise
        end
      end
    end
  end
end
