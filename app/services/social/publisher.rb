# frozen_string_literal: true

# Unified publisher that routes to platform-specific implementations
# Uses Postforme as the primary backend
class Social::Publisher
  class PublishError < StandardError; end

  PLATFORMS = %w[instagram facebook twitter linkedin tiktok youtube].freeze

  def self.publish(post)
    # Find social accounts for this post
    social_account = find_social_account(post)
    
    return failure_result('No social account found for post') unless social_account
    
    # Route to platform-specific publisher
    publisher = for_platform(post.platform, social_account)
    
    begin
      result = publisher.publish(post)
      success_result(result)
    rescue => e
      Rails.logger.error "[Publisher] Publish failed: #{e.message}"
      failure_result(e.message)
    end
  end

  # Get publisher for a specific platform
  def self.for_platform(platform, social_account)
    case platform.to_s.downcase
    when 'instagram'
      Social::InstagramPublisher.new(social_account)
    when 'facebook'
      Social::FacebookPublisher.new(social_account)
    when 'twitter', 'x'
      Social::TwitterPublisher.new(social_account)
    when 'linkedin'
      Social::LinkedinPublisher.new(social_account)
    when 'tiktok'
      Social::TiktokPublisher.new(social_account)
    when 'youtube'
      Social::YoutubePublisher.new(social_account)
    else
      # Default to generic Postforme publisher
      Social::PostformePublisher.new(social_account)
    end
  end

  # Get all posts due for publishing
  def self.posts_due_for_publishing
    ScheduledPost.where('publish_at <= ?', Time.current)
                 .where(status: 'scheduled')
  end

  # Publish all due posts
  def self.publish_due_posts
    results = []
    
    posts_due_for_publishing.find_each do |post|
      result = publish(post)
      results << { post_id: post.id, result: result }
    end
    
    results
  end

  private

  def self.find_social_account(post)
    return nil unless post
    
    if post.respond_to?(:social_account_id) && post.social_account_id
      SocialAccount.find_by(id: post.social_account_id)
    elsif post.respond_to?(:social_accounts) && post.social_accounts.any?
      post.social_accounts.first
    else
      # Find by platform
      SocialAccount.find_by(platform: post.platform, user_id: post.user_id)
    end
  end

  def self.success_result(data)
    { success: true, platform_post_id: data[:platform_post_id], data: data }
  end

  def self.failure_result(error)
    { success: false, error: error }
  end
end
