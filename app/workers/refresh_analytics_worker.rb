# frozen_string_literal: true

# Sidekiq worker to refresh analytics data from Postforme API
# Runs every 24 hours via sidekiq-cron
# Updates PostAnalytic records for all published posts
class RefreshAnalyticsWorker
  include Sidekiq::Worker
  sidekiq_options retry: 3, backtrace: true

  BATCH_SIZE = 50

  def perform(args = {})
    Rails.logger.info "[RefreshAnalyticsWorker] Starting analytics refresh at #{Time.current.iso8601}"

    start_time = Time.current
    stats = { processed: 0, updated: 0, failed: 0, skipped: 0 }

    begin
      # Get all published posts with Postforme IDs
      posts = get_posts_to_refresh

      Rails.logger.info "[RefreshAnalyticsWorker] Found #{posts.count} posts to refresh"

      posts.each do |post|
        result = refresh_post_analytics(post)
        stats[:processed] += 1

        case result
        when :updated
          stats[:updated] += 1
        when :failed
          stats[:failed] += 1
        when :skipped
          stats[:skipped] += 1
        end
      end

      duration = Time.current - start_time
      Rails.logger.info "[RefreshAnalyticsWorker] Completed in #{duration.round(2)}s - Processed: #{stats[:processed]}, Updated: #{stats[:updated]}, Failed: #{stats[:failed]}, Skipped: #{stats[:skipped]}"

      # Notify completion if significant changes
      if stats[:updated] > 0
        notify_completion(stats)
      end

    rescue StandardError => e
      Rails.logger.error "[RefreshAnalyticsWorker] Fatal error: #{e.message}"
      raise
    end
  end

  private

  def get_posts_to_refresh
    ScheduledPost
      .published
      .where.not(postforme_post_id: nil)
      .includes(:content, :user, :social_account)
      .order(posted_at: :desc)
  end

  def refresh_post_analytics(post)
    return :skipped unless should_refresh?(post)

    analytics_data = fetch_from_postforme(post)

    return :failed unless analytics_data.present? && analytics_data[:success]

    save_analytics(post, analytics_data)
    :updated

  rescue PostformeService::PostformeError => e
    Rails.logger.warn "[RefreshAnalyticsWorker] Postforme error for post #{post.id}: #{e.message}"
    post.update!(status: 'failed', error_message: "Postforme: #{e.message}") if post.status == 'published'
    :failed

  rescue => e
    Rails.logger.error "[RefreshAnalyticsWorker] Error refreshing post #{post.id}: #{e.message}"
    :failed
  end

  def should_refresh?(post)
    # Skip if never fetched or last fetch was more than 1 hour ago
    last_analytic = post.post_analytic
    return true if last_analytic.nil?
    return true if last_analytic.fetched_at.nil?
    return true if last_analytic.fetched_at < 1.hour.ago

    false
  end

  def fetch_from_postforme(post)
    publisher = Social::PostformePublisher.new
    publisher.fetch_post_analytics(post)
  end

  def save_analytics(post, analytics_data)
    analytic = PostAnalytic.find_or_initialize_by(scheduled_post: post)

    analytic.update_from_postforme!(analytics_data)

    # Update scheduled_post with latest metrics summary
    post.update!(
      last_engagement_count: analytic.total_engagement,
      last_impressions_count: analytic.impressions,
      last_analytics_fetched_at: Time.current
    )

    Rails.logger.debug "[RefreshAnalyticsWorker] Updated analytics for post #{post.id}: #{analytic.total_engagement} engagements"
  end

  def notify_completion(stats)
    # Send notification to admin/users about analytics refresh
    User.active.with_subscription.find_each do |user|
      next unless user.email.present?

      AnalyticsRefreshMailer.with(
        user: user,
        stats: stats
      ).refresh_complete.deliver_later if defined?(AnalyticsRefreshMailer)
    rescue => e
      Rails.logger.warn "[RefreshAnalyticsWorker] Failed to send notification: #{e.message}"
    end
  end
end
