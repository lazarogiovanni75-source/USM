# frozen_string_literal: true

# Video Generation Service with Primary/Secondary Fallback
# Primary: Atlas Cloud/Seedance v1 Pro (https://api.atlascloud.ai)
# Secondary: Atlas Cloud (deprecated - fallback only)
class VideoGenerationService
  class VideoGenerationError < StandardError; end
  class ServiceUnavailableError < VideoGenerationError; end

  # Generate video with primary/secondary fallback
  #
  # @param prompt [String] Text prompt for video
  # @param duration [String] Video duration
  # @param aspect_ratio [String] Aspect ratio
  # @return [Hash] Result with task_id and metadata
  #
  def self.generate_video(prompt:, duration: '10', aspect_ratio: '16:9')
    # Try primary service (Atlas Cloud)
    result = try_primary_video(prompt: prompt, duration: duration, aspect_ratio: aspect_ratio)
    return result if result[:success]

    # Try secondary service (Atlas Cloud - fallback)
    result = try_secondary_video(prompt: prompt, duration: duration, aspect_ratio: aspect_ratio)
    return result if result[:success]

    # Both services failed
    raise ServiceUnavailableError, "Video generation services unavailable. Primary: Atlas Cloud failed. Secondary: Atlas Cloud not configured or failed."
  end

  # Get video task status
  def self.get_status(task_id, service: nil)
    service_obj = service_to_object(service)
    service_obj.task_status(task_id)
  end

  private

  def self.try_primary_video(prompt:, duration:, aspect_ratio:)
    Rails.logger.info "[VideoGeneration] Trying primary service: Atlas Cloud (Seedance v1 Pro)"
    
    service = AtlasCloudService.new
    
    unless service.configured?
      Rails.logger.warn "[VideoGeneration] Primary service not configured"
      return { success: false, error: "Atlas Cloud not configured" }
    end

    begin
      result = service.generate_video(
        prompt: prompt,
        duration: duration.to_i,
        aspect_ratio: aspect_ratio
      )

      if result['task_id'].present?
        Rails.logger.info "[VideoGeneration] Primary service succeeded - task_id: #{result['task_id']}"
        {
          success: true,
          task_id: result['task_id'],
          service: 'atlas_cloud',
          metadata: { duration: duration, aspect_ratio: aspect_ratio }
        }
      else
        Rails.logger.error "[VideoGeneration] Primary service returned no task_id. Full response: #{result.inspect}"
        { success: false, error: result['error'] || result['message'] || 'Failed to start generation - no task_id returned' }
      end
    rescue => e
      Rails.logger.error "[VideoGeneration] Primary service error: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def self.try_secondary_video(prompt:, duration:, aspect_ratio:)
    Rails.logger.info "[VideoGeneration] Trying secondary service: Atlas Cloud (fallback)"
    
    service = AtlasCloudService.new
    
    unless service.configured?
      Rails.logger.warn "[VideoGeneration] Secondary service not configured"
      return { success: false, error: "Atlas Cloud not configured" }
    end

    begin
      result = service.generate_video(
        prompt: prompt,
        duration: duration,
        aspect_ratio: aspect_ratio
      )

      if result['task_id'].present?
        Rails.logger.info "[VideoGeneration] Secondary service succeeded - task_id: #{result['task_id']}"
        {
          success: true,
          task_id: result['task_id'],
          service: 'atlas_cloud',
          metadata: { duration: duration, aspect_ratio: aspect_ratio }
        }
      else
        Rails.logger.error "[VideoGeneration] Secondary service returned no task_id. Full response: #{result.inspect}"
        { success: false, error: result['error'] || result['message'] || 'Failed to start generation - no task_id returned' }
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
    when 'atlas_cloud'
      AtlasCloudService.new
    else
      AtlasCloudService.new
    end
  end
end
