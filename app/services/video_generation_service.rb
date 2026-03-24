
# frozen_string_literal: true

# Video Generation Service
# Uses AtlasCloudService unified API (https://api.atlascloud.ai)
# Text-to-Video: POST /api/v1/model/generateVideo
# Image-to-Video: POST /api/v1/model/generateVideo (with image_url)
# Status Polling: GET /api/v1/model/prediction/{id}
class VideoGenerationService
  class VideoGenerationError < StandardError; end
  class ServiceUnavailableError < VideoGenerationError; end

  # Generate video with primary/secondary fallback
  #
  # @param prompt [String] Text prompt for video
  # @param duration [String] Video duration
  # @param aspect_ratio [String] Aspect ratio
  # @param model [String] Model to use (default: atlascloud/magi-1-24b)
  # @return [Hash] Result with task_id and metadata
  #
  def self.generate_video(prompt:, duration: '5', aspect_ratio: '16:9', model: nil)
    # Try primary service (Atlas Cloud unified API)
    result = try_primary_video(prompt: prompt, duration: duration, aspect_ratio: aspect_ratio, model: model)
    return result if result[:success]

    # Try secondary service (Atlas Cloud with alternative model)
    result = try_secondary_video(prompt: prompt, duration: duration, aspect_ratio: aspect_ratio)
    return result if result[:success]

    # Both services failed
    raise ServiceUnavailableError, "Video generation services unavailable. Please check your ATLASCLOUD_API_KEY configuration."
  end

  # Generate video from an existing image
  #
  # @param image_url [String] URL of source image
  # @param prompt [String] Optional prompt to guide the video
  # @param duration [String] Video duration
  # @param aspect_ratio [String] Aspect ratio
  # @param model [String] Model to use
  # @return [Hash] Result with task_id and metadata
  #
  def self.generate_video_from_image(image_url:, prompt: '', duration: '5', aspect_ratio: '16:9', model: nil)
    service = AtlasCloudService.new

    unless service.configured?
      Rails.logger.warn "[VideoGeneration] Atlas Cloud not configured"
      return { success: false, error: "Atlas Cloud not configured. Please add your ATLASCLOUD_API_KEY." }
    end

    begin
      result = service.generate_video_from_image(
        image_url: image_url,
        prompt: prompt,
        model: model || 'atlascloud/magi-1-24b',
        aspect_ratio: aspect_ratio,
        duration: duration.to_i
      )

      if result['task_id'].present?
        Rails.logger.info "[VideoGeneration] Image-to-video started, task_id: #{result['task_id']}"
        {
          success: true,
          task_id: result['task_id'],
          service: 'atlas_cloud',
          metadata: { 
            model: model || 'atlascloud/magi-1-24b', 
            duration: duration, 
            aspect_ratio: aspect_ratio,
            source_image: image_url
          }
        }
      else
        Rails.logger.error "[VideoGeneration] Image-to-video failed: #{result.inspect}"
        { success: false, error: result['error'] || 'Failed to start video generation' }
      end
    rescue => e
      Rails.logger.error "[VideoGeneration] Image-to-video error: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # Get video task status
  def self.get_status(task_id, service: nil)
    service_obj = service_to_object(service)
    service_obj.task_status(task_id)
  end

  private

  def self.try_primary_video(prompt:, duration:, aspect_ratio:, model: nil)
    Rails.logger.info "[VideoGeneration] Trying Atlas Cloud unified API (model: #{model || 'atlascloud/magi-1-24b'})"

    service = AtlasCloudService.new

    unless service.configured?
      Rails.logger.warn "[VideoGeneration] Atlas Cloud not configured"
      return { success: false, error: "Atlas Cloud not configured. Please add your ATLASCLOUD_API_KEY." }
    end

    begin
      result = service.generate_video_from_text(
        prompt: prompt,
        model: model || 'atlascloud/magi-1-24b',
        duration: duration.to_i,
        aspect_ratio: aspect_ratio
      )

      if result['task_id'].present?
        Rails.logger.info "[VideoGeneration] Primary service succeeded - task_id: #{result['task_id']}"
        {
          success: true,
          task_id: result['task_id'],
          service: 'atlas_cloud',
          metadata: { model: model || 'atlascloud/magi-1-24b', duration: duration, aspect_ratio: aspect_ratio }
        }
      else
        Rails.logger.error "[VideoGeneration] Primary service returned no task_id. Full response: #{result.inspect}"
        { success: false, error: result['error'] || result['message'] || 'Failed to start generation - no task_id returned' }
      end
    rescue AtlasCloudService::AuthenticationError => e
      Rails.logger.error "[VideoGeneration] Authentication error: #{e.message}"
      { success: false, error: "Atlas Cloud API key is invalid. Please check your configuration." }
    rescue AtlasCloudService::Error => e
      Rails.logger.error "[VideoGeneration] Primary service error: #{e.message}"
      { success: false, error: e.message }
    rescue => e
      Rails.logger.error "[VideoGeneration] Primary service unexpected error: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def self.try_secondary_video(prompt:, duration:, aspect_ratio:)
    Rails.logger.info "[VideoGeneration] Trying Atlas Cloud with alternative model (vidu/q3-pro/text-to-video)"

    service = AtlasCloudService.new

    unless service.configured?
      Rails.logger.warn "[VideoGeneration] Atlas Cloud not configured for fallback"
      return { success: false, error: "Atlas Cloud not configured" }
    end

    begin
      result = service.generate_video_from_text(
        prompt: prompt,
        model: 'vidu/q3-pro/text-to-video',
        duration: duration.to_i,
        aspect_ratio: aspect_ratio
      )

      if result['task_id'].present?
        Rails.logger.info "[VideoGeneration] Secondary service succeeded - task_id: #{result['task_id']}"
        {
          success: true,
          task_id: result['task_id'],
          service: 'atlas_cloud',
          metadata: { model: 'vidu/q3-pro/text-to-video', duration: duration, aspect_ratio: aspect_ratio }
        }
      else
        Rails.logger.error "[VideoGeneration] Secondary service returned no task_id. Full response: #{result.inspect}"
        { success: false, error: result['error'] || result['message'] || 'Failed to start generation' }
      end
    rescue => e
      Rails.logger.error "[VideoGeneration] Secondary service error: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def self.service_to_object(service_name)
    case service_name
    when 'atlas_cloud'
      AtlasCloudService.new
    else
      AtlasCloudService.new
    end
  end
end
