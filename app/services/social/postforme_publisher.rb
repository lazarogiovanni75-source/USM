# frozen_string_literal: true

# Postforme-powered publisher for all social media platforms
# Unified interface via Postforme API - single integration for all platforms
# Supported platforms: Instagram, Facebook, TikTok, Bluesky, Pinterest, LinkedIn, YouTube, Threads, X
class Social::PostformePublisher < Social::BasePublisher
  PLATFORM = 'postforme'

  # Supported platforms via Postforme
  SUPPORTED_PLATFORMS = %w[
    instagram facebook tiktok bluesky pinterest
    linkedin youtube threads x twitter
  ].freeze

  def publish(post)
    Rails.logger.info "[PostformePublisher] Publishing post #{post.id}"

    validate_postforme_config!

    caption = build_caption(post)
    media = build_media(post)
    scheduled_at = determine_scheduled_time(post)

    # Get all profile IDs for the post's target platforms
    profile_ids = get_profile_ids(post)

    if profile_ids.empty?
      raise PlatformError, "No connected social accounts found for post #{post.id}"
    end

    result = postforme_service.create_post(profile_ids, caption, media: media, scheduled_at: scheduled_at)

    if result['data'].present?
      platform_post_id = result.dig('data', 'id')
      post_url = result.dig('data', 'url')

      post.update!(
        postforme_post_id: platform_post_id,
        status: scheduled_at.present? ? 'scheduled' : 'published',
        posted_at: scheduled_at.blank? ? Time.current : nil
      )

      Rails.logger.info "[PostformePublisher] Post #{post.id} published successfully via Postforme"

      {
        success: true,
        platform_post_id: platform_post_id,
        post_id: post.id,
        platform: 'postforme',
        url: post_url,
        postforme_post_id: platform_post_id,
        platforms_targeted: post.all_platforms
      }
    else
      error_msg = result.dig('error', 'message') || result.inspect
      post.update!(status: 'failed', error_message: error_msg) if post.persisted?
      raise PlatformError, "Postforme API error: #{error_msg}"
    end
  rescue PostformeService::PostformeError => e
    Rails.logger.error "[PostformePublisher] Postforme API error: #{e.message}"
    post.update!(status: 'failed', error_message: e.message) if post.persisted?
    raise PlatformError, "Postforme API error: #{e.message}"
  rescue => e
    Rails.logger.error "[PostformePublisher] Unexpected error: #{e.message}"
    post.update!(status: 'failed', error_message: e.message) if post.persisted?
    raise PlatformError, "Failed to publish: #{e.message}"
  end

  # Share an already-created post immediately
  def share_now(post)
    return { success: false, error: 'No Postforme post ID' } unless post.postforme_post_id

    result = postforme_service.share_now(post.postforme_post_id)

    if result['success'] || result.dig('data', 'shared')
      post.update!(status: 'published', posted_at: Time.current)
      { success: true, platform_post_id: post.postforme_post_id }
    else
      { success: false, error: result.dig('error', 'message') || 'Failed to share' }
    end
  rescue => e
    Rails.logger.error "[PostformePublisher] Share error: #{e.message}"
    { success: false, error: e.message }
  end

  # Fetch analytics for a specific post
  def fetch_post_analytics(post)
    return {} unless post.postforme_post_id.present?

    result = postforme_service.post_analytics(post.postforme_post_id)
    parse_analytics_response(result, post)
  rescue => e
    Rails.logger.error "[PostformePublisher] Failed to fetch analytics: #{e.message}"
    {}
  end

  # Fetch account metrics for all connected profiles
  def fetch_account_metrics
    return {} unless configured?

    result = postforme_service.account_metrics(profile_id)
    parse_metrics_response(result)
  rescue => e
    Rails.logger.error "[PostformePublisher] Failed to fetch account metrics: #{e.message}"
    {}
  end

  # List all posts from Postforme
  def list_posts(options = {})
    postforme_service.list_posts(options)
  end

  # Get a specific post from Postforme
  def get_post(post_id)
    postforme_service.get_post(post_id)
  end

  # Delete a post from Postforme
  def delete_post(post_id)
    postforme_service.delete_post(post_id)
  end

  private

  attr_reader :api_key

  def postforme_service
    @postforme_service ||= PostformeService.new(api_key)
  end

  def api_key
    @api_key ||= ENV.fetch('POSTFORME_API_KEY', nil)
  end

  def configured?
    api_key.present?
  end

  def validate_postforme_config!
    raise PlatformError, 'Postforme API key not configured' unless configured?
  end

  def build_caption(post)
    caption = post.content&.body.to_s.dup
    caption = post.content&.title.to_s if caption.blank?

    if post.respond_to?(:hashtags) && post.hashtags.present?
      caption += "\n\n#{post.hashtags}"
    end

    caption.strip
  end

  def build_media(post)
    media_urls = []

    # Check multiple possible media URL fields
    media_fields = [:media_url, :image_url, :video_url, :asset_url]
    media_fields.each do |field|
      if post.respond_to?(field) && post.send(field).present?
        media_urls << { url: post.send(field) }
      end
    end

    # Check content's media
    if post.content&.respond_to?(:media_url) && post.content.media_url.present?
      media_urls << { url: post.content.media_url }
    end

    # Parse media_urls JSON if present
    if post.respond_to?(:media_urls) && post.media_urls.present?
      urls = post.media_urls.is_a?(Array) ? post.media_urls : JSON.parse(post.media_urls)
      urls.each { |url| media_urls << { url: url } unless url.blank? }
    end

    media_urls.uniq
  end

  def determine_scheduled_time(post)
    if post.scheduled_at.present? && post.scheduled_at > Time.current
      post.scheduled_at
    elsif post.publish_at.present? && post.publish_at > Time.current
      post.publish_at
    end
  end

  def get_profile_ids(post)
    profile_ids = []

    # Get profiles from social account
    if post.social_account&.postforme_profile_id.present?
      profile_ids << post.social_account.postforme_profile_id
    end

    # Get profiles from target platforms via Postforme API
    accounts = postforme_service.social_accounts['data'] || []
    target_platforms = post.all_platforms

    accounts.each do |account|
      account_platform = account['platform']&.downcase
      if target_platforms.include?(account_platform) || target_platforms.include?(account_platform&.gsub('_', ''))
        profile_ids << account['id'] unless profile_ids.include?(account['id'])
      end
    end

    profile_ids.uniq
  end

  def parse_analytics_response(result, post)
    return {} unless result['data'].present?

    data = result['data']
    metrics = data['metrics'] || data

    {
      success: true,
      post_id: post.id,
      postforme_post_id: post.postforme_post_id,
      likes: extract_metric(metrics, 'likes'),
      comments: extract_metric(metrics, 'comments'),
      shares: extract_metric(metrics, 'shares'),
      saves: extract_metric(metrics, 'saves'),
      clicks: extract_metric(metrics, 'clicks'),
      impressions: extract_metric(metrics, 'impressions'),
      reach: extract_metric(metrics, 'reach'),
      engagement_rate: calculate_engagement_rate(metrics),
      fetched_at: Time.current.iso8601,
      raw_data: data
    }
  end

  def parse_metrics_response(result)
    return {} unless result['data'].present?

    data = result['data']
    metrics = data['metrics'] || data

    {
      success: true,
      followers: data['followers'] || 0,
      total_posts: data['total_posts'] || 0,
      total_likes: extract_metric(metrics, 'likes'),
      total_comments: extract_metric(metrics, 'comments'),
      total_shares: extract_metric(metrics, 'shares'),
      total_impressions: extract_metric(metrics, 'impressions'),
      fetched_at: Time.current.iso8601
    }
  end

  def extract_metric(metrics, key)
    value = metrics[key]
    case value
    when Hash then value['count'] || value['total'] || 0
    when Integer then value
    else 0
    end
  end

  def calculate_engagement_rate(metrics)
    impressions = extract_metric(metrics, 'impressions')
    return 0.0 if impressions.zero?

    total_engagement = %w[likes comments shares saves].sum { |k| extract_metric(metrics, k) }
    ((total_engagement.to_f / impressions) * 100).round(2)
  end

  # Platform-specific helpers for compatibility
  def platform
    'postforme'
  end

  def oauth_authorize_url(_callback_url)
    postforme_service.oauth_url(callback_url)['url']
  end

  def exchange_code(_code)
    # OAuth handled by Postforme directly
    {}
  end
end
