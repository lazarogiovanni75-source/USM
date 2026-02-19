module Ai
  module Tools
    class GenerateVideo
      class Error < StandardError; end
      
      def self.call(user:, campaign: nil, prompt:, duration: "10", model: "sora-2-pro", **)
        Rails.logger.info "[Tools::GenerateVideo] Generating video: #{prompt}"
        
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
