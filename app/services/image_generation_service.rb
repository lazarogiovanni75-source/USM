# frozen_string_literal: true

# Image Generation Service with Primary/Secondary Fallback
# Primary: Defapi/GPT-Image-1.5 (https://api.defapi.org)
# Secondary: OpenAI/GPT-Image-1.0 (direct API)
class ImageGenerationService
  class ImageGenerationError < StandardError; end
  class ServiceUnavailableError < ImageGenerationError; end

  # Generate image with primary/secondary fallback
  #
  # @param prompt [String] Text prompt for image
  # @param size [String] Image size
  # @param quality [String] Image quality
  # @return [Hash] Result with task_id and metadata
  #
  def self.generate_image(prompt:, size: '1024x1024', quality: 'high')
    # Try primary service (Defapi GPT-Image-1.5)
    result = try_primary_image(prompt: prompt, size: size, quality: quality)
    return result if result[:success]

    # Try secondary service (OpenAI GPT-Image-1.0)
    result = try_secondary_image(prompt: prompt, size: size, quality: quality)
    return result if result[:success]

    # Both services failed
    raise ServiceUnavailableError, "Image generation services unavailable. Primary: Defapi failed. Secondary: OpenAI failed."
  end

  # Get image task status
  def self.get_status(task_id, service: nil)
    service_obj = service_to_object(service)
    
    if service_obj.is_a?(DefapiService)
      service_obj.gpt_image_status(task_id)
    else
      # OpenAI generates synchronously, so no polling needed
      { 'status' => 'success', 'output' => task_id }
    end
  end

  # Edit an existing image (placeholder - creates new variation)
  def self.edit_image(image_url:, prompt:)
    # Note: OpenAI GPT-Image-1 doesn't support editing, only generation
    # For now, we'll generate a new image based on the prompt
    # In production, you could use inpainting with DALL-E 2 or similar
    { success: false, error: "Image editing requires DALL-E 2 API. Please generate a new image instead." }
  end

  def self.try_primary_image(prompt:, size:, quality:)
    Rails.logger.info "[ImageGeneration] Trying primary service: Defapi/GPT-Image-1.5"
    
    service = DefapiService.new
    
    unless service.configured?
      Rails.logger.warn "[ImageGeneration] Primary service not configured"
      return { success: false, error: "Defapi not configured" }
    end

    begin
      result = service.generate_gpt_image(
        prompt: prompt,
        model: 'openai/gpt-image-1.5',
        size: size,
        quality: quality,
        output_format: 'png'
      )

      if result['task_id'].present?
        Rails.logger.info "[ImageGeneration] Primary service succeeded - task_id: #{result['task_id']}"
        {
          success: true,
          task_id: result['task_id'],
          service: 'defapi',
          metadata: { model: 'gpt-image-1.5', size: size, quality: quality }
        }
      else
        Rails.logger.error "[ImageGeneration] Primary service returned no task_id"
        { success: false, error: result['error'] || 'Failed to start generation' }
      end
    rescue => e
      Rails.logger.error "[ImageGeneration] Primary service error: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def self.try_secondary_image(prompt:, size:, quality:)
    Rails.logger.info "[ImageGeneration] Trying secondary service: OpenAI/GPT-Image-1.0"
    
    service = OpenaiImageService.new
    
    unless service.configured?
      Rails.logger.warn "[ImageGeneration] Secondary service not configured"
      return { success: false, error: "OpenAI not configured" }
    end

    begin
      result = service.generate_gpt_image(
        prompt: prompt,
        size: size,
        quality: quality
      )

      if result['output'].present?
        Rails.logger.info "[ImageGeneration] Secondary service succeeded"
        {
          success: true,
          task_id: result['output'],
          service: 'openai',
          output_url: result['output'],
          metadata: { model: 'gpt-image-1', size: size, quality: quality }
        }
      else
        Rails.logger.error "[ImageGeneration] Secondary service returned no output"
        { success: false, error: 'Failed to generate image' }
      end
    rescue => e
      Rails.logger.error "[ImageGeneration] Secondary service error: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def self.service_to_object(service_name)
    case service_name
    when 'defapi'
      DefapiService.new
    when 'openai'
      OpenaiImageService.new
    else
      DefapiService.new
    end
  end
end
