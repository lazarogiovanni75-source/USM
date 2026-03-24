# frozen_string_literal: true

class SocialMediaDashboardController < ApplicationController
  before_action :authenticate_user!

  PLATFORMS = %w[instagram twitter tiktok facebook linkedin youtube pinterest bluebird threads].freeze

  def index
    @dashboard_service = PostformeDashboardService.new

    # Get user's connected social accounts
    @social_accounts = current_user.social_accounts.order(platform: :asc)

    # Build platform data with ALL accounts (not just first one per platform)
    @platforms_data = {}
    
    PLATFORMS.each do |platform|
      platform_accounts = @social_accounts.select { |a| a.platform == platform }
      
      if platform_accounts.any?
        # Process all accounts for this platform
        platform_accounts_data = platform_accounts.map do |account|
          if account.configured_for_postforme?
            metrics = @dashboard_service.fetch_account_metrics(account)
            
            if metrics[:connected]
              {
                platform: platform,
                name: account.account_name || metrics[:name] || platform.titleize,
                connected: true,
                account: account,
                followers: metrics[:followers],
                likes: metrics[:likes],
                views: metrics[:views],
                engagement: metrics[:engagement],
                shares: metrics[:shares],
                new_followers: metrics[:new_followers],
                unfollowers: metrics[:unfollowers],
                messages: metrics[:messages],
                posts_count: metrics[:posts_count],
                last_synced: metrics[:last_synced]
              }
            else
              {
                platform: platform,
                name: account.account_name || platform.titleize,
                connected: false,
                account: account,
                followers: account.followers || 0,
                likes: account.likes || 0,
                views: account.views || 0,
                engagement: account.engagement || 0,
                shares: account.shares || 0,
                new_followers: account.new_followers || 0,
                unfollowers: account.unfollowers || 0,
                messages: account.messages || 0,
                posts_count: 0,
                error: metrics[:error]
              }
            end
          else
            {
              platform: platform,
              name: account.account_name || platform.titleize,
              connected: false,
              account: account,
              followers: account.followers || 0,
              likes: account.likes || 0,
              views: account.views || 0,
              engagement: account.engagement || 0,
              shares: account.shares || 0,
              new_followers: account.new_followers || 0,
              unfollowers: account.unfollowers || 0,
              messages: account.messages || 0,
              posts_count: 0
            }
          end
        end
        
        @platforms_data[platform] = platform_accounts_data
      else
        # No accounts for this platform
        @platforms_data[platform] = [{
          platform: platform,
          name: platform.titleize,
          connected: false,
          account: nil,
          followers: 0,
          likes: 0,
          views: 0,
          engagement: 0,
          shares: 0,
          new_followers: 0,
          unfollowers: 0,
          messages: 0,
          posts_count: 0
        }]
      end
    end

    # Calculate totals from all accounts
    all_accounts_data = @platforms_data.values.flatten
    @totals = {
      likes: all_accounts_data.sum { |p| p[:likes].to_i },
      views: all_accounts_data.sum { |p| p[:views].to_i },
      engagement: all_accounts_data.sum { |p| p[:engagement].to_i },
      shares: all_accounts_data.sum { |p| p[:shares].to_i },
      followers: all_accounts_data.sum { |p| p[:followers].to_i },
      new_followers: all_accounts_data.sum { |p| p[:new_followers].to_i },
      unfollowers: all_accounts_data.sum { |p| p[:unfollowers].to_i },
      messages: all_accounts_data.sum { |p| p[:messages].to_i }
    }

    @connected_count = all_accounts_data.count { |p| p[:connected] }
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

  def connect_profile
    # Redirect to the social_account_connections controller for profile connection
    redirect_to social_account_connections_connect_profile_path(
      api_key: params[:api_key],
      profile_id: params[:profile_id],
      platform: params[:platform]
    )
  end
end
