# frozen_string_literal: true

class CompetitorTrackingController < ApplicationController
  before_action :authenticate_user!

  def index
    @competitors = current_user.competitors.active.order(created_at: :desc)
    @platforms = SocialAccount.pluck(:platform).compact.uniq.sort
    @suggested_competitors = [] # Will be populated via search

    # Calculate summary stats
    @total_competitors = @competitors.count
    @total_followers = @competitors.sum(:follower_count)
    @avg_engagement = @competitors.any? ? @competitors.map(&:engagement_rate).sum / @competitors.count : 0
  end

  def search
    query = params[:query]
    platform = params[:platform]

    if query.blank?
      redirect_to competitor_tracking_index_path, alert: 'Please enter a search query'
      return
    end

    results = CompetitorTrackingService.search_competitors(query, platform)

    # Save as suggestions (not yet tracked)
    @suggested_competitors = results.map do |result|
      # Check if already tracked
      existing = current_user.competitors.find_by(
        platform: result[:platform],
        handle: result[:handle]
      )

      result.merge(existing: existing.present?)
    end

    @competitors = current_user.competitors.active.order(created_at: :desc)
    @search_query = query
    @search_platform = platform

    render :index
  end

  def add
    competitor_data = {
      platform: params[:platform],
      handle: params[:handle],
      display_name: params[:display_name],
      profile_url: params[:profile_url],
      follower_count: params[:follower_count] || 0,
      is_verified: params[:is_verified] || false
    }

    @competitor = current_user.competitors.create!(competitor_data)

    # Trigger initial tracking
    CompetitorTrackingService.track_competitor(@competitor)

    redirect_to competitor_tracking_index_path, notice: "#{@competitor.display_name} added to tracking!"
  rescue StandardError => e
    redirect_to competitor_tracking_index_path, alert: "Failed to add competitor: #{e.message}"
  end

  def refresh
    @competitor = current_user.competitors.find(params[:id])

    result = CompetitorTrackingService.track_competitor(@competitor)

    if result[:success]
      redirect_to competitor_tracking_index_path, notice: 'Competitor data refreshed!'
    else
      redirect_to competitor_tracking_index_path, alert: "Refresh failed: #{result[:error]}"
    end
  end

  def destroy
    @competitor = current_user.competitors.find(params[:id])
    @competitor.destroy!

    redirect_to competitor_tracking_index_path, notice: 'Competitor removed from tracking'
  end

  def insights
    @competitor = current_user.competitors.find(params[:id])

    # Get recent posts
    @recent_posts = @competitor.competitor_posts.recent.order(posted_at: :desc).limit(20)

    # Calculate engagement rate
    @engagement_rate = @competitor.engagement_rate

    # Get post frequency
    @posts_per_day = @competitor.posts_per_day

    # Analyze content themes
    @content_themes = CompetitorTrackingService.analyze_content_themes(@competitor)

    # Get historical data if available
    @historical_metrics = get_historical_metrics(@competitor)
  end

  def refresh_all
    CompetitorTrackingService.refresh_all_metrics

    redirect_to competitor_tracking_index_path, notice: 'All competitors refreshed!'
  end

  private

  def get_historical_metrics(competitor)
    # Group posts by week and calculate average engagement
    posts = competitor.competitor_posts.where('created_at > ?', 90.days.ago)
    return [] if posts.empty?

    posts.group_by { |p| p.created_at.to_date.beginning_of_week }
         .map do |week, week_posts|
      {
        week: week,
        avg_engagement: week_posts.map(&:total_engagement).sum / week_posts.count.to_f,
        post_count: week_posts.count,
        avg_likes: week_posts.pluck(:likes_count).sum / week_posts.count.to_f
      }
    end.sort_by { |m| m[:week] }
  end
end