# frozen_string_literal: true

# Video Generation Service with Primary/Secondary Fallback
# Primary: Poyo.ai (https://api.poyo.ai)
# Secondary: OpenAI/Sora (not yet available via API - placeholder for future)
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
    # Try primary service (Poyo)
    result = try_primary_video(prompt: prompt, duration: duration, aspect_ratio: aspect_ratio)
    return result if result[:success]

    # Try secondary service (OpenAI Sora - placeholder for when available)
    result = try_secondary_video(prompt: prompt, duration: duration, aspect_ratio: aspect_ratio)
    return result if result[:success]

    # Both services failed
    raise ServiceUnavailableError, "Video generation services unavailable. Primary: Poyo.ai failed. Secondary: OpenAI Sora not yet available."
  end

  # Get video task status
  def self.get_status(task_id, service: nil)
    service_obj = service_to_object(service)
    service_obj.task_status(task_id)
  end

  private

  def self.try_primary_video(prompt:, duration:, aspect_ratio:)
    Rails.logger.info "[VideoGeneration] Trying primary service: Poyo.ai"
    
    service = PoyoService.new
    
    unless service.configured?
      Rails.logger.warn "[VideoGeneration] Primary service not configured"
      return { success: false, error: "Poyo.ai not configured" }
    end

    # Get the webhook URL for callbacks
    callback_url = Rails.application.routes.url_helpers.poyo_webhook_url(
      host: Rails.application.config.x.public_host || ENV['CLACKY_PUBLIC_HOST'] || 'localhost:3000',
      protocol: Rails.env.production? ? 'https' : 'http'
    )

    begin
      result = service.generate_video(
        prompt: prompt,
        duration: duration,
        aspect_ratio: aspect_ratio,
        callback_url: callback_url
      )

      if result['task_id'].present?
        Rails.logger.info "[VideoGeneration] Primary service succeeded - task_id: #{result['task_id']}"
        {
          success: true,
          task_id: result['task_id'],
          service: 'poyo',
          metadata: { duration: duration, aspect_ratio: aspect_ratio, callback_url: callback_url }
        }
      else
        # Log the full result for debugging
        Rails.logger.error "[VideoGeneration] Primary service returned no task_id. Full response: #{result.inspect}"
        { success: false, error: result['error'] || result['message'] || 'Failed to start generation - no task_id returned' }
      end
    rescue => e
      Rails.logger.error "[VideoGeneration] Primary service error: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def self.try_secondary_video(prompt:, duration:, aspect_ratio:)
    Rails.logger.info "[VideoGeneration] Trying secondary service: OpenAI/Sora"
    
    # Note: OpenAI Sora is not yet publicly available via API
    # This is a placeholder for when it becomes available
    # For now, we return failure to indicate it's not ready
    
    Rails.logger.warn "[VideoGeneration] Secondary service (OpenAI Sora) not yet available via API"
    { success: false, error: "OpenAI Sora not yet available via API" }
  end

  def self.service_to_object(service_name)
    case service_name
    when 'poyo'
      PoyoService.new
    when 'openai'
      # Placeholder for when OpenAI Sora becomes available
      raise ServiceUnavailableError, "OpenAI Sora not yet available"
    else
      PoyoService.new
    end
  end
end
