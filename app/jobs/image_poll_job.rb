# frozen_string_literal: true

# Polling job for image generation tasks
# Primary: Atlas Cloud/Z-Image Turbo
class ImagePollJob < ApplicationJob
  queue_as :default

  MAX_ATTEMPTS = 300
  POLL_INTERVAL = 2.seconds

  def perform(draft_id, task_id = nil, service = nil, attempt = 0)
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
        draft.update(media_url: output_url, status: 'draft')
        Rails.logger.info "ImagePollJob: Draft #{draft_id} completed successfully with URL: #{output_url}"
        Rails.logger.info "ImagePollJob: VERIFIED - Saved media_url to Draft #{draft_id}: #{draft.reload.media_url}"
      else
        draft.update(status: 'failed')
        Rails.logger.error "ImagePollJob: Draft #{draft_id} succeeded but no output URL"
      end
    elsif raw_status.in?(['failed', 'error'])
      if @attempt >= 3
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
    case service
    when 'atlas_cloud_image', 'atlas_cloud'
      begin
        AtlasCloudImageService.new.task_status(task_id)
      rescue AtlasCloudImageService::Error => e
        if e.message.include?('404') || e.message.include?('not found')
          Rails.logger.warn "ImagePollJob: Task #{task_id} not found yet, will retry..."
          return { 'status' => 'not_found', 'error' => 'Task not found - may still be processing' }
        end
        raise
      end
    when 'openai'
      { 'status' => 'success', 'output' => task_id }
    else
      begin
        AtlasCloudImageService.new.task_status(task_id)
      rescue AtlasCloudImageService::Error => e
        if e.message.include?('404') || e.message.include?('not found')
          return { 'status' => 'not_found', 'error' => 'Task not found - may still be processing' }
        end
        raise
      end
    end
  end
end
