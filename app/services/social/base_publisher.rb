# frozen_string_literal: true

# Base publisher service using Postforme API
# All platforms are handled through Postforme's unified API
class Social::BasePublisher
  class PublishError < StandardError; end
  class PlatformError < PublishError; end
  class AuthenticationError < PublishError; end

  attr_reader :social_account, :post

  PLATFORM = 'base'

  def initialize(social_account)
    @social_account = social_account
    @postforme_service = PostformeService.new(social_account.postforme_api_key)
  end

  # Main publish method - should be overridden by platform-specific implementations
  def publish(post)
    raise NotImplementedError, "Subclass must implement #publish"
  end

  # Get platform-specific Postforme profile ID
  def profile_id
    social_account.postforme_profile_id
  end

  # Check if account is configured
  def configured?
    social_account.configured_for_postforme?
  end

  # Fetch current metrics from platform
  def fetch_metrics
    return {} unless configured?
    
    @postforme_service.account_metrics(profile_id)
  rescue => e
    Rails.logger.error "[Social::BasePublisher] Failed to fetch metrics: #{e.message}"
    {}
  end

  protected

  def handle_result(result, post)
    if result['data'].present?
      platform_post_id = result.dig('data', 'id')
      
      post.update!(
        postforme_post_id: platform_post_id,
        status: 'published',
        published_at: Time.current
      )

      {
        success: true,
        platform_post_id: platform_post_id,
        post_id: post.id,
        platform: PLATFORM,
        url: result.dig('data', 'url')
      }
    else
      raise PlatformError, "Failed to create post: #{result.inspect}"
    end
  rescue PostformeService::PostformeError => e
    post.update!(status: 'failed', error_message: e.message) if post.persisted?
    raise PlatformError, "API error: #{e.message}"
  end

  private

  def postforme_service
    @postforme_service
  end
end
