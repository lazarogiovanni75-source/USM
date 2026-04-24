module Ai
  module Tools
    class GenerateVideo
      class Error < StandardError; end
      
      def self.call(user:, campaign: nil, prompt:, duration: "10", model: "bytedance/seedance-v1.5-pro/text-to-video-fast", **)
        Rails.logger.info "[Tools::GenerateVideo] Generating video: #{prompt}"
        
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
      rescue => e
        Rails.logger.error "[Tools::GenerateVideo] Error: #{e.message}"
        { success: false, error: e.message }
      end
    end
  end
end
