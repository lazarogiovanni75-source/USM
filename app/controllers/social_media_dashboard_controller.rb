# frozen_string_literal: true

class SocialMediaDashboardController < ApplicationController
  before_action :authenticate_user!

  PLATFORMS = %w[instagram twitter tiktok facebook linkedin youtube pinterest bluebird threads].freeze

  def index
    @dashboard_service = PostformeDashboardService.new

    # Get user's connected social accounts
    @social_accounts = current_user.social_accounts.order(platform: :asc)

    # Build platform data with real metrics from Postforme
    @platforms_data = PLATFORMS.map do |platform|
      account = @social_accounts.find { |a| a.platform == platform }

      if account&.configured_for_postforme?
        # Fetch real metrics from Postforme
        metrics = @dashboard_service.fetch_account_metrics(account)
        metrics[:name] = account.name || metrics[:name] || platform.titleize
        metrics
      else
        # Account not connected to Postforme
        {
          platform: platform,
          name: platform.titleize,
          connected: false,
          account: account,
          followers: account&.followers || 0,
          likes: account&.likes || 0,
          views: account&.views || 0,
          engagement: account&.engagement || 0,
          shares: account&.shares || 0,
          new_followers: account&.new_followers || 0,
          unfollowers: account&.unfollowers || 0,
          messages: account&.messages || 0
        }
      end
    end

    # Calculate totals from real data
    @totals = {
      likes: @platforms_data.sum { |p| p[:likes].to_i },
      views: @platforms_data.sum { |p| p[:views].to_i },
      engagement: @platforms_data.sum { |p| p[:engagement].to_i },
      shares: @platforms_data.sum { |p| p[:shares].to_i },
      followers: @platforms_data.sum { |p| p[:followers].to_i },
      new_followers: @platforms_data.sum { |p| p[:new_followers].to_i },
      unfollowers: @platforms_data.sum { |p| p[:unfollowers].to_i },
      messages: @platforms_data.sum { |p| p[:messages].to_i }
    }

    @connected_count = @platforms_data.count { |p| p[:connected] }
    @syncing = params[:syncing] == 'true'
  end

  def sync_all
    @dashboard_service = PostformeDashboardService.new

    synced_count = 0
    failed_count = 0

    current_user.social_accounts.where.not(postforme_profile_id: nil).find_each do |account|
      if @dashboard_service.sync_account_metrics(account)
        synced_count += 1
      else
        failed_count += 1
      end
    end

    redirect_to social_media_dashboard_index_path(syncing: true),
                notice: "Synced #{synced_count} accounts. #{failed_count} failed."
  end

  def available_profiles
    api_key = params[:api_key]

    unless api_key.present?
      @error = 'API key is required'
      render :profiles_error
      return
    end

    begin
      @profiles = @dashboard_service.fetch_available_profiles(api_key)
      render :available_profiles
    rescue StandardError => e
      Rails.logger.error("[SocialMediaDashboard] Error fetching profiles: #{e.message}")
      @error = 'Failed to fetch profiles. Please check your API key.'
      render :profiles_error
    end
  end
end
