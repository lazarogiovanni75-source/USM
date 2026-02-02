# frozen_string_literal: true

# Controller for Buffer Analytics
# Displays post performance data and handles syncing from Buffer API
class BufferAnalyticsController < ApplicationController
  before_action :authenticate_user!

  # GET /buffer_analytics
  # Shows aggregated analytics for all user's posts
  def index
    @analytics = current_user.buffer_analytics
      .joins(scheduled_post: :social_account)
      .where(social_accounts: { user_id: current_user.id })
      .order(synced_at: :desc)
      .page(params[:page])

    @totals = {
      clicks: @analytics.sum(:clicks),
      impressions: @analytics.sum(:impressions),
      engagement: @analytics.sum(:engagement),
      reach: @analytics.sum(:reach),
      shares: @analytics.sum(:shares),
      likes: @analytics.sum(:likes),
      comments: @analytics.sum(:comments)
    }

    @engagement_rate = calculate_engagement_rate
    @platform_stats = platform_breakdown
    @recent_posts = @analytics.limit(5)
  end

  # POST /buffer_analytics/sync
  # Triggers sync of analytics from Buffer API
  def sync
    sync_service = BufferAnalyticsSyncService.new

    if params[:post_id].present?
      # Sync single post
      post = current_user.scheduled_posts.find(params[:post_id])
      result = sync_service.sync_post(post)
      message = result ? 'Analytics synced successfully' : 'Failed to sync analytics'
      redirect_to buffer_analytics_path, notice: message
    else
      # Sync all user posts
      count = sync_service.sync_user_posts(current_user)
      redirect_to buffer_analytics_path, notice: "Synced #{count} posts"
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to buffer_analytics_path, alert: 'Post not found'
  rescue StandardError => e
    Rails.logger.error "[BufferAnalyticsController] Sync error: #{e.message}"
    redirect_to buffer_analytics_path, alert: 'Sync failed. Please try again.'
  end

  private

  def calculate_engagement_rate
    total_impressions = @analytics.sum(:impressions)
    total_engagement = @analytics.sum(:engagement)

    return 0 if total_impressions.zero?

    (total_engagement.to_f / total_impressions * 100).round(2)
  end

  def platform_breakdown
    current_user.buffer_analytics
      .joins(scheduled_post: :social_account)
      .where(social_accounts: { user_id: current_user.id })
      .group('social_accounts.platform')
      .select(
        'social_accounts.platform,
         SUM(buffer_analytics.clicks) as clicks,
         SUM(buffer_analytics.impressions) as impressions,
         SUM(buffer_analytics.engagement) as engagement,
         COUNT(*) as post_count'
      )
  end
end
