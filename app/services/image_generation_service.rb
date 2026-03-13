# frozen_string_literal: true

# Image Generation Service
# Primary: Atlas Cloud/Z-Image Turbo (https://api.atlascloud.ai)
class ImageGenerationService
  class ImageGenerationError < StandardError; end
  class ServiceUnavailableError < ImageGenerationError; end

  # Generate image
  #
  # @param prompt [String] Text prompt for image
  # @param size [String] Image size
  # @param quality [String] Image quality
  # @return [Hash] Result with task_id and metadata
  #
  def self.generate_image(prompt:, size: '1024x1024', quality: 'high')
    # Use Atlas Cloud Z-Image Turbo
    result = try_primary_image(prompt: prompt, size: size, quality: quality)
    
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

  def self.try_primary_image(prompt:, size:, quality:)
    Rails.logger.info "[ImageGeneration] Trying Atlas Cloud/Z-Image Turbo"
    
    service = AtlasCloudImageService.new
    
    unless service.configured?
      Rails.logger.warn "[ImageGeneration] Primary service not configured"
      return { success: false, error: "Atlas Cloud not configured" }
    end

    begin
      result = service.generate_image(
        prompt: prompt,
        size: size,
        quality: quality
      )

      # In sync mode, output_url may be returned immediately
      if result['task_id'].present?
        output_url = result['output'] || result.dig('data', 'outputs')&.first
        
        if output_url.present?
          Rails.logger.info "[ImageGeneration] Primary service succeeded - image ready immediately"
          {
            success: true,
            task_id: result['task_id'],
            service: 'atlas_cloud_image',
            output_url: output_url,
            metadata: { model: 'z-image/turbo', size: size, quality: quality }
          }
        else
          # Fallback: task was started but needs polling
          Rails.logger.info "[ImageGeneration] Primary service started task: #{result['task_id']}"
          {
            success: true,
            task_id: result['task_id'],
            service: 'atlas_cloud_image',
            output_url: nil,
            metadata: { model: 'z-image/turbo', size: size, quality: quality }
          }
        end
      else
        Rails.logger.error "[ImageGeneration] Primary service returned no task_id: #{result.inspect}"
        { success: false, error: result['error'] || 'Failed to generate image' }
      end
    rescue AtlasCloudImageService::Error => e
      Rails.logger.error "[ImageGeneration] Primary service error: #{e.message}"
      # Check if it's a credit/account issue - should trigger fallback
      retryable = e.message.include?('credit') || e.message.include?('unavailable') || e.message.include?('insufficient') || e.message.include?('令牌')
      { success: false, error: e.message, retry: retryable }
    rescue => e
      Rails.logger.error "[ImageGeneration] Primary service unexpected error: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def self.try_secondary_image(prompt:, size:, quality:)
    Rails.logger.info "[ImageGeneration] Trying secondary service: Atlas Cloud (fallback)"
    
    service = AtlasCloudImageService.new
    
    unless service.configured?
      Rails.logger.warn "[ImageGeneration] Secondary service not configured"
      return { success: false, error: "Atlas Cloud not configured" }
    end

    begin
      result = service.generate_gpt_image(
        prompt: prompt,
        size: size,
        quality: quality
      )

      if result['task_id'].present? && result['output'].present?
        Rails.logger.info "[ImageGeneration] Secondary service succeeded"
        {
          success: true,
          task_id: result['task_id'],
          service: 'atlas_cloud_image',
          output_url: result['output'],
          metadata: { model: 'gpt-image-1', size: size, quality: quality }
        }
      elsif result['task_id'].present?
        Rails.logger.info "[ImageGeneration] Secondary service started task: #{result['task_id']}"
        {
          success: true,
          task_id: result['task_id'],
          service: 'atlas_cloud_image',
          output_url: nil,
          metadata: { model: 'gpt-image-1', size: size, quality: quality }
        }
      else
        Rails.logger.error "[ImageGeneration] Secondary service returned no task_id"
        { success: false, error: result['error'] || 'Failed to start generation' }
      end
    rescue => e
      Rails.logger.error "[ImageGeneration] Secondary service error: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def self.service_to_object(service_name)
    case service_name
    when 'atlas_cloud_image'
      AtlasCloudImageService.new
    when 'atlas_cloud_image'
      AtlasCloudImageService.new
    when 'openai'
      OpenaiImageService.new
    else
      AtlasCloudImageService.new
    end
  end
end
