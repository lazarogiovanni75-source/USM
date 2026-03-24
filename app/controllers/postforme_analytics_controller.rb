# frozen_string_literal: true

# Controller for Postforme Analytics Dashboard
# Displays performance metrics, charts, and AI-generated insights
class PostformeAnalyticsController < ApplicationController
  before_action :authenticate_user!

  def index
    @days = params[:days]&.to_i || 30
    @platform = params[:platform]

    @analytics_service = PostformeAnalyticsService.new(current_user)
    @dashboard_data = @analytics_service.dashboard_data(days: @days)
    @platforms = available_platforms
    @recent_posts = recent_posts
  end

  def post_details
    @post = current_user.scheduled_posts
                      .includes(:content, :post_analytic, :postforme_analytic)
                      .find(params[:id])

    @analytics = @post.post_analytics_data
    @similar_posts = similar_posts
  end

  def refresh
    RefreshAnalyticsWorker.perform_async

    redirect_to postforme_analytics_index_path,
                notice: 'Analytics refresh started. Data will update shortly.'
  end

  private

  def available_platforms
    platforms = current_user.scheduled_posts
                           .published
                           .where.not(platform: nil)
                           .distinct
                           .pluck(:platform)

    platforms.map do |platform|
      {
        name: platform,
        display_name: platform.capitalize,
        icon: platform_icon(platform)
      }
    end
  end

  def recent_posts
    posts = current_user.scheduled_posts
                       .published
                       .where('posted_at >= ?', @days.days.ago)
                       .includes(:content, :post_analytic)
                       .order(posted_at: :desc)
                       .limit(20)

    posts.map { |post| format_post_for_display(post) }
  end

  def similar_posts
    return [] unless @post.content

    current_user.scheduled_posts
               .published
               .where(id: @post.id)
               .or(
                 current_user.scheduled_posts
                            .published
                            .joins(:content)
                            .where('contents.category = ?', @post.content.category)
               )
               .where.not(id: @post.id)
               .includes(:content, :post_analytic)
               .limit(5)
               .map { |post| format_post_for_display(post) }
  end

  def format_post_for_display(post)
    analytics = post.post_analytics_data

    {
      id: post.id,
      title: post.content&.title || 'Untitled',
      body: truncate_text(post.content&.body, 100),
      platform: post.platform,
      posted_at: post.posted_at,
      posted_at_formatted: post.posted_at&.strftime('%b %d, %Y at %I:%M %p'),
      thumbnail: post.content&.media_url,
      metrics: {
        likes: analytics&.likes || 0,
        comments: analytics&.comments || 0,
        shares: analytics&.shares || 0,
        saves: analytics&.saves || 0,
        impressions: analytics&.impressions || 0,
        reach: analytics&.reach || 0,
        clicks: analytics&.clicks || 0,
        total_engagement: analytics&.total_engagement || 0,
        engagement_rate: analytics&.engagement_rate || 0
      },
      performance_score: analytics&.performance_score || 0,
      has_analytics: analytics.present?
    }
  end

  def truncate_text(text, length)
    return '' if text.blank?
    text.length > length ? "#{text[0...length]}..." : text
  end

  def platform_icon(platform)
    case platform
    when 'instagram' then 'camera'
    when 'facebook' then 'thumbs-up'
    when 'tiktok' then 'music'
    when 'x', 'twitter' then 'repeat'
    when 'linkedin' then 'briefcase'
    when 'youtube' then 'play'
    when 'threads' then 'message-circle'
    when 'bluesky' then 'cloud'
    when 'pinterest' then 'map-pin'
    else 'share-2'
    end
  end
end
