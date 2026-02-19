# frozen_string_literal: true

# Postforme-powered publisher for all platforms
# Unified interface via Postforme API
class Social::PostformePublisher < Social::BasePublisher
  PLATFORM = 'postforme'

  def publish(post)
    Rails.logger.info "[PostformePublisher] Publishing post #{post.id} to #{profile_id}"

    # Prepare post data
    caption = build_caption(post)
    media = build_media(post)
    scheduled_at = post.publish_at if post.publish_at.present? && post.publish_at > Time.current

    # Create post via Postforme API
    result = postforme_service.create_post(
      profile_id,
      caption,
      media: media,
      scheduled_at: scheduled_at,
      now: scheduled_at.nil?
    )

    if result['data'].present?
      platform_post_id = result.dig('data', 'id')
      
      # Update local post with platform info
      post.update!(
        postforme_post_id: platform_post_id,
        status: 'published',
        published_at: Time.current
      )

      {
        success: true,
        platform_post_id: platform_post_id,
        post_id: post.id,
        platform: 'postforme',
        url: result.dig('data', 'url')
      }
    else
      raise PlatformError, "Failed to create post: #{result.inspect}"
    end
  rescue PostformeService::PostformeError => e
    Rails.logger.error "[PostformePublisher] Postforme error: #{e.message}"
    post.update!(status: 'failed', error_message: e.message) if post.persisted?
    raise PlatformError, "Postforme API error: #{e.message}"
  end

  # Fetch analytics for a specific post
  def fetch_post_analytics(post)
    return {} unless post.postforme_post_id.present?
    
    postforme_service.post_analytics(post.postforme_post_id)
  rescue => e
    Rails.logger.error "[PostformePublisher] Failed to fetch analytics: #{e.message}"
    {}
  end

  # Fetch account metrics
  def fetch_account_metrics
    return {} unless configured?
    
    postforme_service.account_metrics(profile_id)
  rescue => e
    Rails.logger.error "[PostformePublisher] Failed to fetch account metrics: #{e.message}"
    {}
  end

  private

  def build_caption(post)
    caption = post.content.to_s.dup
    
    # Add hashtags if present
    if post.respond_to?(:hashtags) && post.hashtags.present?
      caption += "\n\n#{post.hashtags}"
    end
    
    caption
  end

  def build_media(post)
    return [] unless post.respond_to?(:media_url) && post.media_url.present?

    [{ url: post.media_url }]
  end
end
