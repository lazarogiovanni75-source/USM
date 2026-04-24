
# frozen_string_literal: true

# Image Generation Service
# Primary: Atlas Cloud unified API (https://api.atlascloud.ai)
# Uses POST /api/v1/model/generateImage
class ImageGenerationService
  class ImageGenerationError < StandardError; end
  class ServiceUnavailableError < ImageGenerationError; end

  # Generate image
  #
  # @param prompt [String] Text prompt for image
  # @param size [String] Image size
  # @param quality [String] Image quality tier (standard, hd)
  # @param model [String] Model to use (default: bytedance/seedream-v4.5/sequential)
  # @return [Hash] Result with task_id and metadata
  #
  def self.generate_image(prompt:, size: '1:1', quality: 'standard', model: nil)
    # Map size to aspect_ratio format
    aspect_ratio = map_size_to_aspect_ratio(size)
    
    # Use Atlas Cloud unified API
    result = try_primary_image(prompt: prompt, aspect_ratio: aspect_ratio, model: model, quality: quality)
    
    # If primary succeeded with a task_id, return it (polling will handle completion)
    return result if result[:success] && result[:task_id].present?
    
    # Primary failed - raise error
    raise ServiceUnavailableError, "Image generation service is currently unavailable. Please try again later or contact support."
  end

  # Get image task status
  def self.get_status(task_id, service: nil)
    service_obj = service_to_object(service)
    
    if service_obj.is_a?(AtlasCloudImageService)
      service_obj.image_status(task_id)
    else
      # OpenAI generates synchronously, so no polling needed
      { 'status' => 'success', 'output' => task_id }
    end
  end

  # Edit an existing image (placeholder - creates new variation)
  def self.edit_image(image_url:, prompt:)
    # Note: Most image generation APIs don't support editing
    # For now, we'll generate a new image based on the prompt
    { success: false, error: "Image editing not supported. Please generate a new image instead." }
  end

  def self.try_primary_image(prompt:, aspect_ratio:, model: nil, quality: 'standard')
    Rails.logger.info "[ImageGeneration] Trying Atlas Cloud unified API"
    
    service = AtlasCloudImageService.new
    
    unless service.configured?
      Rails.logger.warn "[ImageGeneration] Atlas Cloud not configured"
      return { success: false, error: "Atlas Cloud not configured. Please add your ATLASCLOUD_API_KEY." }
    end

    begin
      result = service.generate_image(
        prompt: prompt,
        model: model || 'atlascloud/qwen-image/text-to-image',
        aspect_ratio: aspect_ratio,
        quality: quality
      )

      if result['task_id'].present?
        Rails.logger.info "[ImageGeneration] Primary service started task: #{result['task_id']}"
        {
          success: true,
          task_id: result['task_id'],
          service: 'atlas_cloud',
          output_url: nil,
          metadata: { model: model || 'bytedance/seedream-v4.5/sequential', aspect_ratio: aspect_ratio, quality_tier: quality }
        }
      else
        Rails.logger.error "[ImageGeneration] Primary service returned no task_id: #{result.inspect}"
        { success: false, error: result['error'] || 'Failed to generate image' }
      end
    rescue AtlasCloudImageService::AuthenticationError => e
      Rails.logger.error "[ImageGeneration] Authentication error: #{e.message}"
      { success: false, error: "Atlas Cloud API key is invalid. Please check your configuration." }
    rescue AtlasCloudImageService::Error => e
      Rails.logger.error "[ImageGeneration] Primary service error: #{e.message}"
      { success: false, error: e.message }
    rescue => e
      Rails.logger.error "[ImageGeneration] Primary service unexpected error: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def self.try_secondary_image(prompt:, size:, quality: 'standard')
    Rails.logger.info "[ImageGeneration] Trying secondary service (same API)"
    
    # Same API, just different model
    aspect_ratio = map_size_to_aspect_ratio(size)
    try_primary_image(prompt: prompt, aspect_ratio: aspect_ratio, model: 'z-image/turbo', quality: quality)
  end

  def self.service_to_object(service_name)
    case service_name
    when 'atlas_cloud', 'atlas_cloud_image'
      AtlasCloudImageService.new
    when 'openai'
      OpenaiImageService.new
    else
      AtlasCloudImageService.new
    end
  end

  def self.map_size_to_aspect_ratio(size)
    case size
    when '1024x1024', '1:1', 'square'
      '1:1'
    when '1792x1024', '16:9', 'landscape'
      '16:9'
    when '1024x1792', '9:16', 'portrait'
      '9:16'
    when '1024x1536', '3:4'
      '3:4'
    when '1536x1024', '4:3'
      '4:3'
    else
      '1:1'
    end
  end
end
