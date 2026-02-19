module Ai
  module Tools
    class GenerateImage
      class Error < StandardError; end
      
      def self.call(user:, campaign: nil, prompt:, style: "photorealistic", size: "1024x1024", **)
        Rails.logger.info "[Tools::GenerateImage] Generating image: #{prompt}"
        
        result = ImageGenerationService.generate_image(
          prompt: prompt,
          size: size,
          quality: 'high'
        )
        
        if result[:success]
          # Track image generation usage
          Ai::UsageTracker.track_images_generated(campaign, 1) if campaign

          # Optionally attach to campaign
          if campaign
            campaign.update!(strategy: (campaign.strategy || {}).merge(
              last_image_url: result[:output_url],
              last_image_task_id: result[:task_id]
            ))
          end
          
          {
            success: true,
            image_url: result[:output_url],
            task_id: result[:task_id],
            service: result[:service],
            prompt: prompt
          }
        else
          { success: false, error: result[:error] }
        end
      rescue => e
        Rails.logger.error "[Tools::GenerateImage] Error: #{e.message}"
        { success: false, error: e.message }
      end
    end
  end
end
