# frozen_string_literal: true

# Image Generation Service with Primary/Secondary Fallback
# Primary: Poyo.ai/GPT-Image-1.5 (https://api.poyo.ai)
# Secondary: Defapi/GPT-Image-1.5 (https://api.defapi.org)
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
    # Try primary service (Poyo.ai GPT-Image-1.5)
    result = try_primary_image(prompt: prompt, size: size, quality: quality)
    
    # If primary succeeded with a task_id, return it (polling will handle completion)
    return result if result[:success] && result[:task_id].present?
    
    # If primary failed with retry flag (like insufficient credits), try fallback
    if result[:retry] || result[:error]&.include?('credits') || result[:error]&.include?('insufficient')
      Rails.logger.info "[ImageGeneration] Primary service failed with retryable error, trying Defapi..."
    else
      Rails.logger.warn "[ImageGeneration] Primary service failed: #{result[:error]}"
    end

    # Try secondary service (Defapi GPT-Image-1.5)
    result = try_secondary_image(prompt: prompt, size: size, quality: quality)
    return result if result[:success]

    # Both services failed
    raise ServiceUnavailableError, "Image generation services unavailable. Primary: Poyo.ai failed. Secondary: Defapi failed."
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
    Rails.logger.info "[ImageGeneration] Trying primary service: Poyo.ai/GPT-Image-1.5"
    
    service = PoyoImageService.new
    
    unless service.configured?
      Rails.logger.warn "[ImageGeneration] Primary service not configured"
      return { success: false, error: "Poyo.ai not configured" }
    end

    begin
      result = service.generate_gpt_image(
        prompt: prompt,
        size: size,
        quality: quality
      )

      if result['task_id'].present? && result['output'].present?
        Rails.logger.info "[ImageGeneration] Primary service succeeded"
        {
          success: true,
          task_id: result['task_id'],
          service: 'poyo',
          output_url: result['output'],
          metadata: { model: 'gpt-image-1', size: size, quality: quality }
        }
      elsif result['task_id'].present?
        # Task started but no output yet - this is OK, polling will handle it
        Rails.logger.info "[ImageGeneration] Primary service started task: #{result['task_id']}"
        {
          success: true,
          task_id: result['task_id'],
          service: 'poyo',
          output_url: nil,
          metadata: { model: 'gpt-image-1', size: size, quality: quality }
        }
      else
        Rails.logger.error "[ImageGeneration] Primary service returned no task_id: #{result.inspect}"
        { success: false, error: result['error'] || 'Failed to generate image' }
      end
    rescue PoyoImageService::Error => e
      Rails.logger.error "[ImageGeneration] Primary service error: #{e.message}"
      { success: false, error: e.message, retry: true }
    rescue => e
      Rails.logger.error "[ImageGeneration] Primary service unexpected error: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def self.try_secondary_image(prompt:, size:, quality:)
    Rails.logger.info "[ImageGeneration] Trying secondary service: Defapi/GPT-Image-1.5"
    
    service = DefapiService.new
    
    unless service.configured?
      Rails.logger.warn "[ImageGeneration] Secondary service not configured"
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
        Rails.logger.info "[ImageGeneration] Secondary service succeeded - task_id: #{result['task_id']}"
        {
          success: true,
          task_id: result['task_id'],
          service: 'defapi',
          metadata: { model: 'gpt-image-1.5', size: size, quality: quality }
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
    when 'poyo'
      PoyoImageService.new
    when 'defapi'
      DefapiService.new
    when 'openai'
      OpenaiImageService.new
    else
      PoyoImageService.new
    end
  end
end
