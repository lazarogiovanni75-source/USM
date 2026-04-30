
# frozen_string_literal: true

# Video Generation Service
# Uses AtlasCloudService unified API (https://api.atlascloud.ai)
# Text-to-Video: POST /api/v1/model/generateVideo
# Image-to-Video: POST /api/v1/model/generateVideo (with image_url)
# Status Polling: GET /api/v1/model/prediction/{id}
class VideoGenerationService
  class VideoGenerationError < StandardError; end
  class ServiceUnavailableError < VideoGenerationError; end

  # Generate text-to-video using Google Veo 3.1 Lite
  #
  # @param prompt [String] Text prompt for video
  # @param duration [String] Video duration
  # @param aspect_ratio [String] Aspect ratio
  # @param model [String] Model to use (default: google/veo3.1-lite/text-to-video)
  # @param quality [String] Quality tier (standard, hd)
  # @return [Hash] Result with task_id and metadata
  #
  def self.generate_video(prompt:, duration: '5', aspect_ratio: '16:9', model: nil, quality: 'standard')
    # Pass model: nil to let AtlasCloudService auto-select based on prompt content
    service = AtlasCloudService.new

    unless service.configured?
      Rails.logger.warn "[VideoGeneration] Atlas Cloud not configured"
      return { success: false, error: "Atlas Cloud not configured. Please add your ATLASCLOUD_API_KEY." }
    end

    begin
      result = service.generate_video_from_text(
        prompt: prompt,
        model: model,
        duration: duration.to_i,
        aspect_ratio: aspect_ratio,
        quality: quality
      )

      if result['task_id'].present?
        Rails.logger.info "[VideoGeneration] Video generation started, task_id: #{result['task_id']}"
        {
          success: true,
          task_id: result['task_id'],
          service: 'atlas_cloud',
          metadata: { model: model, duration: duration, aspect_ratio: aspect_ratio, quality_tier: quality }
        }
      else
        Rails.logger.error "[VideoGeneration] Video generation failed: #{result.inspect}"
        { success: false, error: result['error'] || 'Failed to start video generation' }
      end
    rescue => e
      Rails.logger.error "[VideoGeneration] Video generation error: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # Generate video from an existing image using Google Veo 3.1 Lite
  #
  # @param image_url [String] URL of source image
  # @param prompt [String] Optional prompt to guide the video
  # @param duration [String] Video duration
  # @param aspect_ratio [String] Aspect ratio
  # @param model [String] Model to use (default: google/veo3.1-lite/image-to-video)
  # @param quality [String] Quality tier (standard, hd)
  # @return [Hash] Result with task_id and metadata
  #
  def self.generate_video_from_image(image_url:, prompt: '', duration: '5', aspect_ratio: '16:9', model: nil, quality: 'standard')
    model ||= 'google/veo3.1-lite/image-to-video'
    
    service = AtlasCloudService.new

    unless service.configured?
      Rails.logger.warn "[VideoGeneration] Atlas Cloud not configured"
      return { success: false, error: "Atlas Cloud not configured. Please add your ATLASCLOUD_API_KEY." }
    end

    begin
      result = service.generate_video_from_image(
        image_url: image_url,
        prompt: prompt,
        model: model,
        aspect_ratio: aspect_ratio,
        duration: duration.to_i,
        quality: quality
      )

      if result['task_id'].present?
        Rails.logger.info "[VideoGeneration] Image-to-video started, task_id: #{result['task_id']}"
        {
          success: true,
          task_id: result['task_id'],
          service: 'atlas_cloud',
          metadata: { 
            model: model, 
            duration: duration, 
            aspect_ratio: aspect_ratio,
            source_image: image_url,
            quality_tier: quality
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

  # Generate video from start and end frames using Google Veo 3.1 Lite
  #
  # @param start_image_url [String] URL of the start frame
  # @param end_image_url [String] URL of the end frame
  # @param prompt [String] Optional prompt to guide the video
  # @param duration [String] Video duration
  # @param aspect_ratio [String] Aspect ratio
  # @param model [String] Model to use (default: google/veo3.1-lite/start-end-frame-to-video)
  # @param quality [String] Quality tier (standard, hd)
  # @return [Hash] Result with task_id and metadata
  #
  def self.generate_video_from_start_end_frames(start_image_url:, end_image_url:, prompt: '', duration: '5', aspect_ratio: '16:9', model: nil, quality: 'standard')
    model ||= 'google/veo3.1-lite/start-end-frame-to-video'
    
    service = AtlasCloudService.new

    unless service.configured?
      Rails.logger.warn "[VideoGeneration] Atlas Cloud not configured"
      return { success: false, error: "Atlas Cloud not configured. Please add your ATLASCLOUD_API_KEY." }
    end

    begin
      result = service.generate_video_from_start_end_frames(
        start_image_url: start_image_url,
        end_image_url: end_image_url,
        prompt: prompt,
        model: model,
        aspect_ratio: aspect_ratio,
        duration: duration.to_i,
        quality: quality
      )

      if result['task_id'].present?
        Rails.logger.info "[VideoGeneration] Start-end-frame-to-video started, task_id: #{result['task_id']}"
        {
          success: true,
          task_id: result['task_id'],
          service: 'atlas_cloud',
          metadata: {
            model: model,
            duration: duration,
            aspect_ratio: aspect_ratio,
            start_image_url: start_image_url,
            end_image_url: end_image_url,
            quality_tier: quality
          }
        }
      else
        Rails.logger.error "[VideoGeneration] Start-end-frame-to-video failed: #{result.inspect}"
        { success: false, error: result['error'] || 'Failed to start video generation' }
      end
    rescue => e
      Rails.logger.error "[VideoGeneration] Start-end-frame-to-video error: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # Get video task status
  def self.get_status(task_id, service: nil)
    AtlasCloudService.new.task_status(task_id)
  end
end
