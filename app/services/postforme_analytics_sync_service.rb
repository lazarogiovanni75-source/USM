# frozen_string_literal: true

# Service for syncing analytics from Postforme API
# Replaces Buffer analytics sync
class PostformeAnalyticsSyncService
  POSTFORME_ANALYTICS_CONFIG_KEY = 'POSTFORME_ANALYTICS_SYNC_ENABLED'

  def initialize(scheduled_post = nil)
    @scheduled_post = scheduled_post
    @postforme_service = nil
  end

  # Sync analytics for a single scheduled post
  # @param scheduled_post [ScheduledPost]
  # @return [PostformeAnalytic] The synced analytics record
  def sync_post(scheduled_post)
    return nil unless scheduled_post.postforme_post_id.present?

    postforme_service = get_postforme_service(scheduled_post.social_account)
    return nil unless postforme_service&.configured?

    begin
      analytics_data = postforme_service.post_analytics(scheduled_post.postforme_post_id)

      analytic = PostformeAnalytic.find_or_initialize_by(
        scheduled_post: scheduled_post,
        postforme_post_id: scheduled_post.postforme_post_id
      )

      analytic.update!(
        clicks: extract_value(analytics_data, 'clicks'),
        impressions: extract_value(analytics_data, 'impressions'),
        engagement: extract_value(analytics_data, 'engagement'),
        reach: extract_value(analytics_data, 'reach'),
        shares: extract_value(analytics_data, 'shares'),
        likes: extract_value(analytics_data, 'likes'),
        comments: extract_value(analytics_data, 'comments'),
        posted_at: extract_posted_at(analytics_data, scheduled_post),
        synced_at: Time.current
      )

      Rails.logger.info("[PostformeAnalyticsSync] Synced analytics for post #{scheduled_post.id}")
      analytic
    rescue PostformeService::PostformeError => e
      Rails.logger.error("[PostformeAnalyticsSync] Postforme API error: #{e.message}")
      nil
    rescue StandardError => e
      Rails.logger.error("[PostformeAnalyticsSync] Sync error: #{e.message}")
      nil
    end
  end

  # Sync analytics for all published posts of a user
  # @param user [User]
  # @return [Array<PostformeAnalytic>] Array of synced analytics
  def sync_user_posts(user)
    return [] unless sync_enabled?

    scheduled_posts = user.scheduled_posts.joins(:social_account)
      .where.not(postforme_post_id: nil)
      .where.not(social_accounts: { postforme_api_key: nil })

    scheduled_posts.map { |post| sync_post(post) }.compact
  end

  # Sync analytics for all posts (admin/background job)
  # @return [Integer] Number of posts synced
  def sync_all_posts
    return 0 unless sync_enabled?

    count = 0
    ScheduledPost.where.not(postforme_post_id: nil).find_each do |post|
      result = sync_post(post)
      count += 1 if result.present?
    end
    count
  end

  private

  def get_postforme_service(social_account)
    return nil unless social_account&.postforme_api_key.present?

    PostformeService.new(social_account.postforme_api_key)
  end

  def sync_enabled?
    return true if Rails.env.development? || Rails.env.test?

    ENV.fetch(POSTFORME_ANALYTICS_CONFIG_KEY) do
      Rails.application.config.x.postforme_analytics_sync_enabled
    end.present?
  rescue KeyError
    true
  end

  def extract_value(data, key)
    return nil if data.nil?

    value = data[key]
    value&.to_i
  end

  def extract_posted_at(analytics_data, scheduled_post)
    posted_at = analytics_data&.dig('sent_at') ||
                analytics_data&.dig('created_at') ||
                analytics_data&.dig('publish_time')

    return nil if posted_at.nil?

    case posted_at
    when String
      DateTime.parse(posted_at)
    when Integer, Float
      Time.at(posted_at)
    else
      scheduled_post.scheduled_at
    end
  rescue StandardError
    scheduled_post.scheduled_at
  end
end
