module Ai
  module Tools
    class GenerateImage
      class Error < StandardError; end
      class InsufficientCreditsError < Error; end
      
      def self.call(user:, campaign: nil, prompt:, style: "photorealistic", size: "1024x1024", **)
        Rails.logger.info "[Tools::GenerateImage] Generating image: #{prompt}"
        
        # Get active subscription and check credits
        subscription = user.user_subscriptions.active.first
        credit_cost = 1 # Standard image cost
        
        unless subscription && subscription.has_credits?(credit_cost)
          raise InsufficientCreditsError, "You don't have enough credits. Please upgrade your plan or wait for your monthly reset."
        end
        
        result = ImageGenerationService.generate_image(
          prompt: prompt,
          size: size,
          quality: 'high'
        )
        
        if result[:success]
          # Deduct credits
          subscription&.deduct_credits!(credit_cost)
          
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
      rescue InsufficientCreditsError => e
        Rails.logger.warn "[Tools::GenerateImage] Insufficient credits: #{e.message}"
        { success: false, error: e.message, requires_upgrade: true }
      rescue => e
        Rails.logger.error "[Tools::GenerateImage] Error: #{e.message}"
        { success: false, error: e.message }
      end
    end
  end
end
