# frozen_string_literal: true

# Polling job for image generation tasks
# Primary: Atlas Cloud/Z-Image Turbo
class ImagePollJob < ApplicationJob
  queue_as :default

  MAX_ATTEMPTS = 300
  POLL_INTERVAL = 2.seconds

  def perform(draft_id, task_id = nil, service = nil, attempt = 0)
    @draft_id = draft_id

    if attempt < 3
      Rails.logger.info "ImagePollJob: Waiting before poll attempt #{attempt + 1}"
      sleep(2)
    elsif attempt > 0
      sleep(2)
    end

    draft = DraftContent.find(draft_id)
    return if draft.media_url.present? && draft.status == 'draft'

    if attempt >= MAX_ATTEMPTS
      draft.update(status: 'failed', metadata: (draft.metadata || {}).merge({ 'error' => 'Max polling attempts reached' }))
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
      
      # Try alternative URL sources if primary output is nil
      if output_url.blank?
        output_url = draft.metadata['output_url'] || 
                     draft.metadata['image_url'] ||
                     draft.metadata['result_url'] ||
                     draft.metadata.dig('result', 'image_url') ||
                     draft.metadata.dig('result', 'url')
      end
      
      if output_url.present?
        # Simply save the URL directly - like the original working code
        draft.update(
          media_url: output_url,
          status: 'draft',
          metadata: (draft.metadata || {}).merge({ 'completed_at' => Time.current.to_i })
        )
        Rails.logger.info "ImagePollJob: Draft #{draft_id} completed - saved media_url: #{output_url[0..80]}..."
      else
        if attempt >= 5
          draft.update(status: 'failed', metadata: (draft.metadata || {}).merge({ 'error' => 'Image completed but no output URL' }))
        else
          ImagePollJob.set(wait: 3.seconds).perform_later(draft_id, task_id, service, attempt + 1)
        end
      end
    elsif raw_status.in?(['failed', 'error'])
      error_msg = status_response['error'] || 'Image generation failed'
      draft.update(
        status: 'failed',
        metadata: (draft.metadata || {}).merge({ 'error' => error_msg })
      )
      Rails.logger.error "ImagePollJob: Draft #{draft_id} failed - #{error_msg}"
    elsif raw_status.in?(['in_progress', 'starting', 'pending', 'processing', 'running'])
      attempt += 1
      ImagePollJob.set(wait: 3.seconds).perform_later(draft_id, task_id, service, attempt)
    elsif raw_status == 'not_found'
      attempt += 1
      ImagePollJob.set(wait: 3.seconds).perform_later(draft_id, task_id, service, attempt)
    else
      attempt += 1
      ImagePollJob.set(wait: 3.seconds).perform_later(draft_id, task_id, service, attempt)
    end
  end

  private

  def get_status(service, task_id)
    case service
    when 'atlas_cloud_image', 'atlas_cloud'
      begin
        AtlasCloudImageService.new.task_status(task_id)
      rescue AtlasCloudImageService::AuthenticationError => e
        error_msg = 'Authentication failed - please check your Atlas Cloud API key'
        draft = DraftContent.find_by(id: @draft_id)
        draft&.update(status: 'failed', metadata: (draft.metadata || {}).merge({ 'error' => error_msg }))
        return { 'status' => 'failed', 'error' => error_msg }
      rescue AtlasCloudImageService::Error => e
        error_msg_lower = e.message.downcase
        if error_msg_lower.include?('insufficient credits') || error_msg_lower.include?('top up')
          error_msg = 'Insufficient credits - please top up your Atlas Cloud account'
          draft = DraftContent.find_by(id: @draft_id)
          draft&.update(status: 'failed', metadata: (draft.metadata || {}).merge({ 'error' => error_msg }))
          return { 'status' => 'failed', 'error' => error_msg }
        elsif error_msg_lower.include?('server error: 500') || error_msg_lower.include?('server error: 502') ||
              error_msg_lower.include?('server error: 503') || error_msg_lower.include?('server error: 504')
          error_msg = "Atlas Cloud server error - #{e.message}"
          draft = DraftContent.find_by(id: @draft_id)
          draft&.update(status: 'failed', metadata: (draft.metadata || {}).merge({ 'error' => error_msg }))
          return { 'status' => 'failed', 'error' => error_msg }
        elsif error_msg_lower.include?('404') || error_msg_lower.include?('not found')
          return { 'status' => 'not_found', 'error' => 'Task not found - may still be processing' }
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
        if error_msg_lower.include?('404') || error_msg_lower.include?('not found')
          return { 'status' => 'not_found', 'error' => e.message }
        else
          raise
        end
      end
    end
  end
end
