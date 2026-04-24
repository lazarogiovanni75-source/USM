module Ai
  module Tools
    class GenerateVideo
      class Error < StandardError; end
      class InsufficientCreditsError < Error; end
      
      def self.call(user:, campaign: nil, prompt:, duration: "10", model: "bytedance/seedance-v1.5-pro/text-to-video-fast", **)
        Rails.logger.info "[Tools::GenerateVideo] Generating video: #{prompt}"
        
        # Get active subscription and check credits
        subscription = user.user_subscriptions.active.first
        credit_cost = 5 # Video costs 5 credits
        
        unless subscription && subscription.has_credits?(credit_cost)
          raise InsufficientCreditsError, "You don't have enough credits. Please upgrade your plan or wait for your monthly reset."
        end
        
        # Prevent duplicate video generations - check for recent pending videos with same prompt
        recent_video = user.videos.where(
          "created_at > ? AND status IN ('pending', 'processing')", 
          5.minutes.ago
        ).where("title ILIKE ?", "%#{prompt[0..50]}%").first
        
        if recent_video
          Rails.logger.info "[Tools::GenerateVideo] Duplicate video generation detected, returning existing video"
          return {
            success: true,
            task_id: recent_video.prediction_url,
            service: 'atlas_cloud',
            prompt: prompt,
            duration: duration,
            model: model,
            message: "Video generation already in progress for similar prompt. Please wait for the existing video."
          }
        end
        
        result = VideoGenerationService.generate_video(
          prompt: prompt,
          duration: duration,
          model: model
        )
        
        if result[:success]
          # Deduct credits
          subscription&.deduct_credits!(credit_cost)
          
          # Optionally attach to campaign
          if campaign
            campaign.update!(strategy: (campaign.strategy || {}).merge(
              last_video_task_id: result[:task_id],
              last_video_model: model
            ))
          end
          
          {
            success: true,
            task_id: result[:task_id],
            service: result[:service],
            prompt: prompt,
            duration: duration,
            model: model,
            message: "Video generation started. Task ID: #{result[:task_id]}"
          }
        else
          { success: false, error: result[:error] }
        end
      rescue InsufficientCreditsError => e
        Rails.logger.warn "[Tools::GenerateVideo] Insufficient credits: #{e.message}"
        { success: false, error: e.message, requires_upgrade: true }
      rescue => e
        Rails.logger.error "[Tools::GenerateVideo] Error: #{e.message}"
        { success: false, error: e.message }
      end
    end
  end
end
