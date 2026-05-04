# frozen_string_literal: true

# Job to publish scheduled posts that are due
class PublishScheduledPostsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "[PublishScheduledPostsJob] Checking for posts due to publish"

    # Find posts scheduled for now or past
    due_posts = ScheduledPost.where('scheduled_at <= ?', Time.current)
                             .where(status: 'scheduled')
                             .where.not(postforme_post_id: nil)

    Rails.logger.info "[PublishScheduledPostsJob] Found #{due_posts.count} posts due for publishing"

    due_posts.find_each do |post|
      begin
        publish_post(post)
      rescue => e
        Rails.logger.error "[PublishScheduledPostsJob] Failed to publish post #{post.id}: #{e.message}"
      end
    end

    # Also check for posts without postforme_post_id that are due
    posts_without_platform_id = ScheduledPost.where('scheduled_at <= ?', Time.current)
                                            .where(status: 'scheduled')
                                            .where(postforme_post_id: nil)

    posts_without_platform_id.find_each do |post|
      begin
        result = Social::Publisher.publish(post)
        if result[:success]
          Rails.logger.info "[PublishScheduledPostsJob] Published post #{post.id} via Postforme"
        else
          Rails.logger.warn "[PublishScheduledPostsJob] Failed to publish post #{post.id}: #{result[:error]}"
        end
      rescue => e
        Rails.logger.error "[PublishScheduledPostsJob] Error publishing post #{post.id}: #{e.message}"
      end
    end
  end

  private

  def publish_post(post)
    social_account = find_social_account(post)
    return unless social_account

    publisher = Social::Publisher.for_platform(post.platform, social_account)
    result = publisher.publish(post)

    if result[:success]
      Rails.logger.info "[PublishScheduledPostsJob] Successfully published post #{post.id}"
      post.update!(status: 'published', published_at: Time.current)
    else
      Rails.logger.warn "[PublishScheduledPostsJob] Failed to publish post #{post.id}: #{result[:error]}"
      post.update!(status: 'failed', error_message: result[:error])
    end
  end

  def find_social_account(post)
    if post.respond_to?(:social_account_id) && post.social_account_id
      SocialAccount.find_by(id: post.social_account_id)
    else
      SocialAccount.find_by(platform: post.platform, user_id: post.user_id)
    end
  end
end
