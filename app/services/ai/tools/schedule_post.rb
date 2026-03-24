module Ai
  module Tools
    class SchedulePost
      class Error < StandardError; end
      
      def self.call(user:, campaign: nil, content_id:, platform:, scheduled_at:, **)
        Rails.logger.info "[Tools::SchedulePost] Scheduling post ##{content_id} for #{scheduled_at}"
        
        # Find the content
        content = user.contents.find_by(id: content_id)
        unless content
          return { success: false, error: "Content not found" }
        end
        
        # Find the social account for the platform
        social_account = user.social_accounts.find_by(platform: platform, is_connected: true)
        unless social_account
          return { success: false, error: "No connected #{platform} account found" }
        end
        
        # Parse scheduled_at
        publish_time = if scheduled_at.is_a?(String)
          Time.zone.parse(scheduled_at)
        else
          scheduled_at
        end
        
        # Validate time is in the future
        if publish_time <= Time.current
          return { success: false, error: "Scheduled time must be in the future" }
        end
        
        # Create scheduled post
        scheduled_post = ScheduledPost.create!(
          content: content,
          social_account: social_account,
          user: user,
          scheduled_at: publish_time,
          status: :scheduled
        )
        
        # Associate with campaign if provided
        if campaign
          content.update!(campaign: campaign) if content.campaign.nil?
        end
        
        Rails.logger.info "[Tools::SchedulePost] Created scheduled post ##{scheduled_post.id}"
        
        {
          success: true,
          scheduled_post_id: scheduled_post.id,
          content_id: content.id,
          platform: platform,
          scheduled_at: scheduled_post.scheduled_at.iso8601,
          message: "Post scheduled for #{I18n.l(scheduled_post.scheduled_at, format: :long)}"
        }
      rescue ActiveRecord::RecordNotFound => e
        Rails.logger.error "[Tools::SchedulePost] Record not found: #{e.message}"
        { success: false, error: e.message }
      rescue => e
        Rails.logger.error "[Tools::SchedulePost] Error: #{e.message}"
        { success: false, error: e.message }
      end
    end
  end
end
