# frozen_string_literal: true

module Ai
  module Tools
    class PublishPost
      class Error < StandardError; end

      def self.call(user:, campaign: nil, scheduled_post_id: nil, content_id: nil, **)
        Rails.logger.info "[Tools::PublishPost] Publishing post id=#{scheduled_post_id || content_id}"

        # Find the post to publish
        post = find_post(scheduled_post_id, content_id)
        return { success: false, error: 'Post not found' } unless post

        # Find social account
        social_account = find_social_account(post)
        return { success: false, error: 'No social account configured' } unless social_account

        # Publish via PostformeClient
        client = Social::PostformeClient.new
        result = client.publish_post(post)

        if result[:success]
          # Track usage
          Ai::UsageTracker.track_post_published(campaign, 1) if campaign
          Ai::UsageTracker.track_api_call(campaign, 1) if campaign

          # Update post with platform info
          post.update!(
            postforme_post_id: result[:platform_post_id],
            status: 'published',
            published_at: Time.current
          ) if post.respond_to?(:postforme_post_id)

          # Track in campaign if applicable
          if campaign
            campaign.increment!(:published_posts_count)
          end

          {
            success: true,
            platform_post_id: result[:platform_post_id],
            post_id: post.id,
            platform: post.platform,
            url: result[:url]
          }
        else
          { success: false, error: result[:error] }
        end
      rescue => e
        Rails.logger.error "[Tools::PublishPost] Error: #{e.message}"
        { success: false, error: e.message }
      end

      private

      def self.find_post(scheduled_post_id, content_id)
        if scheduled_post_id.present?
          ScheduledPost.find_by(id: scheduled_post_id)
        elsif content_id.present?
          ScheduledPost.find_by(id: content_id) || Content.find_by(id: content_id)&.to_scheduled_post
        end
      end

      def self.find_social_account(post)
        return nil unless post

        if post.respond_to?(:social_account_id) && post.social_account_id
          SocialAccount.find_by(id: post.social_account_id)
        else
          SocialAccount.find_by(platform: post.platform, user_id: post.user_id)
        end
      end
    end
  end
end
