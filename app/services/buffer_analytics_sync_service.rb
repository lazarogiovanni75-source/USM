# frozen_string_literal: true

# Service for syncing analytics from Buffer API
# Fetches post performance data and stores it locally
class BufferAnalyticsSyncService
  BUFFER_ANALYTICS_CONFIG_KEY = 'BUFFER_ANALYTICS_SYNC_ENABLED'

  def initialize(scheduled_post = nil)
    @scheduled_post = scheduled_post
    @buffer_service = nil
  end

  # Sync analytics for a single scheduled post
  # @param scheduled_post [ScheduledPost]
  # @return [BufferAnalytic] The synced analytics record
  def sync_post(scheduled_post)
    return nil unless scheduled_post.buffer_update_id.present?

    buffer_service = get_buffer_service(scheduled_post.social_account)
    return nil unless buffer_service&.configured?

    begin
      # Fetch analytics from Buffer
      analytics_data = buffer_service.update_analytics(scheduled_post.buffer_update_id)

      # Create or update analytics record
      analytic = BufferAnalytic.find_or_initialize_by(
        scheduled_post: scheduled_post,
        buffer_update_id: scheduled_post.buffer_update_id
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

      Rails.logger.info("[BufferAnalyticsSync] Synced analytics for post #{scheduled_post.id}")
      analytic
    rescue BufferService::BufferError => e
      Rails.logger.error("[BufferAnalyticsSync] Buffer API error: #{e.message}")
      nil
    rescue StandardError => e
      Rails.logger.error("[BufferAnalyticsSync] Sync error: #{e.message}")
      nil
    end
  end

  # Sync analytics for all published posts of a user
  # @param user [User]
  # @return [Array<BufferAnalytic>] Array of synced analytics
  def sync_user_posts(user)
    return [] unless sync_enabled?

    scheduled_posts = user.scheduled_posts.joins(:social_account)
      .where.not(buffer_update_id: nil)
      .where.not(social_accounts: { buffer_access_token: nil })

    scheduled_posts.map { |post| sync_post(post) }.compact
  end

  # Sync analytics for all posts (admin/background job)
  # @return [Integer] Number of posts synced
  def sync_all_posts
    return 0 unless sync_enabled?

    count = 0
    ScheduledPost.where.not(buffer_update_id: nil).find_each do |post|
      result = sync_post(post)
      count += 1 if result.present?
    end
    count
  end

  private

  def get_buffer_service(social_account)
    return nil unless social_account&.buffer_access_token.present?

    BufferService.new(social_account.buffer_access_token)
  end

  def sync_enabled?
    return true if Rails.env.development? || Rails.env.test?

    ENV.fetch(BUFFER_ANALYTICS_CONFIG_KEY) do
      Rails.application.config.x.buffer_analytics_sync_enabled
    end.present?
  rescue KeyError
    true # Default to enabled
  end

  def extract_value(data, key)
    return nil if data.nil?

    value = data[key]
    value&.to_i
  end

  def extract_posted_at(analytics_data, scheduled_post)
    # Try various fields Buffer might use
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
