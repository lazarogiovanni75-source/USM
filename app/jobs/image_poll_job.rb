# frozen_string_literal: true

# Polling job for image generation tasks
# Primary: Atlas Cloud/Z-Image Turbo
class ImagePollJob < ApplicationJob
  queue_as :default

  MAX_ATTEMPTS = 300
  POLL_INTERVAL = 2.seconds

  def perform(draft_id, task_id = nil, service = nil, attempt = 0)
    @draft_id = draft_id # Store for use in get_status error handling

    if attempt < 3
      Rails.logger.info "ImagePollJob: Waiting before poll attempt #{attempt + 1}"
      sleep(2)
    elsif attempt > 0
      sleep(2)
    end

    draft = DraftContent.find(draft_id)
    return if draft.media_url.present?

    if attempt >= MAX_ATTEMPTS
      draft.update(status: 'failed')
      Rails.logger.error "ImagePollJob: Max attempts reached for draft #{draft_id}"
      return
    end

    task_id ||= draft.metadata['task_id']
    service ||= draft.metadata['service'] || 'atlas_cloud_image'
    return if task_id.blank?

    if service == 'openai'
      Rails.logger.warn "ImagePollJob: OpenAI service generates synchronously, skipping poll"
      return
    end

    status_response = get_status(service, task_id)
    Rails.logger.info "ImagePollJob: Draft #{draft_id}, Service #{service}, Task #{task_id}, Status: #{status_response['status']}, Output: #{status_response['output'] ? 'present' : 'nil'}, Attempt: #{attempt}"

    raw_status = status_response['status']&.downcase

    if raw_status.in?(['success', 'completed', 'done', 'ready', 'succeeded'])
      output_url = status_response['output']
      if output_url.present?
        # Download and attach the image to ActiveStorage
        begin
          require 'open-uri'
          
          Rails.logger.info "ImagePollJob: Downloading image from #{output_url}"
          
          # Download with SSL verification disabled for Alibaba Cloud
          downloaded_file = URI.open(output_url, ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE)
          filename = "image_#{draft_id}_#{Time.current.to_i}.jpg"
          
          # Attach to ActiveStorage
          draft.media.attach(
            io: downloaded_file,
            filename: filename,
            content_type: 'image/jpeg'
          )
          
          draft.update!(status: 'draft')
          
          Rails.logger.info "ImagePollJob: Draft #{draft_id} completed - image downloaded and attached to ActiveStorage"
        rescue => e
          # Fallback: save URL if download fails
          Rails.logger.error "ImagePollJob: Failed to download image for draft #{draft_id}: #{e.class} - #{e.message}"
          Rails.logger.error e.backtrace.first(5).join("\n") if e.backtrace
          draft.update(media_url: output_url, status: 'failed')
        end
      else
        draft.update(status: 'failed')
        Rails.logger.error "ImagePollJob: Draft #{draft_id} succeeded but no output URL"
      end
    elsif raw_status.in?(['failed', 'error'])
      if attempt >= 3
        draft.update(status: 'failed')
        Rails.logger.error "ImagePollJob: Draft #{draft_id} failed - #{status_response['error']}"
      else
        ImagePollJob.set(wait: 3.seconds).perform_later(draft_id, task_id, service, attempt + 1)
      end
    elsif raw_status.in?(['in_progress', 'starting', 'pending', 'processing', 'running'])
      attempt += 1
      ImagePollJob.set(wait: 3.seconds).perform_later(draft_id, task_id, service, attempt)
    elsif raw_status == 'not_found'
      attempt += 1
      ImagePollJob.set(wait: 3.seconds).perform_later(draft_id, task_id, service, attempt)
    else
      Rails.logger.info "ImagePollJob: Unknown status '#{status_response['status']}' for draft #{draft_id}, will retry"
      attempt += 1
      ImagePollJob.set(wait: 3.seconds).perform_later(draft_id, task_id, service, attempt)
    end
  end

  private

  def get_status(service, task_id)
    draft_id = @draft_id
    case service
    when 'atlas_cloud_image', 'atlas_cloud'
      begin
        AtlasCloudImageService.new.task_status(task_id)
      rescue AtlasCloudImageService::AuthenticationError => e
        error_msg = 'Authentication failed - please check your Atlas Cloud API key'
        draft = DraftContent.find_by(id: @draft_id)
        draft&.update(status: 'failed', metadata: (draft.metadata || {}).merge({ 'error' => error_msg }))
        Rails.logger.error "ImagePollJob: Authentication error for task #{task_id}: #{e.message}"
        return { 'status' => 'failed', 'error' => error_msg }
      rescue AtlasCloudImageService::Error => e
        error_msg_lower = e.message.downcase
        if error_msg_lower.include?('insufficient credits') || error_msg_lower.include?('top up')
          error_msg = 'Insufficient credits - please top up your Atlas Cloud account'
          draft = DraftContent.find_by(id: @draft_id)
          draft&.update(status: 'failed', metadata: (draft.metadata || {}).merge({ 'error' => error_msg }))
          Rails.logger.error "ImagePollJob: Insufficient credits for task #{task_id}"
          return { 'status' => 'failed', 'error' => error_msg }
        elsif error_msg_lower.include?('server error: 500') || error_msg_lower.include?('server error: 502') ||
              error_msg_lower.include?('server error: 503') || error_msg_lower.include?('server error: 504')
          error_msg = "Atlas Cloud server error - #{e.message}"
          draft = DraftContent.find_by(id: @draft_id)
          draft&.update(status: 'failed', metadata: (draft.metadata || {}).merge({ 'error' => error_msg }))
          Rails.logger.error "ImagePollJob: Atlas Cloud server error for task #{task_id}: #{e.message}"
          return { 'status' => 'failed', 'error' => error_msg }
        elsif error_msg_lower.include?('404') || error_msg_lower.include?('not found')
          Rails.logger.warn "ImagePollJob: Task #{task_id} not found yet, will retry..."
          return { 'status' => 'not_found', 'error' => 'Task not found - may still be processing' }
        elsif error_msg_lower.include?('rate limit')
          return { 'status' => 'not_found', 'error' => e.message }
        else
          raise
        end
      end
    when 'openai'
      { 'status' => 'success', 'output' => task_id }
    else
      begin
        AtlasCloudImageService.new.task_status(task_id)
      rescue AtlasCloudImageService::Error => e
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
